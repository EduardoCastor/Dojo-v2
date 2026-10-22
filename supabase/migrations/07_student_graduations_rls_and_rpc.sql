-- ============================================================================
-- ARQUIVO: 07_student_graduations_rls_and_rpc.sql
-- OBJETIVO: Correção definitiva das políticas RLS e função RPC atômica para
--           salvar graduações (faixas) de alunos no TatameHub sem erros de RLS.
-- ============================================================================

-- 1. HABILITAR ROW LEVEL SECURITY NA TABELA DE GRADUAÇÕES
ALTER TABLE public.student_graduations ENABLE ROW LEVEL SECURITY;

-- 2. LIMPAR POLÍTICAS ANTERIORES PARA GARANTIR IDEMPOTÊNCIA
DROP POLICY IF EXISTS "graduations_select" ON public.student_graduations;
DROP POLICY IF EXISTS "graduations_select_tenant" ON public.student_graduations;
DROP POLICY IF EXISTS "graduations_insert_staff" ON public.student_graduations;
DROP POLICY IF EXISTS "graduations_update_staff" ON public.student_graduations;
DROP POLICY IF EXISTS "graduations_delete_owner" ON public.student_graduations;

-- 3. POLÍTICA DE LEITURA (SELECT)
-- Membros ativos da academia, o próprio aluno ou seu responsável legal podem ler o histórico
CREATE POLICY "graduations_select_tenant" ON public.student_graduations
FOR SELECT TO authenticated
USING (
  public.is_tenant_member(tenant_id)
  OR public.is_own_student(student_id)
  OR public.is_guardian_of_student(student_id)
);

-- 4. POLÍTICA DE INSERÇÃO (INSERT)
-- Usuários staff autenticados (owner, branch_manager, secretary, instructor, financial)
-- pertencentes à mesma academia (tenant_id) podem registrar graduações
CREATE POLICY "graduations_insert_staff" ON public.student_graduations
FOR INSERT TO authenticated
WITH CHECK (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial')
);

-- 5. POLÍTICA DE ATUALIZAÇÃO (UPDATE)
-- Atualizações de graduação por membros staff autorizados
CREATE POLICY "graduations_update_staff" ON public.student_graduations
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial'));

-- 6. POLÍTICA DE EXCLUSÃO (DELETE)
-- Apenas proprietários e gestores de filial podem remover registros de graduação
CREATE POLICY "graduations_delete_owner" ON public.student_graduations
FOR DELETE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager'));

-- ============================================================================
-- 7. FUNÇÃO RPC ATÔMICA E SEGURA: RECORD_STUDENT_GRADUATION
-- ============================================================================
-- Permite registrar/atualizar a graduação do aluno com validação estrita no servidor,
-- verificação de permissões do operador, conferência de chaves estrangeiras compostas
-- e registro automático de auditoria, imune a inconsistências de RLS no cliente.
CREATE OR REPLACE FUNCTION public.record_student_graduation(
  p_tenant_id uuid,
  p_student_id uuid,
  p_martial_art_id uuid,
  p_belt_rank_id uuid,
  p_examiner_name text DEFAULT 'Atualização administrativa',
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_graduation_id uuid;
  v_user_name text;
BEGIN
  -- 1. Validar autenticação
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validar permissão na academia
  IF NOT public.has_tenant_role(p_tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial') THEN
    RAISE EXCEPTION 'Permissão insuficiente para registrar graduações nesta academia.'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Validar que o aluno pertence à academia ativa
  IF NOT EXISTS (
    SELECT 1 FROM public.students 
    WHERE id = p_student_id AND tenant_id = p_tenant_id
  ) THEN
    RAISE EXCEPTION 'Aluno não encontrado nesta academia.'
      USING ERRCODE = 'P0002';
  END IF;

  -- 4. Validar que a modalidade pertence à mesma academia e está ativa
  IF NOT EXISTS (
    SELECT 1 FROM public.martial_arts 
    WHERE id = p_martial_art_id AND tenant_id = p_tenant_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Modalidade não pertence a esta academia ou está inativa.'
      USING ERRCODE = 'P0002';
  END IF;

  -- 5. Validar que a faixa/graduação pertence à modalidade e à academia informada
  IF NOT EXISTS (
    SELECT 1 FROM public.belt_ranks 
    WHERE id = p_belt_rank_id AND tenant_id = p_tenant_id AND martial_art_id = p_martial_art_id
  ) THEN
    RAISE EXCEPTION 'Graduação não pertence à modalidade ou à academia informada.'
      USING ERRCODE = 'P0002';
  END IF;

  -- 6. Obter nome do usuário operador para auditoria
  SELECT COALESCE(full_name, 'Colaborador') INTO v_user_name
  FROM public.profiles WHERE id = v_user_id;

  -- 7. Inserir graduação no histórico
  INSERT INTO public.student_graduations (
    tenant_id,
    student_id,
    martial_art_id,
    belt_rank_id,
    graduated_at,
    examiner_name,
    notes
  ) VALUES (
    p_tenant_id,
    p_student_id,
    p_martial_art_id,
    p_belt_rank_id,
    CURRENT_DATE,
    COALESCE(p_examiner_name, v_user_name, 'Sensei Responsável'),
    p_notes
  )
  RETURNING id INTO v_graduation_id;

  -- 8. Auditoria silenciosa
  BEGIN
    INSERT INTO public.audit_logs (
      tenant_id,
      user_id,
      user_name,
      action,
      entity,
      entity_id,
      details
    ) VALUES (
      p_tenant_id,
      v_user_id,
      COALESCE(v_user_name, 'Colaborador'),
      'Registro de Graduação',
      'student_graduations',
      v_graduation_id,
      'Graduação atualizada no cadastro do aluno ID ' || p_student_id::text
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'id', v_graduation_id,
    'student_id', p_student_id,
    'martial_art_id', p_martial_art_id,
    'belt_rank_id', p_belt_rank_id,
    'graduated_at', CURRENT_DATE,
    'success', true
  );
END;
$$;

-- 8. Conceder permissão de execução aos usuários autenticados
GRANT EXECUTE ON FUNCTION public.record_student_graduation(uuid, uuid, uuid, uuid, text, text) TO authenticated;
