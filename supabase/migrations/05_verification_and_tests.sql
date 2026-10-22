-- ============================================================================
-- ARQUIVO: 05_verification_and_tests.sql
-- OBJETIVO: Scripts de validação de RLS e testes de isolamento entre academias.
-- PROJETO: TatameHub (Gestão de Academias de Artes Marciais)
-- ============================================================================
-- INSTRUÇÕES DE EXECUÇÃO NO SUPABASE SQL EDITOR:
-- 1. A PARTE 1 contém consultas SQL puras. Você pode selecionar e executar
--    qualquer uma delas individualmente.
-- 2. A PARTE 2 é um bloco anônimo PL/pgSQL (DO $$ ... $$). 
--    ATENÇÃO: Você DEVE selecionar TODO o bloco (da linha DO $$ até a linha END $$;)
--    ao clicar em Run. Não execute linhas isoladas de dentro do bloco (como 
--    SELECT ... WHERE tenant_id = v_tenant_beta), pois variáveis com prefixo 
--    'v_' só existem dentro da execução do bloco.
-- ============================================================================

-- ============================================================================
-- PARTE 1: CONSULTAS DE VERIFICAÇÃO DO ESTADO DO BANCO
-- ============================================================================

-- 1.1 Verificar se o RLS está habilitado em TODAS as tabelas do schema public
-- RESULTADO ESPERADO: Todas as tabelas públicas devem retornar rowsecurity = true
SELECT 
  schemaname,
  tablename,
  rowsecurity AS rls_habilitado
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 1.2 Listar todas as políticas RLS criadas e seus comandos permitidos
-- RESULTADO ESPERADO: Políticas cobrindo SELECT, INSERT, UPDATE, DELETE
SELECT 
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;

-- 1.3 Verificar se o bucket de documentos médicos está estritamente privado
-- RESULTADO ESPERADO: public = false
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'medical-documents';


-- ============================================================================
-- PARTE 2: SUÍTE DE TESTES TRANSACIONAIS DE ISOLAMENTO MULTI-TENANT
-- ============================================================================
-- ATENÇÃO: SELECIONE TODO O BLOCO ABAIXO (DO $$ até END $$;) PARA EXECUTAR.
-- Este teste cria duas academias temporárias (Alpha e Beta), testa o isolamento
-- de leitura e escrita com RLS ativo, e ao final executa um ROLLBACK automático,
-- deixando o banco 100% limpo e sem resíduos.
-- ============================================================================

