-- ============================================================================
-- ARQUIVO: 10_guardians_persistence_search_and_rpc.sql
-- OBJETIVO: Correção definitiva da persistência, pesquisa, listagem e vínculos
--           de responsáveis no TatameHub com funções RPC seguras e políticas RLS completas.
-- ============================================================================

-- 1. CORREÇÃO DAS POLÍTICAS RLS PARA PERMITIR INSTRUCTORS E STAFF COMPLETO
-- Em muitas academias, instrutores matriculam alunos e seus responsáveis.
DROP POLICY IF EXISTS "persons_insert_staff" ON public.persons;
CREATE POLICY "persons_insert_staff" ON public.persons
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

DROP POLICY IF EXISTS "persons_update_staff" ON public.persons;
CREATE POLICY "persons_update_staff" ON public.persons
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

DROP POLICY IF EXISTS "guardians_insert_staff" ON public.guardian_relationships;
CREATE POLICY "guardians_insert_staff" ON public.guardian_relationships
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

DROP POLICY IF EXISTS "guardians_update_staff" ON public.guardian_relationships;
CREATE POLICY "guardians_update_staff" ON public.guardian_relationships
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

DROP POLICY IF EXISTS "guardians_delete_staff" ON public.guardian_relationships;
CREATE POLICY "guardians_delete_staff" ON public.guardian_relationships
FOR DELETE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

-- 2. GARANTIR FOREIGN KEYS DIRETAS PARA SUPORTE COMPLETO AO POSTGREST
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_guardians_person_direct'
      AND table_name = 'guardian_relationships'
  ) THEN
    ALTER TABLE public.guardian_relationships
      ADD CONSTRAINT fk_guardians_person_direct
      FOREIGN KEY (guardian_person_id) REFERENCES public.persons(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_guardians_student_direct'
      AND table_name = 'guardian_relationships'
  ) THEN
    ALTER TABLE public.guardian_relationships
      ADD CONSTRAINT fk_guardians_student_direct
      FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;
  END IF;
END $$;

-- 3. ÍNDICE ÚNICO PARA PREVENIR DUPLICIDADE DE VÍNCULO IDÊNTICO
CREATE UNIQUE INDEX IF NOT EXISTS uq_guardian_student_relationship
ON public.guardian_relationships (tenant_id, student_id, guardian_person_id);

-- ============================================================================
-- 4. FUNÇÃO RPC: SEARCH_GUARDIANS_SUMMARY
-- ============================================================================
-- Pesquisa em tempo real de responsáveis e pessoas aptas a vínculo na academia,
-- retornando dependentes vinculados e status de aluno se aplicável.
CREATE OR REPLACE FUNCTION public.search_guardians_summary(
  p_tenant_id uuid,
  p_search_query text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_clean_search text;
  v_text_search text;
  v_results jsonb;
BEGIN
  -- 1. Validar autenticação
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validar acesso ao tenant
  IF NOT public.has_tenant_role(p_tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial') THEN
    RAISE EXCEPTION 'Permissão insuficiente para consultar responsáveis nesta academia.'
      USING ERRCODE = '42501';
  END IF;

  v_clean_search := public.clean_cpf(p_search_query);
  v_text_search := '%' || lower(trim(COALESCE(p_search_query, ''))) || '%';

  -- Consulta agregada de pessoas com papéis de responsável ou vínculos
  SELECT COALESCE(jsonb_agg(item ORDER BY item->>'full_name'), '[]'::jsonb)
  INTO v_results
  FROM (
    SELECT
      jsonb_build_object(
        'person_id', p.id,
        'full_name', p.full_name,
        'social_name', p.social_name,
        'cpf', p.cpf,
        'birth_date', p.birth_date,
        'gender', p.gender,
        'phone', p.phone,
        'email', p.email,
        'address', p.address,
        'created_at', p.created_at,
        'is_student', (st.id IS NOT NULL),
        'student_id', st.id,
        'registration_number', st.registration_number,
        'student_status', st.status,
        'dependents_count', COUNT(gr.id),
        'dependents', COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'relationship_id', gr.id,
              'student_id', s_dep.id,
              'student_name', p_dep.full_name,
              'student_registration_number', s_dep.registration_number,
              'student_status', s_dep.status,
              'relationship_label', gr.relationship_label,
              'is_legal_guardian', gr.is_legal_guardian,
              'is_financial_guardian', gr.is_financial_guardian,
              'is_emergency_contact', gr.is_emergency_contact,
              'is_pickup_authorized', gr.is_pickup_authorized,
              'notes', gr.notes
            )
          ) FILTER (WHERE gr.id IS NOT NULL),
          '[]'::jsonb
        )
      ) AS item
    FROM public.persons p
    -- Aluno próprio (se essa pessoa também for aluna)
    LEFT JOIN public.students st ON st.tenant_id = p.tenant_id AND st.person_id = p.id
    -- Vínculos como responsável
    LEFT JOIN public.guardian_relationships gr ON gr.tenant_id = p.tenant_id AND gr.guardian_person_id = p.id
    LEFT JOIN public.students s_dep ON s_dep.id = gr.student_id
    LEFT JOIN public.persons p_dep ON p_dep.id = s_dep.person_id
    WHERE p.tenant_id = p_tenant_id
      -- Trazer se a pessoa é responsável de alguém OU se bate com a busca textual/CPF
      AND (
        gr.id IS NOT NULL
        OR (
          p_search_query IS NOT NULL
          AND trim(p_search_query) <> ''
          AND (
            lower(p.full_name) LIKE v_text_search
            OR (v_clean_search <> '' AND public.clean_cpf(p.cpf) LIKE '%' || v_clean_search || '%')
            OR lower(COALESCE(p.email, '')) LIKE v_text_search
          )
        )
      )
    GROUP BY p.id, st.id, st.registration_number, st.status
    HAVING (
      p_search_query IS NULL
      OR trim(p_search_query) = ''
      OR lower(p.full_name) LIKE v_text_search
      OR (v_clean_search <> '' AND public.clean_cpf(p.cpf) LIKE '%' || v_clean_search || '%')
      OR bool_or(lower(COALESCE(p_dep.full_name, '')) LIKE v_text_search)
      OR bool_or(lower(COALESCE(s_dep.registration_number, '')) LIKE v_text_search)
    )
  ) sub;

  RETURN v_results;
