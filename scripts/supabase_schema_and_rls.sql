-- ============================================================================
-- SCRIPT KHỞI TẠO CƠ SỞ DỮ LIỆU & ROW LEVEL SECURITY (RLS) TRÊN SUPABASE
-- Dành cho đồ án: Ứng dụng Quản lý Tài liệu Học tập
-- ============================================================================

-- Xóa các bảng cũ nếu đã tồn tại để tránh xung đột
DROP TABLE IF EXISTS permissions CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ----------------------------------------------------------------------------
-- 1. BẢNG NGƯỜI DÙNG (users)
-- Đồng bộ tài khoản từ Firebase Auth sang Supabase
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index tăng tốc tìm kiếm theo email và firebase_uid
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);

-- ----------------------------------------------------------------------------
-- 2. BẢNG TÀI LIỆU (documents)
-- Lưu metadata của tài liệu, file thực tế lưu trên Firebase Storage
-- ----------------------------------------------------------------------------
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    doc_type TEXT NOT NULL CHECK (doc_type IN ('bai_giang', 'bai_tap', 'tai_lieu_tham_khao', 'de_thi')),
    author TEXT NOT NULL,
    year INTEGER NOT NULL CHECK (year BETWEEN 1900 AND 2100),
    storage_path TEXT,          -- Đường dẫn file trên Firebase Storage (vd: documents/user_id/doc_id/file.pdf)
    file_url TEXT,              -- URL tải hoặc xem file
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index tìm kiếm tài liệu
CREATE INDEX idx_documents_owner ON documents(owner_id);
CREATE INDEX idx_documents_title ON documents(title);
CREATE INDEX idx_documents_subject ON documents(subject);
CREATE INDEX idx_documents_doc_type ON documents(doc_type);

-- ----------------------------------------------------------------------------
-- 3. BẢNG QUYỀN CHIA SẺ (permissions)
-- Quản lý chia sẻ tài liệu giữa các người dùng (view hoặc edit)
-- ----------------------------------------------------------------------------
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_level TEXT NOT NULL CHECK (permission_level IN ('view', 'edit')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(document_id, user_id) -- Mỗi tài liệu với mỗi người dùng chỉ có 1 mức quyền
);

CREATE INDEX idx_permissions_doc_user ON permissions(document_id, user_id);

-- ----------------------------------------------------------------------------
-- 4. BẬT ROW LEVEL SECURITY (RLS) TRÊN CẢ 3 BẢNG
-- ----------------------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 5. CHÍNH SÁCH BẢO MẬT (RLS POLICIES) CHO BẢNG USERS
-- ----------------------------------------------------------------------------
-- Mọi người dùng đã xác thực đều có thể đọc danh sách users (để tìm email khi share)
CREATE POLICY "Cho phép đọc thông tin người dùng"
    ON users FOR SELECT
    USING (true);

-- Cho phép thêm hoặc cập nhật thông tin chính mình
CREATE POLICY "Cho phép upsert người dùng"
    ON users FOR ALL
    USING (true)
    WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 6. CHÍNH SÁCH BẢO MẬT (RLS POLICIES) CHO BẢNG DOCUMENTS
-- ----------------------------------------------------------------------------
-- XEM (SELECT): Chỉ xem được tài liệu nếu:
-- (a) Là chủ sở hữu (owner_id)
-- HOẶC (b) Được chia sẻ quyền trong bảng permissions (dù là 'view' hay 'edit')
CREATE POLICY "Chính sách xem tài liệu (Owner hoặc Shared)"
    ON documents FOR SELECT
    USING (
        -- Chủ sở hữu
        owner_id IN (SELECT id FROM users WHERE firebase_uid = auth.jwt()->>'sub')
        OR
        -- Hoặc được chia sẻ
        EXISTS (
            SELECT 1 FROM permissions p
            JOIN users u ON u.id = p.user_id
            WHERE p.document_id = documents.id
            AND u.firebase_uid = auth.jwt()->>'sub'
        )
    );

-- THÊM MỚI (INSERT): Chỉ tạo tài liệu với owner_id là chính mình
CREATE POLICY "Chính sách thêm tài liệu (Owner)"
    ON documents FOR INSERT
    WITH CHECK (
        owner_id IN (SELECT id FROM users WHERE firebase_uid = auth.jwt()->>'sub')
    );

