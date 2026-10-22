-- ============================================================================
-- ARQUIVO: 03_row_level_security.sql
-- OBJETIVO: Habilitação de RLS em 100% das tabelas e criação de políticas estritas.
-- PROJETO: TatameHub (Gestão de Academias de Artes Marciais)
-- ============================================================================

-- 1. HABILITAR ROW LEVEL SECURITY EM TODAS AS TABELAS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardian_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.physical_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.martial_arts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.belt_ranks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_graduations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.belt_exam_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.belt_exam_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digital_library_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. POLÍTICAS: PROFILES
-- ============================================================================
DROP POLICY IF EXISTS "profiles_select_own_or_coworkers" ON public.profiles;
CREATE POLICY "profiles_select_own_or_coworkers" ON public.profiles
FOR SELECT TO authenticated
USING (
  id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.tenant_memberships m1
    JOIN public.tenant_memberships m2 ON m1.tenant_id = m2.tenant_id
    WHERE m1.user_id = auth.uid() AND m2.user_id = public.profiles.id
  )
);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ============================================================================
-- 3. POLÍTICAS: TENANTS
-- ============================================================================
DROP POLICY IF EXISTS "tenants_select_members" ON public.tenants;
CREATE POLICY "tenants_select_members" ON public.tenants
FOR SELECT TO authenticated
USING (public.is_tenant_member(id));

-- Inserção direta bloqueada: criações de academia DEVEM usar register_academy_atomic()
DROP POLICY IF EXISTS "tenants_insert_rpc_only" ON public.tenants;
CREATE POLICY "tenants_insert_rpc_only" ON public.tenants
FOR INSERT TO authenticated
WITH CHECK (false);

DROP POLICY IF EXISTS "tenants_update_owner_only" ON public.tenants;
CREATE POLICY "tenants_update_owner_only" ON public.tenants
FOR UPDATE TO authenticated
USING (public.has_tenant_role(id, 'owner'))
WITH CHECK (public.has_tenant_role(id, 'owner'));

-- ============================================================================
-- 4. POLÍTICAS: TENANT_MEMBERSHIPS (Vínculos e Papéis)
-- ============================================================================
DROP POLICY IF EXISTS "memberships_select_tenant" ON public.tenant_memberships;
CREATE POLICY "memberships_select_tenant" ON public.tenant_memberships
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_tenant_member(tenant_id));

-- Somente o proprietário da academia pode atribuir papéis a colaboradores
DROP POLICY IF EXISTS "memberships_insert_owner_only" ON public.tenant_memberships;
CREATE POLICY "memberships_insert_owner_only" ON public.tenant_memberships
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner'));

DROP POLICY IF EXISTS "memberships_update_owner_only" ON public.tenant_memberships;
CREATE POLICY "memberships_update_owner_only" ON public.tenant_memberships
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner'));

DROP POLICY IF EXISTS "memberships_delete_owner_only" ON public.tenant_memberships;
CREATE POLICY "memberships_delete_owner_only" ON public.tenant_memberships
FOR DELETE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner'));

-- ============================================================================
-- 5. POLÍTICAS: FILIAIS (BRANCHES)
-- ============================================================================
DROP POLICY IF EXISTS "branches_select_members" ON public.branches;
CREATE POLICY "branches_select_members" ON public.branches
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

DROP POLICY IF EXISTS "branches_insert_owner_only" ON public.branches;
CREATE POLICY "branches_insert_owner_only" ON public.branches
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner'));

DROP POLICY IF EXISTS "branches_update_admin" ON public.branches;
CREATE POLICY "branches_update_admin" ON public.branches
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager'));

-- ============================================================================
-- 6. POLÍTICAS: PESSOAS E ALUNOS (STUDENTS & PERSONS)
-- ============================================================================
DROP POLICY IF EXISTS "persons_select" ON public.persons;
CREATE POLICY "persons_select" ON public.persons
FOR SELECT TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial')
  OR email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

DROP POLICY IF EXISTS "persons_insert_staff" ON public.persons;
CREATE POLICY "persons_insert_staff" ON public.persons
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

DROP POLICY IF EXISTS "persons_update_staff" ON public.persons;
CREATE POLICY "persons_update_staff" ON public.persons
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

DROP POLICY IF EXISTS "students_select" ON public.students;
CREATE POLICY "students_select" ON public.students
FOR SELECT TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor', 'financial')
  OR public.is_own_student(id)
  OR public.is_guardian_of_student(id)
);

DROP POLICY IF EXISTS "students_insert_staff" ON public.students;
CREATE POLICY "students_insert_staff" ON public.students
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

