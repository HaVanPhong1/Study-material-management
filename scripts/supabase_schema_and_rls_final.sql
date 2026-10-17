-- ============================================================================
-- SCRIPT CƠ SỞ DỮ LIỆU & RLS (FINAL - SUPABASE AUTH)
-- ============================================================================

-- 1. TẠO BẢNG (IF NOT EXISTS)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id UUID UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    doc_type TEXT NOT NULL CHECK (doc_type IN ('bai_giang', 'bai_tap', 'tai_lieu_tham_khao', 'de_thi')),
    author TEXT NOT NULL,
    year INTEGER NOT NULL CHECK (year BETWEEN 1900 AND 2100),
    storage_path TEXT,
    file_url TEXT,
    tags TEXT[] DEFAULT '{}',
    location_label TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Bảng yêu cầu mượn tài liệu vật lý
CREATE TABLE IF NOT EXISTS borrow_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'returned')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_level TEXT NOT NULL CHECK (permission_level IN ('view', 'edit')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(document_id, user_id)
);

-- 2. INDEXES
CREATE INDEX IF NOT EXISTS idx_users_supabase_user_id ON users(supabase_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_tags ON documents USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_permissions_doc_user ON permissions(document_id, user_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_doc ON borrow_requests(document_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_requester ON borrow_requests(requester_id);

-- 3. BẬT ROW LEVEL SECURITY (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE borrow_requests ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. HÀM HỖ TRỢ BẢO MẬT (SECURITY DEFINER - TRÁNH ĐỆ QUY VÔ TẬN RLS 42P17)
-- ============================================================================
-- Các hàm này chạy với quyền của creator, ngắt vòng lặp SELECT giữa documents và permissions.

CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT id FROM public.users WHERE supabase_user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_document_owner(doc_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.documents
    WHERE id = doc_id AND owner_id = public.current_app_user_id()
  );
$$;

CREATE OR REPLACE FUNCTION public.has_document_permission(doc_id UUID, required_level TEXT DEFAULT 'view')
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.permissions
    WHERE document_id = doc_id
      AND user_id = public.current_app_user_id()
      AND (required_level = 'view' OR permission_level = 'edit')
  );
$$;

GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_document_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_document_permission(UUID, TEXT) TO authenticated;

-- ============================================================================
-- 5. POLICIES (BẢO MẬT)
-- ============================================================================

-- 5.1. Bảng users
DROP POLICY IF EXISTS "Users read all" ON users;
CREATE POLICY "Users read all" ON users FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users upsert own" ON users;
CREATE POLICY "Users upsert own" ON users FOR ALL 
USING (supabase_user_id = auth.uid()) 
WITH CHECK (supabase_user_id = auth.uid());

-- 5.2. Bảng documents
DROP POLICY IF EXISTS "Documents select" ON documents;
CREATE POLICY "Documents select" ON documents FOR SELECT USING (
    owner_id = public.current_app_user_id() OR
    public.has_document_permission(id, 'view')
);

DROP POLICY IF EXISTS "Documents insert" ON documents;
CREATE POLICY "Documents insert" ON documents FOR INSERT WITH CHECK (
    owner_id = public.current_app_user_id()
);

DROP POLICY IF EXISTS "Documents update" ON documents;
CREATE POLICY "Documents update" ON documents FOR UPDATE 
USING (
    -- Chủ sở hữu OR Editor
    owner_id = public.current_app_user_id() OR
    public.has_document_permission(id, 'edit')
)
WITH CHECK (
    -- Chủ sở hữu có thể sửa tất cả. Editor không được đổi owner_id.
    -- Không SELECT lại documents trong policy này, tránh đệ quy RLS.
    owner_id = public.current_app_user_id() OR
    public.has_document_permission(id, 'edit')
);

DROP POLICY IF EXISTS "Documents delete" ON documents;
CREATE POLICY "Documents delete" ON documents FOR DELETE USING (
    owner_id = public.current_app_user_id()
);

-- 5.3. Bảng permissions
DROP POLICY IF EXISTS "Permissions select" ON permissions;
CREATE POLICY "Permissions select" ON permissions FOR SELECT USING (
    user_id = public.current_app_user_id() OR
    public.is_document_owner(document_id)
);

DROP POLICY IF EXISTS "Permissions insert" ON permissions;
CREATE POLICY "Permissions insert" ON permissions FOR INSERT WITH CHECK (
    public.is_document_owner(document_id)
);

DROP POLICY IF EXISTS "Permissions update" ON permissions;
CREATE POLICY "Permissions update" ON permissions FOR UPDATE USING (
    public.is_document_owner(document_id)
);

DROP POLICY IF EXISTS "Permissions delete" ON permissions;
CREATE POLICY "Permissions delete" ON permissions FOR DELETE USING (
    public.is_document_owner(document_id)
);

-- 5.4. Bảng borrow_requests
DROP POLICY IF EXISTS "Borrow requests select" ON borrow_requests;
CREATE POLICY "Borrow requests select" ON borrow_requests FOR SELECT USING (
    requester_id = public.current_app_user_id() OR
    public.is_document_owner(document_id)
);

DROP POLICY IF EXISTS "Borrow requests insert" ON borrow_requests;
CREATE POLICY "Borrow requests insert" ON borrow_requests FOR INSERT WITH CHECK (
    requester_id = public.current_app_user_id()
);

DROP POLICY IF EXISTS "Borrow requests update" ON borrow_requests;
CREATE POLICY "Borrow requests update" ON borrow_requests FOR UPDATE USING (
    public.is_document_owner(document_id)
);

-- ============================================================================
-- 5. STORAGE BUCKET & STORAGE ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Đảm bảo bucket 'documents' tồn tại và là private (bắt buộc xác thực và RLS)
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 5.1. STORAGE SELECT (TẢI / XEM FILE ĐÍNH KÈM)
-- Cho phép:
-- 1. Chủ sở hữu tài liệu (auth.uid() khớp tiền tố thư mục hoặc owner object)
-- 2. Người dùng được chia sẻ quyền (view hoặc edit) qua bảng permissions
DROP POLICY IF EXISTS "Documents storage select" ON storage.objects;
CREATE POLICY "Documents storage select" ON storage.objects FOR SELECT USING (
    bucket_id = 'documents' AND (
        -- Chủ sở hữu upload file
        owner = auth.uid() OR
        (string_to_array(name, '/'))[1] = auth.uid()::text OR
        -- Người dùng được cấp quyền xem hoặc sửa qua bảng permissions
        EXISTS (
            SELECT 1
            FROM public.documents d
            JOIN public.permissions p ON p.document_id = d.id
            JOIN public.users pu ON pu.id = p.user_id
            WHERE d.id::text = (string_to_array(storage.objects.name, '/'))[2]
              AND pu.supabase_user_id = auth.uid()
        )
    )
);

-- 5.2. STORAGE INSERT (UPLOAD FILE MỚI)
-- Chỉ người dùng đã đăng nhập và lưu file đúng thư mục auth.uid() của chính họ
DROP POLICY IF EXISTS "Documents storage insert" ON storage.objects;
CREATE POLICY "Documents storage insert" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'documents' AND
    auth.role() = 'authenticated' AND
    (string_to_array(name, '/'))[1] = auth.uid()::text
);

-- 5.3. STORAGE UPDATE (CẬP NHẬT FILE)
-- Chỉ chủ sở hữu file mới có quyền cập nhật file trong thư mục của mình
DROP POLICY IF EXISTS "Documents storage update" ON storage.objects;
CREATE POLICY "Documents storage update" ON storage.objects FOR UPDATE USING (
    bucket_id = 'documents' AND
    (owner = auth.uid() OR (string_to_array(name, '/'))[1] = auth.uid()::text)
);

-- 5.4. STORAGE DELETE (XÓA FILE)
-- Chỉ chủ sở hữu mới có quyền xóa file khỏi Storage
DROP POLICY IF EXISTS "Documents storage delete" ON storage.objects;
CREATE POLICY "Documents storage delete" ON storage.objects FOR DELETE USING (
    bucket_id = 'documents' AND
    (owner = auth.uid() OR (string_to_array(name, '/'))[1] = auth.uid()::text)
);

-- ============================================================================
-- 6. TRIGGER TỰ ĐỘNG CẬP NHẬT updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_documents_updated_at ON documents;
CREATE TRIGGER trigger_update_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
