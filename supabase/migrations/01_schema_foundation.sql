-- ============================================================================
-- ARQUIVO: 01_schema_foundation.sql
-- OBJETIVO: Estrutura relacional normalizada com integridade multi-tenant estrita.
-- PROJETO: TatameHub (Gestão de Academias de Artes Marciais)
-- ============================================================================

-- 1. EXTENSÕES NECESSÁRIAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. ENUMS DE DOMÍNIO
DO $$ BEGIN
  CREATE TYPE app_role AS ENUM (
    'owner',
    'branch_manager',
    'secretary',
    'financial',
    'instructor',
    'student',
    'guardian'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE membership_status AS ENUM (
    'active',
    'suspended',
    'invited'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE tenant_status AS ENUM (
    'trial',
    'active',
    'suspended',
    'canceled'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE student_status AS ENUM (
    'active',
    'inactive',
    'suspended',
    'dropped'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE attendance_status AS ENUM (
    'present',
    'absent',
    'excused'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM (
    'pending',
    'paid',
    'overdue',
    'partially_paid',
    'canceled'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM (
    'pix',
    'boleto',
    'credit_card',
    'cash',
    'transfer'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 3. TABELA DE ACADEMIAS (TENANTS)
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_name text NOT NULL,
  legal_name text,
  cnpj_or_cpf text NOT NULL,
  admin_name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  whatsapp text,
  website text,
  logo_url text,
  address jsonb NOT NULL DEFAULT '{}'::jsonb,
  plan_id text NOT NULL DEFAULT 'trial',
  status tenant_status NOT NULL DEFAULT 'trial',
  trial_started_at timestamptz NOT NULL DEFAULT now(),
  trial_expires_at timestamptz NOT NULL DEFAULT (now() + interval '10 days'),
  retention_days int NOT NULL DEFAULT 60,
  settings jsonb NOT NULL DEFAULT '{
    "defaultDueDay": 10,
    "penaltyRate": 2.0,
    "dailyInterestRate": 0.033,
    "familyDiscount2ndMember": 15,
    "multiArtDiscount": 20
  }'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_tenants_id UNIQUE (id)
);

-- 4. TABELA DE FILIAIS (BRANCHES)
CREATE TABLE IF NOT EXISTS public.branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  is_headquarter boolean NOT NULL DEFAULT false,
  phone text,
  email text,
  address text,
  manager_name text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_branches_tenant_id_id UNIQUE (tenant_id, id)
);

-- 5. PERFIS DE USUÁRIOS (Vinculados a auth.users do Supabase)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  avatar_url text,
  phone text,
  is_platform_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 6. ASSOCIAÇÃO MULTI-TENANT DE USUÁRIOS (MEMBERSHIPS)
-- Permite que um usuário pertença a múltiplas academias com papéis e escopos independentes
CREATE TABLE IF NOT EXISTS public.tenant_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  branch_id uuid,
  role app_role NOT NULL,
  status membership_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_membership_branch FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE SET NULL,
  CONSTRAINT uq_tenant_user_role UNIQUE (tenant_id, user_id, role)
);

-- 7. TABELA UNIFICADA DE PESSOAS (Evita duplicação de CPF/indivíduos)
CREATE TABLE IF NOT EXISTS public.persons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  social_name text,
  cpf text,
  birth_date date NOT NULL,
  gender text CHECK (gender IN ('male', 'female', 'other')),
  phone text,
  email text,
  address jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_persons_tenant_id_id UNIQUE (tenant_id, id)
);

-- 8. ALUNOS (STUDENTS)
CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL,
  person_id uuid NOT NULL,
  registration_number text NOT NULL,
  enrollment_date date NOT NULL DEFAULT CURRENT_DATE,
  status student_status NOT NULL DEFAULT 'active',
  monthly_fee numeric(10,2) NOT NULL DEFAULT 0.00,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_students_tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT uq_students_tenant_reg UNIQUE (tenant_id, registration_number),
  CONSTRAINT fk_students_branch FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_students_person FOREIGN KEY (tenant_id, person_id)
    REFERENCES public.persons(tenant_id, id) ON DELETE RESTRICT
);

-- 9. RESPONSÁVEIS LEGAIS E FINANCEIROS (VÍNCULOS FAMILIARES)
CREATE TABLE IF NOT EXISTS public.guardian_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id uuid NOT NULL,
  guardian_person_id uuid NOT NULL,
  relationship_label text NOT NULL, -- 'Pai', 'Mãe', 'Tutor Legal', etc.
  is_legal_guardian boolean NOT NULL DEFAULT false,
  is_financial_guardian boolean NOT NULL DEFAULT false,
  is_emergency_contact boolean NOT NULL DEFAULT true,
  is_pickup_authorized boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_guardians_tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_guardians_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_guardians_person FOREIGN KEY (tenant_id, guardian_person_id)
    REFERENCES public.persons(tenant_id, id) ON DELETE RESTRICT
);

