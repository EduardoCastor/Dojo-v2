-- ============================================================================
-- ARQUIVO: 08_martial_arts_and_belts_rls.sql
-- OBJETIVO: Políticas completas de RLS (SELECT, INSERT, UPDATE, DELETE) e
--           funções RPC para gerenciamento de Modalidades (Artes Marciais) e
--           Faixas/Graduações no TatameHub com segurança multi-tenant.
-- ============================================================================

-- 1. HABILITAR ROW LEVEL SECURITY NAS TABELAS
ALTER TABLE public.martial_arts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.belt_ranks ENABLE ROW LEVEL SECURITY;

-- 2. LIMPAR POLÍTICAS ANTERIORES PARA GARANTIR IDEMPOTÊNCIA
DROP POLICY IF EXISTS "martial_arts_read" ON public.martial_arts;
DROP POLICY IF EXISTS "martial_arts_select_tenant" ON public.martial_arts;
DROP POLICY IF EXISTS "martial_arts_insert_staff" ON public.martial_arts;
DROP POLICY IF EXISTS "martial_arts_update_staff" ON public.martial_arts;
DROP POLICY IF EXISTS "martial_arts_delete_owner" ON public.martial_arts;

DROP POLICY IF EXISTS "belt_ranks_read" ON public.belt_ranks;
DROP POLICY IF EXISTS "belt_ranks_select_tenant" ON public.belt_ranks;
DROP POLICY IF EXISTS "belt_ranks_insert_staff" ON public.belt_ranks;
DROP POLICY IF EXISTS "belt_ranks_update_staff" ON public.belt_ranks;
DROP POLICY IF EXISTS "belt_ranks_delete_owner" ON public.belt_ranks;

-- ============================================================================
-- 3. POLÍTICAS PARA PUBLIC.MARTIAL_ARTS
-- ============================================================================

-- SELECT: Qualquer membro autenticado da academia pode visualizar as modalidades
CREATE POLICY "martial_arts_select_tenant" ON public.martial_arts
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

-- INSERT: Membros com perfil de gestão/pedagógico podem cadastrar modalidades
CREATE POLICY "martial_arts_insert_staff" ON public.martial_arts
FOR INSERT TO authenticated
WITH CHECK (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
);

-- UPDATE: Edição de modalidades e status (active/inactive)
CREATE POLICY "martial_arts_update_staff" ON public.martial_arts
FOR UPDATE TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
)
WITH CHECK (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
);

-- DELETE: Exclusão restrita a administradores e gestores
CREATE POLICY "martial_arts_delete_owner" ON public.martial_arts
FOR DELETE TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager')
);

-- ============================================================================
-- 4. POLÍTICAS PARA PUBLIC.BELT_RANKS
-- ============================================================================

-- SELECT: Qualquer membro autenticado da academia pode visualizar as faixas
CREATE POLICY "belt_ranks_select_tenant" ON public.belt_ranks
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

-- INSERT: Membros staff podem cadastrar faixas e graduações
CREATE POLICY "belt_ranks_insert_staff" ON public.belt_ranks
FOR INSERT TO authenticated
WITH CHECK (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
);

-- UPDATE: Membros staff podem editar faixas e suas regras
CREATE POLICY "belt_ranks_update_staff" ON public.belt_ranks
FOR UPDATE TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
)
WITH CHECK (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
);

-- DELETE: Exclusão de faixas por gestores autorizados
CREATE POLICY "belt_ranks_delete_owner" ON public.belt_ranks
FOR DELETE TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary')
);

-- ============================================================================
-- 5. FUNÇÃO RPC ATÔMICA: REORDER_BELT_RANKS
-- ============================================================================
-- Permite reordenar a sequência progressiva de faixas de uma arte marcial
-- em uma única transação atômica.
CREATE OR REPLACE FUNCTION public.reorder_belt_ranks(
  p_tenant_id uuid,
  p_martial_art_id uuid,
  p_ordered_belt_ids uuid[]
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_belt_id uuid;
  v_index integer := 1;
BEGIN
  -- 1. Validar autenticação
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validar permissão na academia
  IF NOT public.has_tenant_role(p_tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor') THEN
    RAISE EXCEPTION 'Permissão insuficiente para alterar a ordem das graduações nesta academia.'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Atualizar cada faixa com seu novo order_index
  FOREACH v_belt_id IN ARRAY p_ordered_belt_ids
  LOOP
    UPDATE public.belt_ranks
    SET order_index = v_index
    WHERE id = v_belt_id
      AND tenant_id = p_tenant_id
      AND martial_art_id = p_martial_art_id;

    v_index := v_index + 1;
  END LOOP;

  RETURN true;
END;
$$;

-- 6. Conceder permissão de execução aos usuários autenticados
GRANT EXECUTE ON FUNCTION public.reorder_belt_ranks(uuid, uuid, uuid[]) TO authenticated;
