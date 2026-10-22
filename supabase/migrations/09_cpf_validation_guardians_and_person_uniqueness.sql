-- ============================================================================
-- ARQUIVO: 09_cpf_validation_guardians_and_person_uniqueness.sql
-- OBJETIVO: Validação matemática de CPF, unicidade de CPF por tenant,
--           reutilização de pessoas entre alunos e responsáveis e
--           funções RPC para gestão de vínculos familiares no TatameHub.
-- ============================================================================

-- 1. FUNÇÃO UTILITÁRIA PARA LIMPEZA DE CPF NO POSTGRESQL
CREATE OR REPLACE FUNCTION public.clean_cpf(p_cpf text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g');
$$;

-- 2. FUNÇÃO PARA VALIDAÇÃO MATEMÁTICA RIGOROSA DE CPF (MÓDULO 11)
CREATE OR REPLACE FUNCTION public.is_valid_cpf(p_cpf text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_clean text;
  v_sum1 integer := 0;
  v_sum2 integer := 0;
  v_digit1 integer;
  v_digit2 integer;
  v_rest1 integer;
  v_rest2 integer;
  i integer;
BEGIN
  v_clean := public.clean_cpf(p_cpf);

  -- 1. Deve possuir exatamente 11 dígitos
  IF length(v_clean) <> 11 THEN
    RETURN false;
  END IF;

  -- 2. Não pode conter todos os dígitos iguais (ex: 00000000000, 11111111111)
  IF v_clean ~ '^([0-9])\1{10}$' THEN
    RETURN false;
  END IF;

  -- 3. Cálculo do 1º Dígito Verificador (pesos de 10 a 2)
  FOR i IN 1..9 LOOP
    v_sum1 := v_sum1 + substring(v_clean from i for 1)::integer * (11 - i);
  END LOOP;
  v_rest1 := (v_sum1 * 10) % 11;
  IF v_rest1 = 10 OR v_rest1 = 11 THEN
    v_rest1 := 0;
  END IF;
  v_digit1 := substring(v_clean from 10 for 1)::integer;
  IF v_rest1 <> v_digit1 THEN
    RETURN false;
  END IF;

  -- 4. Cálculo do 2º Dígito Verificador (pesos de 11 a 2)
  FOR i IN 1..10 LOOP
    v_sum2 := v_sum2 + substring(v_clean from i for 1)::integer * (12 - i);
  END LOOP;
  v_rest2 := (v_sum2 * 10) % 11;
  IF v_rest2 = 10 OR v_rest2 = 11 THEN
    v_rest2 := 0;
  END IF;
  v_digit2 := substring(v_clean from 11 for 1)::integer;
  IF v_rest2 <> v_digit2 THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

-- 3. ÍNDICE ÚNICO DE CPF POR ACADEMIA (TENANT_ID)
-- Garante que dentro da mesma academia o mesmo CPF limpo não possa ser duplicado em persons,
-- permitindo que a mesma pessoa seja tanto Aluno quanto Responsável.
CREATE UNIQUE INDEX IF NOT EXISTS uq_persons_tenant_clean_cpf
ON public.persons (tenant_id, public.clean_cpf(cpf))
WHERE cpf IS NOT NULL AND length(public.clean_cpf(cpf)) = 11;

-- 4. ÍNDICE DE PESQUISA RÁPIDA POR NOME E CPF LIMPO
CREATE INDEX IF NOT EXISTS idx_persons_tenant_cpf_clean
ON public.persons (tenant_id, public.clean_cpf(cpf));

CREATE INDEX IF NOT EXISTS idx_persons_tenant_name_trgm
ON public.persons (tenant_id, full_name);

-- 5. EVITAR DUPLICAÇÃO DE VÍNCULO FAMILIAR IDÊNTICO
CREATE UNIQUE INDEX IF NOT EXISTS uq_guardian_student_relationship
ON public.guardian_relationships (tenant_id, student_id, guardian_person_id);

-- ============================================================================
-- 6. RPC ATUALIZADA: REGISTER_STUDENT_ATOMIC
-- ============================================================================
-- Reutiliza a mesma pessoa caso o CPF já exista na academia, permitindo:
-- - Responsável existente se matricular como aluno sem duplicar cadastro.
-- - Aluno existente ser vinculado como responsável.
-- - Responsável de um aluno ser reutilizado para outro irmão/dependente.
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
  v_student_id uuid;
  v_guardian_person_id uuid;
  v_guardian_rel_id uuid;
  v_graduation_id uuid;
  v_registration_num text;
  v_monthly_fee numeric;
  v_student_name text;
  v_student_cpf text;
  v_guardian_name text;
  v_guardian_cpf text;
BEGIN
  -- 1. Validar autenticação
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: o usuário precisa estar autenticado.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Validar permissão na academia
  IF NOT public.has_tenant_role(p_tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor') THEN
    RAISE EXCEPTION 'Permissão insuficiente para cadastrar alunos nesta academia.'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Validar e normalizar dados do Aluno
  v_student_name := trim(COALESCE(p_person->>'full_name', ''));
  IF v_student_name = '' THEN
    RAISE EXCEPTION 'O nome completo do aluno é obrigatório.'
      USING ERRCODE = '23502';
  END IF;

  v_student_cpf := public.clean_cpf(p_person->>'cpf');
  IF v_student_cpf = '' THEN
    v_student_cpf := NULL;
  END IF;

  -- Se CPF foi informado, validar matematicamente
  IF v_student_cpf IS NOT NULL AND NOT public.is_valid_cpf(v_student_cpf) THEN
    RAISE EXCEPTION 'O CPF do aluno (%) é matematicamente inválido.', p_person->>'cpf'
      USING ERRCODE = '22023';
  END IF;

  -- Gerar matrícula única caso não informada
  v_registration_num := trim(COALESCE(p_student->>'registration_number', ''));
  IF v_registration_num = '' THEN
    v_registration_num := 'MAT-' || to_char(CURRENT_DATE, 'YYYY') || '-' || floor(1000 + random() * 9000)::text;
  END IF;

  v_monthly_fee := COALESCE((p_student->>'monthly_fee')::numeric, 0.00);

  -- 4. Criar ou reutilizar Pessoa do Aluno (Person)
  IF v_student_cpf IS NOT NULL THEN
    SELECT id INTO v_student_person_id
    FROM public.persons
    WHERE tenant_id = p_tenant_id AND public.clean_cpf(cpf) = v_student_cpf
    LIMIT 1;

    -- Se a pessoa já possuir matrícula ativa de aluno nesta academia, impedir duplicação de aluno
    IF v_student_person_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1 FROM public.students
        WHERE tenant_id = p_tenant_id AND person_id = v_student_person_id
      ) THEN
        RAISE EXCEPTION 'Já existe uma matrícula cadastrada para este CPF nesta academia.'
          USING ERRCODE = '23505';
      END IF;
    END IF;
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
    -- Atualiza dados de contato da pessoa já existente (ex: que era apenas responsável e virou aluno)
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
    v_guardian_name := trim(p_guardian_person->>'full_name');
    v_guardian_cpf := public.clean_cpf(p_guardian_person->>'cpf');
    IF v_guardian_cpf = '' THEN
      v_guardian_cpf := NULL;
    END IF;

    -- Validar CPF do responsável se informado
    IF v_guardian_cpf IS NOT NULL AND NOT public.is_valid_cpf(v_guardian_cpf) THEN
      RAISE EXCEPTION 'O CPF do responsável (%) é matematicamente inválido.', p_guardian_person->>'cpf'
        USING ERRCODE = '22023';
    END IF;

    -- Localizar se o responsável já existe na academia por CPF limpo
    IF v_guardian_cpf IS NOT NULL THEN
      SELECT id INTO v_guardian_person_id
      FROM public.persons
      WHERE tenant_id = p_tenant_id AND public.clean_cpf(cpf) = v_guardian_cpf
      LIMIT 1;
    END IF;

    -- Se não encontrou por CPF, criar a pessoa do responsável
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
        v_guardian_cpf,
        COALESCE((p_guardian_person->>'birth_date')::date, '1985-01-01'::date),
        COALESCE(p_guardian_person->>'gender', 'other'),
        p_guardian_person->>'phone',
        p_guardian_person->>'email',
        COALESCE(p_guardian_person->'address', '{}'::jsonb)
      )
      RETURNING id INTO v_guardian_person_id;
    ELSE
      -- Atualiza contatos se fornecidos
      UPDATE public.persons
      SET
        full_name = v_guardian_name,
        phone = COALESCE(p_guardian_person->>'phone', phone),
        email = COALESCE(p_guardian_person->>'email', email),
        updated_at = now()
      WHERE id = v_guardian_person_id;
    END IF;

    -- Criar ou atualizar o vínculo familiar
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
    ON CONFLICT (tenant_id, student_id, guardian_person_id)
    DO UPDATE SET
      relationship_label = EXCLUDED.relationship_label,
      is_legal_guardian = EXCLUDED.is_legal_guardian,
      is_financial_guardian = EXCLUDED.is_financial_guardian
    RETURNING id INTO v_guardian_rel_id;
  END IF;

  -- 7. Se houver graduação inicial (faixa)
  IF p_graduation IS NOT NULL AND p_graduation->>'martial_art_id' IS NOT NULL AND p_graduation->>'belt_rank_id' IS NOT NULL THEN
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
      (p_graduation->>'martial_art_id')::uuid,
      (p_graduation->>'belt_rank_id')::uuid,
      COALESCE((p_graduation->>'graduated_at')::date, CURRENT_DATE),
      COALESCE(p_graduation->>'examiner_name', 'Sensei Responsável'),
      p_graduation->>'notes'
    )
    RETURNING id INTO v_graduation_id;
  END IF;

  -- 8. Auditoria de Criação
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
      'Administrador',
      'Matrícula de Aluno',
      'students',
      v_student_id,
      'Aluno ' || v_student_name || ' (Matrícula: ' || v_registration_num || ') cadastrado com sucesso.'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'student_id', v_student_id,
    'person_id', v_student_person_id,
    'guardian_person_id', v_guardian_person_id,
    'guardian_relationship_id', v_guardian_rel_id,
    'graduation_id', v_graduation_id,
    'registration_number', v_registration_num
  );
END;
$$;

-- 7. CONCEDER PERMISSÃO DE EXECUÇÃO
GRANT EXECUTE ON FUNCTION public.clean_cpf(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_valid_cpf(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_student_atomic(uuid, uuid, jsonb, jsonb, jsonb, jsonb, jsonb) TO authenticated;