DROP POLICY IF EXISTS "students_update_staff" ON public.students;
CREATE POLICY "students_update_staff" ON public.students
FOR UPDATE TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

-- ============================================================================
-- 7. POLÍTICAS: DADOS SENSÍVEIS DE SAÚDE (HEALTH_RECORDS - LGPD)
-- ============================================================================
DROP POLICY IF EXISTS "health_records_select_strict" ON public.health_records;
CREATE POLICY "health_records_select_strict" ON public.health_records
FOR SELECT TO authenticated
USING (public.can_access_health_record(tenant_id, student_id));

DROP POLICY IF EXISTS "health_records_insert_authorized" ON public.health_records;
CREATE POLICY "health_records_insert_authorized" ON public.health_records
FOR INSERT TO authenticated
WITH CHECK (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager')
  OR public.is_guardian_of_student(student_id)
);

DROP POLICY IF EXISTS "health_records_update_authorized" ON public.health_records;
CREATE POLICY "health_records_update_authorized" ON public.health_records
FOR UPDATE TO authenticated
USING (public.can_access_health_record(tenant_id, student_id))
WITH CHECK (public.can_access_health_record(tenant_id, student_id));

-- ============================================================================
-- 8. POLÍTICAS: TURMAS, MATRÍCULAS E FREQUÊNCIA
-- ============================================================================
DROP POLICY IF EXISTS "classes_select" ON public.class_groups;
CREATE POLICY "classes_select" ON public.class_groups
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

DROP POLICY IF EXISTS "classes_write_staff" ON public.class_groups;
CREATE POLICY "classes_write_staff" ON public.class_groups
FOR ALL TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary'));

DROP POLICY IF EXISTS "attendance_select" ON public.attendance_records;
CREATE POLICY "attendance_select" ON public.attendance_records
FOR SELECT TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'instructor')
  OR public.is_own_student(student_id)
  OR public.is_guardian_of_student(student_id)
);

DROP POLICY IF EXISTS "attendance_insert_sensei" ON public.attendance_records;
CREATE POLICY "attendance_insert_sensei" ON public.attendance_records
FOR INSERT TO authenticated
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'instructor', 'secretary'));

-- ============================================================================
-- 9. POLÍTICAS: FINANCEIRO (MENSALIDADES E PAGAMENTOS)
-- ============================================================================
DROP POLICY IF EXISTS "invoices_select" ON public.invoices;
CREATE POLICY "invoices_select" ON public.invoices
FOR SELECT TO authenticated
USING (
  public.has_tenant_role(tenant_id, 'owner', 'branch_manager', 'secretary', 'financial')
  OR public.is_own_student(student_id)
  OR public.is_guardian_of_student(student_id)
);

DROP POLICY IF EXISTS "invoices_write_financial" ON public.invoices;
CREATE POLICY "invoices_write_financial" ON public.invoices
FOR ALL TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'secretary', 'financial'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'secretary', 'financial'));

DROP POLICY IF EXISTS "payments_write_financial" ON public.invoice_payments;
CREATE POLICY "payments_write_financial" ON public.invoice_payments
FOR ALL TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner', 'secretary', 'financial'))
WITH CHECK (public.has_tenant_role(tenant_id, 'owner', 'secretary', 'financial'));

-- ============================================================================
-- 10. POLÍTICAS: GRADUAÇÕES, EXAMES E BIBLIOTECA
-- ============================================================================
DROP POLICY IF EXISTS "martial_arts_read" ON public.martial_arts;
CREATE POLICY "martial_arts_read" ON public.martial_arts
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

DROP POLICY IF EXISTS "belt_ranks_read" ON public.belt_ranks;
CREATE POLICY "belt_ranks_read" ON public.belt_ranks
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

DROP POLICY IF EXISTS "exams_read" ON public.belt_exam_events;
CREATE POLICY "exams_read" ON public.belt_exam_events
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

DROP POLICY IF EXISTS "library_read" ON public.digital_library_items;
CREATE POLICY "library_read" ON public.digital_library_items
FOR SELECT TO authenticated
USING (public.is_tenant_member(tenant_id));

DROP POLICY IF EXISTS "audit_logs_select" ON public.audit_logs;
CREATE POLICY "audit_logs_select" ON public.audit_logs
FOR SELECT TO authenticated
USING (public.has_tenant_role(tenant_id, 'owner'));

DROP POLICY IF EXISTS "audit_logs_insert" ON public.audit_logs;
CREATE POLICY "audit_logs_insert" ON public.audit_logs
FOR INSERT TO authenticated
WITH CHECK (public.is_tenant_member(tenant_id));
