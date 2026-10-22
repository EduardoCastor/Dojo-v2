-- ============================================================================
-- ARQUIVO: 04_storage_and_medical_bucket.sql
-- OBJETIVO: Configuração do bucket privado para documentos médicos e regras de Storage.
-- PROJETO: TatameHub (Gestão de Academias de Artes Marciais)
-- ============================================================================

-- 1. CRIAÇÃO DO BUCKET PRIVADO (SE NÃO EXISTIR)
-- public = false garante que nenhum documento seja acessível via URL pública
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'medical-documents',
  'medical-documents',
  false,
  10485760, -- Limite de 10 MB por arquivo
  ARRAY['application/pdf', 'image/jpeg', 'image/png']
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png'];

-- 2. HABILITAR RLS NO STORAGE
-- (Por padrão o Supabase Storage já possui RLS habilitado na tabela storage.objects)

-- 3. POLÍTICA DE LEITURA (DOWNLOAD / SIGNED URL):
-- O caminho do arquivo segue a convenção: {tenant_id}/{student_id}/{filename}
-- Somente pessoas autorizadas pela função can_access_health_record podem visualizar
DROP POLICY IF EXISTS "medical_storage_select" ON storage.objects;
CREATE POLICY "medical_storage_select" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'medical-documents'
  AND (
    -- Extrai tenant_id do primeiro segmento do path (path_tokens[1]) e student_id do segundo (path_tokens[2])
    public.can_access_health_record(
      (storage.foldername(name))[1]::uuid,
      (storage.foldername(name))[2]::uuid
    )
  )
);

-- 4. POLÍTICA DE UPLOAD (INSERT):
-- Apenas equipe autorizada da academia ou o próprio responsável legal
DROP POLICY IF EXISTS "medical_storage_insert" ON storage.objects;
CREATE POLICY "medical_storage_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'medical-documents'
  AND (
    public.has_tenant_role((storage.foldername(name))[1]::uuid, 'owner', 'branch_manager')
    OR public.is_guardian_of_student((storage.foldername(name))[2]::uuid)
  )
);

-- 5. POLÍTICA DE EXCLUSÃO (DELETE):
-- Apenas o proprietário da academia ou o responsável que enviou
DROP POLICY IF EXISTS "medical_storage_delete" ON storage.objects;
CREATE POLICY "medical_storage_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'medical-documents'
  AND (
    public.has_tenant_role((storage.foldername(name))[1]::uuid, 'owner')
    OR public.is_guardian_of_student((storage.foldername(name))[2]::uuid)
  )
);