-- 10. DADOS SENSÍVEIS DE SAÚDE (LGPD - ISOLADOS COM ACESSO RESTRITO)
CREATE TABLE IF NOT EXISTS public.health_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id uuid NOT NULL,
  conditions text[] NOT NULL DEFAULT '{}',
  allergies text[] NOT NULL DEFAULT '{}',
  physical_restrictions text[] NOT NULL DEFAULT '{}',
  injury_history text,
  voluntary_medications text,
  emergency_contact_notes text,
  medical_cert_expiry_date date,
  medical_docs jsonb NOT NULL DEFAULT '[]'::jsonb, -- Anexos apontam para bucket privado
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_health_tenant_student UNIQUE (tenant_id, student_id),
  CONSTRAINT fk_health_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE
);

-- 11. DADOS FÍSICOS E ANTROPOMÉTRICOS
CREATE TABLE IF NOT EXISTS public.physical_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id uuid NOT NULL,
  date date NOT NULL DEFAULT CURRENT_DATE,
  weight_kg numeric(5,2) NOT NULL,
  height_cm numeric(5,2) NOT NULL,
  bmi numeric(4,1) NOT NULL,
  evaluator_name text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_assessments_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE
);

-- 12. MODALIDADES DE ARTES MARCIAIS
CREATE TABLE IF NOT EXISTS public.martial_arts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  origin text,
  description text,
  governing_federation text,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_martial_arts_tenant_id_id UNIQUE (tenant_id, id)
);

-- 13. SISTEMAS DE GRADUAÇÃO E FAIXAS (CONFIGURÁVEIS)
CREATE TABLE IF NOT EXISTS public.belt_ranks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  martial_art_id uuid NOT NULL,
  name text NOT NULL,
  rank_type text NOT NULL DEFAULT 'faixa',
  order_index int NOT NULL,
  color_hex text NOT NULL,
  stripe_color_hex text,
  min_age_years int NOT NULL DEFAULT 4,
  min_practice_months int NOT NULL DEFAULT 0,
  technical_requirements text,
  requires_exam boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_belt_ranks_tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_belts_martial_art FOREIGN KEY (tenant_id, martial_art_id)
    REFERENCES public.martial_arts(tenant_id, id) ON DELETE CASCADE
);

-- 14. HISTÓRICO DE GRADUAÇÃO DO ALUNO
CREATE TABLE IF NOT EXISTS public.student_graduations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id uuid NOT NULL,
  martial_art_id uuid NOT NULL,
  belt_rank_id uuid NOT NULL,
  graduated_at date NOT NULL DEFAULT CURRENT_DATE,
  examiner_name text NOT NULL,
  certificate_code text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_graduations_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_graduations_martial_art FOREIGN KEY (tenant_id, martial_art_id)
    REFERENCES public.martial_arts(tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_graduations_belt FOREIGN KEY (tenant_id, belt_rank_id)
    REFERENCES public.belt_ranks(tenant_id, id) ON DELETE RESTRICT
);

-- 15. TURMAS E HORÁRIOS DE TREINAMENTO
CREATE TABLE IF NOT EXISTS public.class_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL,
  martial_art_id uuid NOT NULL,
  name text NOT NULL,
  head_instructor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  head_instructor_name text NOT NULL,
  days_of_week int[] NOT NULL, -- 1: Seg, 2: Ter, 3: Qua, 4: Qui, 5: Sex, 6: Sáb, 0: Dom
  start_time time NOT NULL,
  end_time time NOT NULL,
  max_capacity int NOT NULL DEFAULT 20,
  min_age int NOT NULL DEFAULT 5,
  max_age int,
  tatami_room text NOT NULL DEFAULT 'Tatami Principal',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_class_groups_tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_classes_branch FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_classes_martial_art FOREIGN KEY (tenant_id, martial_art_id)
    REFERENCES public.martial_arts(tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT chk_class_time CHECK (start_time < end_time)
);

-- 16. MATRÍCULAS EM TURMAS
CREATE TABLE IF NOT EXISTS public.enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL,
  student_id uuid NOT NULL,
  class_group_id uuid NOT NULL,
  enrolled_at date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'canceled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_enrollment_student_class UNIQUE (tenant_id, student_id, class_group_id),
  CONSTRAINT fk_enrollments_branch FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_enrollments_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_enrollments_class FOREIGN KEY (tenant_id, class_group_id)
    REFERENCES public.class_groups(tenant_id, id) ON DELETE CASCADE
);

-- 17. CONTROLE DE FREQUÊNCIA (CHAMADA DO SENSEI)
CREATE TABLE IF NOT EXISTS public.attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  class_group_id uuid NOT NULL,
  student_id uuid NOT NULL,
  date date NOT NULL DEFAULT CURRENT_DATE,
  status attendance_status NOT NULL DEFAULT 'present',
  notes text,
  recorded_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recorded_by_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_attendance_student_class_date UNIQUE (tenant_id, class_group_id, student_id, date),
  CONSTRAINT fk_attendance_class FOREIGN KEY (tenant_id, class_group_id)
    REFERENCES public.class_groups(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_attendance_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE
);

