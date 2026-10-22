-- ============================================================================
-- Migration 19: Baixas Financeiras Atômicas e Histórico de Pagamentos
-- TatameHub: Módulo Mensalidades e Finanças
-- ============================================================================

-- 1. TABELA DE HISTÓRICO DE PAGAMENTOS/BAIXAS DE TRANSAÇÕES EXTRAS
CREATE TABLE IF NOT EXISTS public.transaction_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  transaction_id UUID NOT NULL REFERENCES public.financial_transactions(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  payment_method payment_method NOT NULL DEFAULT 'pix',
  receipt_number TEXT NOT NULL,
  registered_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  registered_by_name TEXT NOT NULL DEFAULT 'Administrador',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_tx_payments_tenant_tx
  ON public.transaction_payments (tenant_id, transaction_id);

-- 2. HABILITAR ROW LEVEL SECURITY NA TABELA TRANSACTION_PAYMENTS
ALTER TABLE public.transaction_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tx_payments_select" ON public.transaction_payments;
CREATE POLICY "tx_payments_select" ON public.transaction_payments
  FOR SELECT TO authenticated
  USING (
    public.has_tenant_role(
      tenant_id,
      VARIADIC ARRAY['owner', 'branch_manager', 'secretary', 'financial']::app_role[]
    )
  );

DROP POLICY IF EXISTS "tx_payments_write_financial" ON public.transaction_payments;
CREATE POLICY "tx_payments_write_financial" ON public.transaction_payments
  FOR ALL TO authenticated
  USING (
    public.has_tenant_role(
      tenant_id,
      VARIADIC ARRAY['owner', 'branch_manager', 'secretary', 'financial']::app_role[]
    )
  )
  WITH CHECK (
    public.has_tenant_role(
      tenant_id,
      VARIADIC ARRAY['owner', 'branch_manager', 'secretary', 'financial']::app_role[]
    )
  );

-- 3. RPC ATÔMICA: BAIXA DE MENSALIDADE / COBRANÇA (INVOICE)
CREATE OR REPLACE FUNCTION public.settle_invoice_payment(
  p_invoice_id UUID,
  p_tenant_id UUID,
  p_amount NUMERIC(10,2),
  p_payment_method payment_method,
  p_payment_date DATE DEFAULT CURRENT_DATE,
  p_receipt_number TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_registered_by_name TEXT DEFAULT 'Administrador'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_invoice RECORD;
  v_new_paid NUMERIC(10,2);
  v_new_balance NUMERIC(10,2);
  v_new_status invoice_status;
  v_receipt TEXT;
  v_user_id UUID;
  v_updated RECORD;
BEGIN
  -- Validar se o usuário autenticado pertence ao tenant com papel financeiro ou gestão
  IF NOT public.has_tenant_role(
    p_tenant_id,
    VARIADIC ARRAY['owner', 'branch_manager', 'secretary', 'financial']::app_role[]
  ) THEN
    RAISE EXCEPTION 'Acesso negado: permissão insuficiente para registrar baixa financeira.';
  END IF;

  -- Obter cobrança com bloqueio FOR UPDATE para prevenir concorrência
  SELECT * INTO v_invoice
  FROM public.invoices
  WHERE id = p_invoice_id AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cobrança não encontrada ou não pertence à academia ativa.';
  END IF;

  IF v_invoice.balance <= 0 THEN
    RAISE EXCEPTION 'Esta cobrança já foi integralmente quitada.';
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'O valor da baixa deve ser maior que zero.';
  END IF;

  IF p_amount > v_invoice.balance THEN
    RAISE EXCEPTION 'O valor da baixa (R$ %) não pode ultrapassar o saldo pendente (R$ %).', p_amount, v_invoice.balance;
  END IF;

  v_new_paid := ROUND((v_invoice.paid_amount + p_amount), 2);
  v_new_balance := ROUND(GREATEST(0, v_invoice.balance - p_amount), 2);

  IF v_new_balance <= 0 THEN
    v_new_status := 'paid'::invoice_status;
  ELSE
    v_new_status := 'partially_paid'::invoice_status;
  END IF;

  v_receipt := COALESCE(p_receipt_number, 'REC-' || to_char(now(), 'YYYYMMDD-HH24MISS'));
  v_user_id := auth.uid();

  -- Atualizar registro na tabela invoices
  UPDATE public.invoices
  SET
    paid_amount = v_new_paid,
    balance = v_new_balance,
    status = v_new_status,
    payment_date = COALESCE(p_payment_date, CURRENT_DATE),
    payment_method = p_payment_method,
    receipt_number = v_receipt,
    notes = CASE
      WHEN p_notes IS NOT NULL AND p_notes <> '' THEN
        COALESCE(notes || ' | ', '') || p_notes
      ELSE notes
    END,
    updated_at = timezone('utc'::text, now())
  WHERE id = p_invoice_id AND tenant_id = p_tenant_id
  RETURNING * INTO v_updated;

  -- Gravar histórico em invoice_payments
  INSERT INTO public.invoice_payments (
    tenant_id,
    invoice_id,
    amount,
    payment_date,
    payment_method,
    receipt_number,
    registered_by_user_id,
    registered_by_name,
    notes
  ) VALUES (
    p_tenant_id,
    p_invoice_id,
    p_amount,
    COALESCE(p_payment_date, CURRENT_DATE),
    p_payment_method,
    v_receipt,
    v_user_id,
    p_registered_by_name,
    p_notes
  );

  RETURN to_jsonb(v_updated);
END;
$$;

GRANT EXECUTE ON FUNCTION public.settle_invoice_payment TO authenticated;

-- 4. RPC ATÔMICA: BAIXA DE TRANSAÇÃO EXTRA (RECEITA OU DESPESA)
CREATE OR REPLACE FUNCTION public.settle_financial_transaction(
  p_transaction_id UUID,
  p_tenant_id UUID,
  p_amount NUMERIC(10,2),
  p_payment_method payment_method,
  p_payment_date DATE DEFAULT CURRENT_DATE,
  p_receipt_number TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_registered_by_name TEXT DEFAULT 'Administrador'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_tx RECORD;
  v_current_paid NUMERIC(10,2);
  v_current_balance NUMERIC(10,2);
  v_new_paid NUMERIC(10,2);
  v_new_balance NUMERIC(10,2);
  v_new_status TEXT;
  v_receipt TEXT;
  v_user_id UUID;
  v_updated RECORD;
BEGIN
  -- Validar se o usuário autenticado pertence ao tenant com papel financeiro ou gestão
  IF NOT public.has_tenant_role(
    p_tenant_id,
    VARIADIC ARRAY['owner', 'branch_manager', 'secretary', 'financial']::app_role[]
  ) THEN
    RAISE EXCEPTION 'Acesso negado: permissão insuficiente para registrar baixa financeira.';
  END IF;

  -- Obter transação com bloqueio FOR UPDATE
  SELECT * INTO v_tx
  FROM public.financial_transactions
  WHERE id = p_transaction_id AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lançamento financeiro não encontrado ou não pertence à academia ativa.';
  END IF;

  v_current_paid := COALESCE(v_tx.paid_amount, CASE WHEN v_tx.status = 'completed' THEN v_tx.amount ELSE 0.00 END);
  v_current_balance := COALESCE(v_tx.balance, CASE WHEN v_tx.status = 'completed' THEN 0.00 ELSE (v_tx.amount - v_current_paid) END);

  IF v_current_balance <= 0 THEN
    RAISE EXCEPTION 'Este lançamento já foi integralmente quitado.';
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'O valor da baixa deve ser maior que zero.';
  END IF;

  IF p_amount > v_current_balance THEN
    RAISE EXCEPTION 'O valor da baixa (R$ %) não pode ultrapassar o saldo pendente (R$ %).', p_amount, v_current_balance;
  END IF;

  v_new_paid := ROUND((v_current_paid + p_amount), 2);
  v_new_balance := ROUND(GREATEST(0, v_current_balance - p_amount), 2);

  IF v_new_balance <= 0 THEN
    v_new_status := 'completed';
  ELSE
    v_new_status := 'partially_paid';
  END IF;

  v_receipt := COALESCE(p_receipt_number, 'REC-TX-' || to_char(now(), 'YYYYMMDD-HH24MISS'));
  v_user_id := auth.uid();

  -- Atualizar registro na tabela financial_transactions
  UPDATE public.financial_transactions
  SET
    paid_amount = v_new_paid,
    balance = v_new_balance,
    status = v_new_status,
    payment_date = COALESCE(p_payment_date, CURRENT_DATE),
    payment_method = p_payment_method,
    receipt_number = v_receipt,
    notes = CASE
      WHEN p_notes IS NOT NULL AND p_notes <> '' THEN
        COALESCE(notes || ' | Baixa: ', '') || p_notes
      ELSE notes
    END,
    updated_at = timezone('utc'::text, now())
  WHERE id = p_transaction_id AND tenant_id = p_tenant_id
  RETURNING * INTO v_updated;

  -- Gravar histórico em transaction_payments
  INSERT INTO public.transaction_payments (
    tenant_id,
    transaction_id,
    amount,
    payment_date,
    payment_method,
    receipt_number,
    registered_by_user_id,
    registered_by_name,
    notes
  ) VALUES (
    p_tenant_id,
    p_transaction_id,
    p_amount,
    COALESCE(p_payment_date, CURRENT_DATE),
    p_payment_method,
    v_receipt,
    v_user_id,
    p_registered_by_name,
    p_notes
  );

  RETURN to_jsonb(v_updated);
END;
$$;

GRANT EXECUTE ON FUNCTION public.settle_financial_transaction TO authenticated;