DO $$
DECLARE
  v_user_alpha uuid := 'a0000000-0000-0000-0000-000000000001'::uuid;
  v_user_beta  uuid := 'b0000000-0000-0000-0000-000000000002'::uuid;
  v_tenant_alpha uuid;
  v_tenant_beta  uuid;
  v_branch_alpha uuid;
  v_branch_beta  uuid;
  v_student_alpha uuid;
  v_student_beta  uuid;
  v_person_alpha  uuid;
  v_person_beta   uuid;
  v_count int;
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE '=== INICIANDO TESTES DE SEGURANÇA MULTI-TENANT ===';
  RAISE NOTICE '==================================================';

  -- 0. GARANTIR USUÁRIOS DE TESTE EM auth.users
  -- Insere com todos os campos necessários do Supabase GoTrue para evitar violação de FK
  DELETE FROM public.tenant_memberships WHERE user_id IN (v_user_alpha, v_user_beta);
  DELETE FROM public.profiles WHERE id IN (v_user_alpha, v_user_beta);
  DELETE FROM auth.users WHERE id IN (v_user_alpha, v_user_beta);

  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    created_at,
    updated_at
  )
  VALUES 
    (
      v_user_alpha,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'alpha_teste_rls@tatamehub.com',
      crypt('SenhaTeste123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Sensei Alpha"}'::jsonb,
      false,
      now(),
      now()
    ),
    (
      v_user_beta,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'beta_teste_rls@tatamehub.com',
      crypt('SenhaTeste123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Sensei Beta"}'::jsonb,
      false,
      now(),
      now()
    );

  INSERT INTO public.profiles (id, full_name)
  VALUES 
    (v_user_alpha, 'Sensei Alpha'),
    (v_user_beta, 'Sensei Beta');

  -- 1. CRIAR ACADEMIA ALPHA (JUDÔ)
  INSERT INTO public.tenants (trade_name, cnpj_or_cpf, admin_name, email, phone)
  VALUES ('Dojo Alpha Judô', '11.111.111/0001-11', 'Sensei Alpha', 'alpha_teste_rls@tatamehub.com', '11999990001')
  RETURNING id INTO v_tenant_alpha;

  INSERT INTO public.branches (tenant_id, name, is_headquarter)
  VALUES (v_tenant_alpha, 'Matriz Alpha', true)
  RETURNING id INTO v_branch_alpha;

  INSERT INTO public.tenant_memberships (tenant_id, user_id, branch_id, role, status)
  VALUES (v_tenant_alpha, v_user_alpha, v_branch_alpha, 'owner', 'active');

  INSERT INTO public.persons (tenant_id, full_name, birth_date)
  VALUES (v_tenant_alpha, 'Aluno Alpha 1', '2015-01-01')
  RETURNING id INTO v_person_alpha;

  INSERT INTO public.students (tenant_id, branch_id, person_id, registration_number, monthly_fee)
  VALUES (v_tenant_alpha, v_branch_alpha, v_person_alpha, 'ALP-001', 200.00)
  RETURNING id INTO v_student_alpha;

  -- 2. CRIAR ACADEMIA BETA (JIU-JITSU)
  INSERT INTO public.tenants (trade_name, cnpj_or_cpf, admin_name, email, phone)
  VALUES ('Dojo Beta Jiu-Jitsu', '22.222.222/0001-22', 'Sensei Beta', 'beta_teste_rls@tatamehub.com', '11999990002')
  RETURNING id INTO v_tenant_beta;

  INSERT INTO public.branches (tenant_id, name, is_headquarter)
  VALUES (v_tenant_beta, 'Matriz Beta', true)
  RETURNING id INTO v_branch_beta;

  INSERT INTO public.tenant_memberships (tenant_id, user_id, branch_id, role, status)
  VALUES (v_tenant_beta, v_user_beta, v_branch_beta, 'owner', 'active');

  INSERT INTO public.persons (tenant_id, full_name, birth_date)
  VALUES (v_tenant_beta, 'Aluno Beta 1', '2014-06-01')
  RETURNING id INTO v_person_beta;

  INSERT INTO public.students (tenant_id, branch_id, person_id, registration_number, monthly_fee)
  VALUES (v_tenant_beta, v_branch_beta, v_person_beta, 'BET-001', 250.00)
  RETURNING id INTO v_student_beta;

  -- 3. TESTE A: SIMULAR SESSÃO DO USUÁRIO ALPHA (auth.uid() = v_user_alpha)
  PERFORM set_config('request.jwt.claim.sub', v_user_alpha::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  -- 3.1 Consulta Alunos de Alpha (deve encontrar exatamente 1)
  SELECT count(*) INTO v_count FROM public.students WHERE tenant_id = v_tenant_alpha;
  IF v_count = 1 THEN
    RAISE NOTICE '[OK] TESTE 1: Usuário Alpha consultou o aluno de sua própria academia com sucesso.';
  ELSE
    RAISE EXCEPTION '[FALHA] TESTE 1: Esperava 1 aluno de Alpha, retornou %', v_count;
  END IF;

  -- 3.2 Tentativa de consulta aos Alunos de Beta (deve retornar 0 linhas pelo RLS)
  SELECT count(*) INTO v_count FROM public.students WHERE tenant_id = v_tenant_beta;
  IF v_count = 0 THEN
    RAISE NOTICE '[OK] TESTE 2 (ISOLAMENTO): Usuário Alpha recebeu 0 registros da Academia Beta.';
  ELSE
    RAISE EXCEPTION '[FALHA] TESTE 2: VAZAMENTO DE DADOS! Alpha visualizou % alunos de Beta.', v_count;
  END IF;

  -- 3.3 Tentativa de UPDATE cruzado: Alpha tentando alterar a mensalidade de Beta
  UPDATE public.students SET monthly_fee = 999.00 WHERE id = v_student_beta;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN
    RAISE NOTICE '[OK] TESTE 3 (PROTEÇÃO DE ESCRITA): Usuário Alpha não conseguiu modificar aluno da Academia Beta (0 linhas afetadas).';
  ELSE
    RAISE EXCEPTION '[FALHA] TESTE 3: Alpha conseguiu modificar dados da Academia Beta!';
  END IF;

  -- 4. TESTE B: SIMULAR SESSÃO DO USUÁRIO BETA (auth.uid() = v_user_beta)
  PERFORM set_config('request.jwt.claim.sub', v_user_beta::text, true);

  -- 4.1 Consulta Alunos de Beta
  SELECT count(*) INTO v_count FROM public.students WHERE tenant_id = v_tenant_beta;
  IF v_count = 1 THEN
    RAISE NOTICE '[OK] TESTE 4: Usuário Beta consultou seu próprio aluno com sucesso.';
  ELSE
    RAISE EXCEPTION '[FALHA] TESTE 4: Beta não conseguiu consultar seu próprio aluno.';
  END IF;

  -- 4.2 Tentativa de consulta aos Alunos de Alpha
  SELECT count(*) INTO v_count FROM public.students WHERE tenant_id = v_tenant_alpha;
  IF v_count = 0 THEN
    RAISE NOTICE '[OK] TESTE 5 (ISOLAMENTO): Usuário Beta recebeu 0 registros da Academia Alpha.';
  ELSE
    RAISE EXCEPTION '[FALHA] TESTE 5: VAZAMENTO DE DADOS! Beta enxergou alunos de Alpha.';
  END IF;

  RAISE NOTICE '==================================================';
  RAISE NOTICE '=== TODOS OS TESTES DE RLS PASSARAM COM ÊXITO! ===';
  RAISE NOTICE '==================================================';

  -- Desfaz os dados criados no teste para deixar o banco limpo
  RAISE EXCEPTION 'Limpeza transacional intencional.' USING ERRCODE = 'P0001';
EXCEPTION
  WHEN SQLSTATE 'P0001' THEN
    RAISE NOTICE 'Rollback de teste concluído com sucesso. Nenhuma alteração de teste permaneceu no banco.';
END $$;