-- 18. MENSALIDADES E COBRANÇAS
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL,
  student_id uuid NOT NULL,
  financial_guardian_person_id uuid,
  competence text NOT NULL, -- '10/2026'
  issue_date date NOT NULL DEFAULT CURRENT_DATE,
  due_date date NOT NULL,
  original_amount numeric(10,2) NOT NULL,
  discount_amount numeric(10,2) NOT NULL DEFAULT 0.00,
  discount_description text,
  penalty_and_interest numeric(10,2) NOT NULL DEFAULT 0.00,
  final_amount numeric(10,2) NOT NULL,
  paid_amount numeric(10,2) NOT NULL DEFAULT 0.00,
  balance numeric(10,2) NOT NULL,
  status invoice_status NOT NULL DEFAULT 'pending',
  payment_date date,
  payment_method payment_method,
  receipt_number text,
  pix_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_invoices_tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_invoices_branch FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_invoices_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_invoices_guardian FOREIGN KEY (tenant_id, financial_guardian_person_id)
    REFERENCES public.persons(tenant_id, id) ON DELETE SET NULL
);

-- 19. PAGAMENTOS PARCIAIS E HISTÓRICO FINANCEIRO
CREATE TABLE IF NOT EXISTS public.invoice_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  invoice_id uuid NOT NULL,
  amount numeric(10,2) NOT NULL,
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  payment_method payment_method NOT NULL,
  receipt_number text NOT NULL,
  registered_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  registered_by_name text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_payments_invoice FOREIGN KEY (tenant_id, invoice_id)
    REFERENCES public.invoices(tenant_id, id) ON DELETE CASCADE
);

-- 20. EXAMES DE GRADUAÇÃO
CREATE TABLE IF NOT EXISTS public.belt_exam_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL,
  martial_art_id uuid NOT NULL,
  title text NOT NULL,
  exam_date date NOT NULL,
  location text NOT NULL,
  chief_examiner_name text NOT NULL,
  target_ranks text[] NOT NULL DEFAULT '{}',
  exam_fee numeric(10,2) NOT NULL DEFAULT 0.00,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_exam_events_tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_exams_branch FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_exams_martial_art FOREIGN KEY (tenant_id, martial_art_id)
    REFERENCES public.martial_arts(tenant_id, id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.belt_exam_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  exam_id uuid NOT NULL,
  student_id uuid NOT NULL,
  current_belt text NOT NULL,
  target_belt text NOT NULL,
  target_belt_id uuid NOT NULL,
  fee_status text NOT NULL DEFAULT 'pending',
  result_status text NOT NULL DEFAULT 'pending',
  score numeric(3,1),
  examiner_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_exam_student UNIQUE (tenant_id, exam_id, student_id),
  CONSTRAINT fk_exam_reg_event FOREIGN KEY (tenant_id, exam_id)
    REFERENCES public.belt_exam_events(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_exam_reg_student FOREIGN KEY (tenant_id, student_id)
    REFERENCES public.students(tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_exam_reg_belt FOREIGN KEY (tenant_id, target_belt_id)
    REFERENCES public.belt_ranks(tenant_id, id) ON DELETE RESTRICT
);

-- 21. BIBLIOTECA DIGITAL DE VÍDEOS E DOCUMENTOS
CREATE TABLE IF NOT EXISTS public.digital_library_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  category text NOT NULL,
  media_type text NOT NULL CHECK (media_type IN ('video', 'pdf', 'document', 'link')),
  media_url text NOT NULL,
  thumbnail_url text,
  description text,
  martial_art_id uuid,
  target_belt_names text[] DEFAULT '{}',
  author_instructor text NOT NULL,
  published_date date NOT NULL DEFAULT CURRENT_DATE,
  access_scope text NOT NULL DEFAULT 'tenant_all',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_library_art FOREIGN KEY (tenant_id, martial_art_id)
    REFERENCES public.martial_arts(tenant_id, id) ON DELETE SET NULL
);

-- 22. TRILHA DE AUDITORIA IMUTÁVEL
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name text NOT NULL,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id text NOT NULL,
  timestamp timestamptz NOT NULL DEFAULT now(),
  details text NOT NULL
);

-- 23. ÍNDICES DE ALTA PERFORMANCE PARA ISOLAMENTO MULTI-TENANT
CREATE INDEX IF NOT EXISTS idx_branches_tenant ON public.branches(tenant_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON public.tenant_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_tenant ON public.tenant_memberships(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_students_tenant ON public.students(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_students_person ON public.students(tenant_id, person_id);
CREATE INDEX IF NOT EXISTS idx_guardians_student ON public.guardian_relationships(tenant_id, student_id);
CREATE INDEX IF NOT EXISTS idx_health_student ON public.health_records(tenant_id, student_id);
CREATE INDEX IF NOT EXISTS idx_classes_tenant ON public.class_groups(tenant_id, branch_id);
CREATE INDEX IF NOT EXISTS idx_attendance_search ON public.attendance_records(tenant_id, class_group_id, date);
CREATE INDEX IF NOT EXISTS idx_invoices_search ON public.invoices(tenant_id, status, due_date);
CREATE INDEX IF NOT EXISTS idx_audit_tenant_time ON public.audit_logs(tenant_id, timestamp DESC);
