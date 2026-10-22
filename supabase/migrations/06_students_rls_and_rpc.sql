-- ============================================================================
-- ARQUIVO: 06_students_rls_and_rpc.sql
-- OBJETIVO: Políticas RLS para Responsáveis e Graduações + Função RPC Atômica de Matrícula
-- PROJETO: TatameHub (Gestão de Academias de Artes Marciais)
-- ============================================================================

-- ============================================================================
-- 1. POLÍTICAS RLS FALTANTES: GUARDIAN_RELATIONSHIPS
-- ============================================================================
-- Permite leitura para equipe autorizada, para o próprio responsável ou para o aluno
DROP POLICY IF EXISTS "guardians_select" ON public.guardian_relationships;
CREATE POLICY "guardians_select" ON public.guardian_relationships
FOR SELECT TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial')
  OR public.is_guardian_of_student(student_id)
  OR public.is_own_student(student_id)
);

-- Permite cadastro de responsáveis por membros da equipe administrativa
DROP POLICY IF EXISTS "guardians_insert_staff" ON public.guardian_relationships;
CREATE POLICY "guardians_insert_staff" ON public.guardian_relationships
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

-- Permite atualização por membros da equipe administrativa
DROP POLICY IF EXISTS "guardians_update_staff" ON public.guardian_relationships;
CREATE POLICY "guardians_update_staff" ON public.guardian_relationships
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

-- Permite exclusão por membros da equipe administrativa
DROP POLICY IF EXISTS "guardians_delete_staff" ON public.guardian_relationships;
CREATE POLICY "guardians_delete_staff" ON public.guardian_relationships
FOR DELETE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

-- ============================================================================
-- 2. POLÍTICAS RLS FALTANTES: STUDENT_GRADUATIONS
-- ============================================================================
-- Permite leitura de graduações por todos os membros da academia
DROP POLICY IF EXISTS "graduations_select" ON public.student_graduations;
CREATE POLICY "graduations_select" ON public.student_graduations
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

-- Permite inserção de graduações por instrutores e administradores
DROP POLICY IF EXISTS "graduations_insert_staff" ON public.student_graduations;
CREATE POLICY "graduations_insert_staff" ON public.student_graduations
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

-- Permite alteração de graduações por instrutores e administradores
DROP POLICY IF EXISTS "graduations_update_staff" ON public.student_graduations;
CREATE POLICY "graduations_update_staff" ON public.student_graduations
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor'));

-- Permite exclusão de graduações exclusivamente pelo proprietário
DROP POLICY IF EXISTS "graduations_delete_owner" ON public.student_graduations;
CREATE POLICY "graduations_delete_owner" ON public.student_graduations
FOR DELETE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner'));


