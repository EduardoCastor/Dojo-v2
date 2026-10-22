-- ============================================================================
-- ARQUIVO: 02_security_functions_and_rpc.sql
-- OBJETIVO: Funções de autorização, RPC atômica de cadastro e helpers RLS.
-- PROJETO: TatameHub (Gestão de Academias de Artes Marciais)
-- ============================================================================

-- 1. FUNÇÃO: VERIFICA SE O USUÁRIO É MEMBRO ATIVO DA ACADEMIA
CREATE OR REPLACE FUNCTION public.is_tenant_member(t_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.tenant_memberships 
    WHERE tenant_id = t_id 
      AND user_id = auth.uid() 
      AND status = 'active'
  );
$$;

-- 2. FUNÇÃO: VERIFICA SE O USUÁRIO POSSUI DETERMINADOS PAPÉIS NA ACADEMIA
CREATE OR REPLACE FUNCTION public.has_tenant_role(t_id uuid, VARIADIC target_roles app_role[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.tenant_memberships 
    WHERE tenant_id = t_id 
      AND user_id = auth.uid() 
      AND status = 'active'
      AND role = ANY(target_roles)
  );
$$;

-- 3. FUNÇÃO: VERIFICA ACESSO ESPECÍFICO POR FILIAL
-- Proprietários e secretaria acessam todas as filiais; Gestores de filial acessam apenas sua unidade
CREATE OR REPLACE FUNCTION public.has_branch_access(t_id uuid, b_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.tenant_memberships 
    WHERE tenant_id = t_id 
      AND user_id = auth.uid() 
      AND status = 'active'
      AND (
        role IN ('owner', 'secretary', 'financial')
        OR (role IN ('branch_manager', 'instructor') AND (branch_id = b_id OR branch_id IS NULL))
      )
  );
$$;

-- 4. FUNÇÃO: VERIFICA SE O USUÁRIO AUTENTICADO É O PRÓPRIO ALUNO
CREATE OR REPLACE FUNCTION public.is_own_student(s_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.students s
    JOIN public.persons p ON p.id = s.person_id
    JOIN auth.users u ON u.email = p.email
    WHERE s.id = s_id 
      AND u.id = auth.uid()
  );
$$;

-- 5. FUNÇÃO: VERIFICA SE O USUÁRIO AUTENTICADO É RESPONSÁVEL DO ALUNO
CREATE OR REPLACE FUNCTION public.is_guardian_of_student(s_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.guardian_relationships gr
    JOIN public.persons gp ON gp.id = gr.guardian_person_id
    JOIN auth.users u ON u.email = gp.email
    WHERE gr.student_id = s_id 
      AND u.id = auth.uid()
  );
$$;

-- 6. FUNÇÃO: VERIFICA AUTORIZAÇÃO RESTRITA PARA DADOS DE SAÚDE (LGPD)
-- Apenas Owner, Gestor da filial do aluno, o próprio aluno ou seu responsável legal
CREATE OR REPLACE FUNCTION public.can_access_health_record(t_id uuid, s_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_student_branch_id uuid;
BEGIN
  -- 1. Verificar se é o próprio aluno ou responsável legal
  IF public.is_own_student(s_id) OR public.is_guardian_of_student(s_id) THEN
    RETURN true;
  END IF;

  -- 2. Se for proprietário da academia correspondente
  IF public.has_tenant_role(t_id, 'owner') THEN
    RETURN true;
  END IF;

  -- 3. Obter filial do aluno
  SELECT branch_id INTO v_student_branch_id 
  FROM public.students 
  WHERE id = s_id AND tenant_id = t_id;

  -- 4. Se for gestor da filial do aluno
  IF v_student_branch_id IS NOT NULL AND public.has_branch_access(t_id, v_student_branch_id) THEN
    RETURN true;
  END IF;

  -- Qualquer outro papel (ex: instrutor comum, financeiro) é bloqueado por padrão
  RETURN false;
END;
$$;

-- 7. FUNÇÃO RPC ATÔMICA: CADASTRO SEGURO DE ACADEMIA + FILIAL MATRIZ + PROPRIETÁRIO
-- Executada pelo usuário autenticado após sign-up. Não permite forjar IDs de terceiros.
CREATE OR REPLACE FUNCTION public.register_academy_atomic(
  p_trade_name text,
  p_legal_name text,
  p_cnpj_or_cpf text,
  p_admin_name text,
  p_phone text,
  p_whatsapp text,
  p_address jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_tenant_id uuid;
  v_branch_id uuid;
  v_membership_id uuid;
BEGIN
  -- 1. Obter identificador do usuário autenticado na sessão do Supabase Auth
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado para criar uma academia.'
      USING ERRCODE = '42501';
  END IF;

  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;

  -- 2. Validar campos obrigatórios
  IF trim(p_trade_name) = '' OR trim(p_cnpj_or_cpf) = '' OR trim(p_admin_name) = '' THEN
    RAISE EXCEPTION 'Parâmetros inválidos: Nome da academia, CNPJ/CPF e nome do responsável são obrigatórios.'
      USING ERRCODE = '22023';
  END IF;

  -- 3. Garantir que o perfil público do usuário exista
  INSERT INTO public.profiles (id, full_name, phone)
  VALUES (v_user_id, p_admin_name, p_phone)
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name, phone = COALESCE(EXCLUDED.phone, public.profiles.phone);

  -- 4. Criar o registro principal da academia (tenant)
  INSERT INTO public.tenants (
    trade_name,
    legal_name,
    cnpj_or_cpf,
    admin_name,
    email,
    phone,
    whatsapp,
    address,
    plan_id,
    status,
    trial_started_at,
    trial_expires_at
  )
  VALUES (
    p_trade_name,
    COALESCE(p_legal_name, p_trade_name),
    p_cnpj_or_cpf,
    p_admin_name,
    v_user_email,
    p_phone,
    p_whatsapp,
    COALESCE(p_address, '{}'::jsonb),
    'trial',
    'trial',
    now(),
    now() + interval '10 days'
  )
  RETURNING id INTO v_tenant_id;

  -- 5. Criar a filial Matriz padrão vinculada à academia
  INSERT INTO public.branches (
    tenant_id,
    name,
    is_headquarter,
    phone,
    email,
    address,
    manager_name,
    active
  )
  VALUES (
    v_tenant_id,
    'Unidade Matriz',
    true,
    p_phone,
    v_user_email,
    COALESCE(p_address->>'street', '') || ', ' || COALESCE(p_address->>'number', ''),
    p_admin_name,
    true
  )
  RETURNING id INTO v_branch_id;

  -- 6. Atribuir ao usuário o papel de PROPRIETÁRIO (owner) da academia recém-criada
  INSERT INTO public.tenant_memberships (
    tenant_id,
    user_id,
    branch_id,
    role,
    status
  )
  VALUES (
    v_tenant_id,
    v_user_id,
    v_branch_id,
    'owner',
    'active'
  )
  RETURNING id INTO v_membership_id;

  -- 7. Registrar auditoria imutável da criação
  INSERT INTO public.audit_logs (
    tenant_id,
    user_id,
    user_name,
    action,
    entity,
    entity_id,
    details
  )
  VALUES (
    v_tenant_id,
    v_user_id,
    p_admin_name,
    'Criação de Academia',
    'Tenant',
    v_tenant_id::text,
    'Academia criada com filial matriz e 10 dias de avaliação gratuita ativados.'
  );

  -- 8. Retornar dados criados em formato estruturado
  RETURN jsonb_build_object(
    'success', true,
    'tenant_id', v_tenant_id,
    'branch_id', v_branch_id,
    'membership_id', v_membership_id,
    'role', 'owner',
    'plan_id', 'trial'
  );
END;
$$;