END;
$$;

-- ============================================================================
-- 5. FUNÇÃO RPC: SAVE_STUDENT_GUARDIAN_LINK
-- ============================================================================
-- Salva ou atualiza atomicamente o responsável e seu vínculo com o aluno,
-- garantindo que não haja duplicação de pessoas e que remoções não apaguem a pessoa.
CREATE OR REPLACE FUNCTION public.save_student_guardian_link(
  p_tenant_id uuid,
  p_student_id uuid,
  p_has_guardian boolean,
  p_guardian_person jsonb DEFAULT NULL,
  p_guardian_rel jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_guardian_person_id uuid;
  v_guardian_rel_id uuid;
  v_guardian_name text;
  v_guardian_cpf text;
  v_clean_cpf text;
  v_relationship_label text;
BEGIN
  -- 1. Validar autenticação
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validar permissões no tenant
  IF NOT public.has_tenant_role(p_tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor') THEN
    RAISE EXCEPTION 'Permissão insuficiente para alterar responsáveis nesta academia.'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Confirmar que o aluno pertence a esta academia
  IF NOT EXISTS (
    SELECT 1 FROM public.students WHERE id = p_student_id AND tenant_id = p_tenant_id
  ) THEN
    RAISE EXCEPTION 'Aluno não encontrado nesta academia.'
      USING ERRCODE = 'P0002';
  END IF;

  -- 4. Se o usuário desmarcou o responsável (remover vínculo)
  IF NOT p_has_guardian THEN
    DELETE FROM public.guardian_relationships
    WHERE tenant_id = p_tenant_id AND student_id = p_student_id;

    RETURN jsonb_build_object(
      'success', true,
      'action', 'unlinked',
      'message', 'Vínculo de responsável removido com sucesso.'
    );
  END IF;

  -- 5. Se o usuário vinculou responsável
  IF p_guardian_person IS NULL THEN
    RAISE EXCEPTION 'Dados do responsável não foram informados.'
      USING ERRCODE = '23502';
  END IF;

  v_guardian_name := trim(COALESCE(p_guardian_person->>'full_name', ''));
  IF v_guardian_name = '' THEN
    RAISE EXCEPTION 'O nome completo do responsável é obrigatório.'
      USING ERRCODE = '23502';
  END IF;

  v_clean_cpf := public.clean_cpf(p_guardian_person->>'cpf');
  IF v_clean_cpf = '' THEN
    v_clean_cpf := NULL;
  END IF;

  -- Validação matemática de CPF se informado
  IF v_clean_cpf IS NOT NULL AND NOT public.is_valid_cpf(v_clean_cpf) THEN
    RAISE EXCEPTION 'O CPF do responsável (%) é matematicamente inválido.', p_guardian_person->>'cpf'
      USING ERRCODE = '22023';
  END IF;

  -- Prioridade 1: Reutilizar por ID explícito de pessoa se já existir
  IF p_guardian_person->>'id' IS NOT NULL AND length(trim(p_guardian_person->>'id')) = 36 THEN
    SELECT id INTO v_guardian_person_id
    FROM public.persons
    WHERE id = (p_guardian_person->>'id')::uuid AND tenant_id = p_tenant_id
    LIMIT 1;
  END IF;

  -- Prioridade 2: Localizar por CPF único no tenant se não encontrou por ID
  IF v_guardian_person_id IS NULL AND v_clean_cpf IS NOT NULL THEN
    SELECT id INTO v_guardian_person_id
    FROM public.persons
    WHERE tenant_id = p_tenant_id AND public.clean_cpf(cpf) = v_clean_cpf
    LIMIT 1;
  END IF;

  -- Se não localizou, criar nova pessoa do responsável
  IF v_guardian_person_id IS NULL THEN
    INSERT INTO public.persons (
      tenant_id,
      full_name,
      cpf,
      birth_date,
      gender,
      phone,
      email,
      address
    )
    VALUES (
      p_tenant_id,
      v_guardian_name,
      v_clean_cpf,
      COALESCE((p_guardian_person->>'birth_date')::date, '1985-01-01'::date),
      COALESCE(p_guardian_person->>'gender', 'other'),
      p_guardian_person->>'phone',
      p_guardian_person->>'email',
      COALESCE(p_guardian_person->'address', '{}'::jsonb)
    )
    RETURNING id INTO v_guardian_person_id;
  ELSE
    -- Atualizar dados cadastrais e de contato da pessoa existente
    UPDATE public.persons
    SET
      full_name = v_guardian_name,
      phone = COALESCE(p_guardian_person->>'phone', phone),
      email = COALESCE(p_guardian_person->>'email', email),
      cpf = COALESCE(v_clean_cpf, cpf),
      updated_at = now()
    WHERE id = v_guardian_person_id AND tenant_id = p_tenant_id;
  END IF;

  -- 6. Upsert no vínculo guardian_relationships
  v_relationship_label := COALESCE(p_guardian_rel->>'relationship_label', 'Responsável');

  -- Se já existia outro responsável vinculado a este aluno, atualizar para o novo
  SELECT id INTO v_guardian_rel_id
  FROM public.guardian_relationships
  WHERE tenant_id = p_tenant_id AND student_id = p_student_id
  LIMIT 1;

  IF v_guardian_rel_id IS NOT NULL THEN
    UPDATE public.guardian_relationships
    SET
      guardian_person_id = v_guardian_person_id,
      relationship_label = v_relationship_label,
      is_legal_guardian = COALESCE((p_guardian_rel->>'is_legal_guardian')::boolean, true),
      is_financial_guardian = COALESCE((p_guardian_rel->>'is_financial_guardian')::boolean, true),
      is_emergency_contact = COALESCE((p_guardian_rel->>'is_emergency_contact')::boolean, true),
      is_pickup_authorized = COALESCE((p_guardian_rel->>'is_pickup_authorized')::boolean, true),
      notes = p_guardian_rel->>'notes'
    WHERE id = v_guardian_rel_id;
  ELSE
    INSERT INTO public.guardian_relationships (
      tenant_id,
      student_id,
      guardian_person_id,
      relationship_label,
      is_legal_guardian,
      is_financial_guardian,
      is_emergency_contact,
      is_pickup_authorized,
      notes
    )
    VALUES (
      p_tenant_id,
      p_student_id,
      v_guardian_person_id,
      v_relationship_label,
      COALESCE((p_guardian_rel->>'is_legal_guardian')::boolean, true),
      COALESCE((p_guardian_rel->>'is_financial_guardian')::boolean, true),
      COALESCE((p_guardian_rel->>'is_emergency_contact')::boolean, true),
      COALESCE((p_guardian_rel->>'is_pickup_authorized')::boolean, true),
      p_guardian_rel->>'notes'
    )
    RETURNING id INTO v_guardian_rel_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'action', 'linked',
    'guardian_person_id', v_guardian_person_id,
    'guardian_relationship_id', v_guardian_rel_id
  );
END;
$$;

-- 6. CONCEDER PERMISSÃO DE EXECUÇÃO
GRANT EXECUTE ON FUNCTION public.search_guardians_summary(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_student_guardian_link(uuid, uuid, boolean, jsonb, jsonb) TO authenticated;