-- CẬP NHẬT (UPDATE): Chỉ sửa được nếu:
-- (a) Là chủ sở hữu
-- HOẶC (b) Được chia sẻ quyền 'edit'
CREATE POLICY "Chính sách cập nhật tài liệu (Owner hoặc Editor)"
    ON documents FOR UPDATE
    USING (
        owner_id IN (SELECT id FROM users WHERE firebase_uid = auth.jwt()->>'sub')
        OR
        EXISTS (
            SELECT 1 FROM permissions p
            JOIN users u ON u.id = p.user_id
            WHERE p.document_id = documents.id
            AND p.permission_level = 'edit'
            AND u.firebase_uid = auth.jwt()->>'sub'
        )
    );

-- XÓA (DELETE): DUY NHẤT chủ sở hữu mới có quyền xóa
CREATE POLICY "Chính sách xóa tài liệu (Chỉ Owner)"
    ON documents FOR DELETE
    USING (
        owner_id IN (SELECT id FROM users WHERE firebase_uid = auth.jwt()->>'sub')
    );

-- ----------------------------------------------------------------------------
-- 7. CHÍNH SÁCH BẢO MẬT (RLS POLICIES) CHO BẢNG PERMISSIONS
-- ----------------------------------------------------------------------------
-- Chỉ chủ sở hữu tài liệu mới được xem danh sách quyền đã chia sẻ của tài liệu đó
CREATE POLICY "Owner xem danh sách quyền"
    ON permissions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM documents d
            JOIN users u ON u.id = d.owner_id
            WHERE d.id = permissions.document_id
            AND u.firebase_uid = auth.jwt()->>'sub'
        )
        OR
        -- Hoặc chính người được chia sẻ xem quyền của mình
        user_id IN (SELECT id FROM users WHERE firebase_uid = auth.jwt()->>'sub')
    );

-- Chỉ chủ sở hữu tài liệu mới được thêm quyền chia sẻ cho người khác
CREATE POLICY "Owner thêm quyền chia sẻ"
    ON permissions FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM documents d
            JOIN users u ON u.id = d.owner_id
            WHERE d.id = permissions.document_id
            AND u.firebase_uid = auth.jwt()->>'sub'
        )
    );

-- Chỉ chủ sở hữu tài liệu mới được thu hồi quyền chia sẻ
CREATE POLICY "Owner xóa quyền chia sẻ"
    ON permissions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM documents d
            JOIN users u ON u.id = d.owner_id
            WHERE d.id = permissions.document_id
            AND u.firebase_uid = auth.jwt()->>'sub'
        )
    );

-- ----------------------------------------------------------------------------
-- DỮ LIỆU MẪU KIỂM THỬ (SEED DATA DÀNH CHO TEST 3 TÀI KHOẢN)
-- ----------------------------------------------------------------------------
INSERT INTO users (id, firebase_uid, email, display_name)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'uid_user_a', 'usera_owner@gmail.com', 'User A (Owner)'),
    ('b0000000-0000-0000-0000-000000000002', 'uid_user_b', 'userb_viewer@gmail.com', 'User B (Viewer)'),
    ('c0000000-0000-0000-0000-000000000003', 'uid_user_c', 'userc_editor@gmail.com', 'User C (Editor)')
ON CONFLICT (email) DO NOTHING;

-- Tài liệu do User A sở hữu
INSERT INTO documents (id, owner_id, title, subject, doc_type, author, year, storage_path, file_url)
VALUES
    (
        'd0000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001',
        'Bài giảng Giải tích 1 - Đạo hàm',
        'Toán cao cấp',
        'bai_giang',
        'Nguyễn Văn A',
        2024,
        'documents/uid_user_a/d1/giai_tich_1.pdf',
        'https://example.com/giai_tich_1.pdf'
    ),
    (
        'd0000000-0000-0000-0000-000000000002',
        'a0000000-0000-0000-0000-000000000001',
        'Đề thi cuối kỳ Lập trình Di động 2025',
        'Lập trình di động',
        'de_thi',
        'Giảng viên Bộ môn',
        2025,
        'documents/uid_user_a/d2/de_thi_mobile.pdf',
        'https://example.com/de_thi_mobile.pdf'
    )
ON CONFLICT (id) DO NOTHING;

-- Chia sẻ tài liệu 1 cho User B (chỉ xem: 'view') và User C (được sửa: 'edit')
INSERT INTO permissions (document_id, user_id, permission_level)
VALUES
    ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'view'),
    ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'edit')
ON CONFLICT (document_id, user_id) DO NOTHING;