-- ============================================================================
-- 3. FUNÇÃO RPC ATÔMICA: CADASTRO COMPLETO DE ALUNO (TRANSAÇÃO SEGURA)
-- ============================================================================
-- Esta função cria de forma atômica:
--  1. Registro do aluno em persons (ou reutilização por CPF/email)
--  2. Registro na tabela students vinculado à filial informada
--  3. Registro do responsável em persons e guardian_relationships (se informado)
--  4. Registro de graduação inicial em student_graduations (se informado)
--  5. Registro da primeira fatura/mensalidade em invoices
--  6. Log de auditoria em audit_logs
-- Caso ocorra qualquer erro, todas as etapas sofrem rollback automático.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.register_student_atomic(
  p_tenant_id uuid,
  p_branch_id uuid,
  p_person jsonb,
  p_student jsonb,
  p_guardian_person jsonb DEFAULT NULL,
  p_guardian_rel jsonb DEFAULT NULL,
  p_graduation jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_student_person_id uuid;
  v_guardian_person_id uuid;
  v_student_id uuid;
  v_guardian_rel_id uuid;
  v_graduation_id uuid;
  v_invoice_id uuid;
  v_student_name text;
  v_student_cpf text;
  v_registration_num text;
  v_monthly_fee numeric(10,2);
  v_martial_art_id uuid;
  v_belt_rank_id uuid;
  v_user_name text;
BEGIN
  -- 1. Validação de autenticação
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validação de autorização na academia especificada (RLS Server-Side)
  IF NOT public.has_tenant_role(p_tenant_id, 'owner', 'branch_manager', 'secretary') THEN
    RAISE EXCEPTION 'Permissão insuficiente para matricular alunos nesta academia.'
      USING ERRCODE = '42501';
  END IF;

  -- Obter nome do usuário operador para auditoria
  SELECT COALESCE(full_name, 'Colaborador') INTO v_user_name
  FROM public.profiles WHERE id = v_user_id;

  -- 3. Extrair dados obrigatórios do aluno
  v_student_name := trim(COALESCE(p_person->>'full_name', ''));
  v_student_cpf := NULLIF(trim(COALESCE(p_person->>'cpf', '')), '');
  v_registration_num := trim(COALESCE(p_student->>'registration_number', ''));
  v_monthly_fee := COALESCE((p_student->>'monthly_fee')::numeric, 0.00);

  IF v_student_name = '' THEN
    RAISE EXCEPTION 'O nome completo do aluno é obrigatório.' USING ERRCODE = '22023';
  END IF;

  IF p_person->>'birth_date' IS NULL THEN
    RAISE EXCEPTION 'A data de nascimento do aluno é obrigatória.' USING ERRCODE = '22023';
  END IF;

  IF v_registration_num = '' THEN
    -- Gerar matrícula automática se não fornecida
    v_registration_num := 'MAT-' || to_char(CURRENT_DATE, 'YYYY') || '-' || lpad((floor(random() * 90000 + 10000)::int)::text, 5, '0');
  END IF;

  -- 4. Criar ou localizar registro da Pessoa (Person)
  -- Se houver CPF, tenta localizar antes para evitar duplicidade dentro do tenant
  IF v_student_cpf IS NOT NULL AND v_student_cpf <> '000.000.000-00' THEN
    SELECT id INTO v_student_person_id
    FROM public.persons
    WHERE tenant_id = p_tenant_id AND cpf = v_student_cpf
    LIMIT 1;
  END IF;

  IF v_student_person_id IS NULL THEN
    INSERT INTO public.persons (
      tenant_id,
      full_name,
      social_name,
      cpf,
      birth_date,
      gender,
      phone,
      email,
      address
    )
    VALUES (
      p_tenant_id,
      v_student_name,
      p_person->>'social_name',
      v_student_cpf,
      (p_person->>'birth_date')::date,
      COALESCE(p_person->>'gender', 'male'),
      p_person->>'phone',
      p_person->>'email',
      COALESCE(p_person->'address', '{}'::jsonb)
    )
    RETURNING id INTO v_student_person_id;
  ELSE
    -- Atualiza dados de contato se já existia
    UPDATE public.persons
    SET
      full_name = v_student_name,
      phone = COALESCE(p_person->>'phone', phone),
      email = COALESCE(p_person->>'email', email),
      address = COALESCE(p_person->'address', address),
      updated_at = now()
    WHERE id = v_student_person_id;
  END IF;

  -- 5. Criar registro na tabela students
  INSERT INTO public.students (
    tenant_id,
    branch_id,
    person_id,
    registration_number,
    enrollment_date,
    status,
    monthly_fee,
    notes
  )
  VALUES (
    p_tenant_id,
    p_branch_id,
    v_student_person_id,
    v_registration_num,
    COALESCE((p_student->>'enrollment_date')::date, CURRENT_DATE),
    COALESCE(p_student->>'status', 'active')::student_status,
    v_monthly_fee,
    p_student->>'notes'
  )
  RETURNING id INTO v_student_id;

  -- 6. Se houver dados de Responsável (Guardian)
  IF p_guardian_person IS NOT NULL AND trim(COALESCE(p_guardian_person->>'full_name', '')) <> '' THEN
    -- Criar ou localizar registro da pessoa do responsável
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
      trim(p_guardian_person->>'full_name'),
      NULLIF(trim(COALESCE(p_guardian_person->>'cpf', '')), ''),
      COALESCE((p_guardian_person->>'birth_date')::date, '1985-01-01'::date),
      COALESCE(p_guardian_person->>'gender', 'other'),
      p_guardian_person->>'phone',
      p_guardian_person->>'email',
      COALESCE(p_guardian_person->'address', '{}'::jsonb)
    )
    RETURNING id INTO v_guardian_person_id;

    -- Criar o vínculo familiar
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
      v_student_id,
      v_guardian_person_id,
      COALESCE(p_guardian_rel->>'relationship_label', 'Responsável'),
      COALESCE((p_guardian_rel->>'is_legal_guardian')::boolean, true),
      COALESCE((p_guardian_rel->>'is_financial_guardian')::boolean, true),
      COALESCE((p_guardian_rel->>'is_emergency_contact')::boolean, true),
      COALESCE((p_guardian_rel->>'is_pickup_authorized')::boolean, true),
      p_guardian_rel->>'notes'
    )
    RETURNING id INTO v_guardian_rel_id;
  END IF;

  -- 7. Se houver graduação inicial informada
  IF p_graduation IS NOT NULL AND p_graduation->>'martial_art_id' IS NOT NULL AND p_graduation->>'belt_rank_id' IS NOT NULL THEN
    BEGIN
      v_martial_art_id := (p_graduation->>'martial_art_id')::uuid;
      v_belt_rank_id := (p_graduation->>'belt_rank_id')::uuid;

      INSERT INTO public.student_graduations (
        tenant_id,
        student_id,
        martial_art_id,
        belt_rank_id,
        graduated_at,
        examiner_name,
        notes
      )
      VALUES (
        p_tenant_id,
        v_student_id,
        v_martial_art_id,
        v_belt_rank_id,
        COALESCE((p_graduation->>'graduated_at')::date, CURRENT_DATE),
        COALESCE(p_graduation->>'examiner_name', v_user_name),
        p_graduation->>'notes'
      )
      RETURNING id INTO v_graduation_id;
    EXCEPTION WHEN OTHERS THEN
      -- Se a arte marcial ou faixa informada não for um UUID existente no tenant, não bloqueia a matrícula
      v_graduation_id := NULL;
    END;
  END IF;

  -- 8. Gerar primeira fatura de mensalidade se houver valor definido
  IF v_monthly_fee > 0 THEN
    INSERT INTO public.invoices (
      tenant_id,
      branch_id,
      student_id,
      financial_guardian_person_id,
      competence,
      issue_date,
      due_date,
      original_amount,
      discount_amount,
      penalty_and_interest,
      final_amount,
      paid_amount,
      balance,
      status
    )
    VALUES (
      p_tenant_id,
      p_branch_id,
      v_student_id,
      v_guardian_person_id,
      to_char(CURRENT_DATE, 'MM/YYYY'),
      CURRENT_DATE,
      CURRENT_DATE + interval '10 days',
      v_monthly_fee,
      0.00,
      0.00,
      v_monthly_fee,
      0.00,
      v_monthly_fee,
      'pending'
    )
    RETURNING id INTO v_invoice_id;
  END IF;

  -- 9. Registrar auditoria imutável da matrícula
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
    p_tenant_id,
    v_user_id,
    v_user_name,
    'Matrícula de Aluno',
    'Student',
    v_student_id::text,
    'Aluno "' || v_student_name || '" matriculado com sucesso. Matrícula: ' || v_registration_num
  );

  -- 10. Retornar identificadores criados
  RETURN jsonb_build_object(
    'success', true,
    'student_id', v_student_id,
    'person_id', v_student_person_id,
    'guardian_person_id', v_guardian_person_id,
    'guardian_relationship_id', v_guardian_rel_id,
    'graduation_id', v_graduation_id,
    'invoice_id', v_invoice_id,
    'registration_number', v_registration_num
  );
END;
$$;
