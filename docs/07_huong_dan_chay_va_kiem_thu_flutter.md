# HƯỚNG DẪN CHẠY VÀ KIỂM THỬ TOÀN DIỆN (FLUTTER + SUPABASE + FIREBASE)

Thư mục `F:\APP_MOBILE\TH1` hiện tại đã được cấu hình thành **Full-stack Hybrid**:
1. **Frontend Flutter (Android/Web/iOS):** Code nằm trong `lib/` (Chạy trực tiếp trên Android Studio hoặc Terminal).
2. **Backend Python (FastAPI):** Code nằm trong `app/` (Phục vụ API & Web Admin tại `http://127.0.0.1:8000`).
3. **Database & RLS:** File SQL nằm tại `scripts/supabase_schema_and_rls.sql`.

---

## 1. THIẾT LẬP CƠ SỞ DỮ LIỆU & RLS TRÊN SUPABASE (LÀM 1 LẦN)

1. Đăng nhập vào [Supabase Dashboard](https://supabase.com).
2. Mở dự án của bạn -> Chọn mục **SQL Editor** ở thanh menu bên trái.
3. Mở file `F:\APP_MOBILE\TH1\scripts\supabase_schema_and_rls.sql`, copy toàn bộ nội dung và dán vào SQL Editor.
4. Bấm **RUN**:
   - Tự động tạo 3 bảng: `users`, `documents`, `permissions`.
   - Tự động bật `Row Level Security (RLS)` và thiết lập 8 chính sách bảo mật phân quyền.
   - Nạp sẵn dữ liệu kiểm thử (Seed Data) cho 3 người dùng:
     - `usera_owner@gmail.com` (Chủ sở hữu)
     - `userb_viewer@gmail.com` (Chỉ xem)
     - `userc_editor@gmail.com` (Được sửa)

---

## 2. CẤU HÌNH KẾT NỐI (FILE `lib/config/cloud_config.dart`)

Mở file `lib/config/cloud_config.dart` và điền thông tin Supabase của bạn:
```dart
class CloudConfig {
  static String supabaseUrl = 'https://your-project-id.supabase.co'; // Lấy tại Project Settings -> API
  static String supabaseAnonKey = 'your-supabase-anon-key';           // Lấy tại Project Settings -> API (anon public)
  static String firebaseStorageBucket = 'your-project-id.appspot.com';
}
```
*(Ghi chú: Nếu chưa điền key, App sẽ tự động chuyển sang chế độ **Demo Offline RLS Mock** để bạn vẫn test mượt mà các luồng phân quyền).*

---

## 3. CÁCH CHẠY ỨNG DỤNG TRÊN ANDROID STUDIO

1. Mở **Android Studio** -> Chọn **Open** -> Chọn thư mục `F:\APP_MOBILE\TH1`.
2. Chọn thiết bị chạy (Android Emulator hoặc Chrome).
3. Bấm nút **Run (tam giác xanh)** hoặc gõ lệnh terminal:
```bash
flutter run
```

---

## 4. KỊCH BẢN KIỂM THỬ 3 TÀI KHOẢN (ĐÁP ỨNG TIÊU CHÍ NỘP BÀI)

Màn hình đăng nhập cung cấp sẵn **3 nút chọn tài khoản Demo** (hoặc nút **Google Sign-In**):

### Bước 1: Đăng nhập bằng User A (Owner)
1. Bấm nút **User A (Chủ sở hữu - Owner)**.
2. Bạn sẽ thấy 2 tài liệu mẫu:
   - *Bài giảng Giải tích 1 - Đạo hàm*
   - *Đề thi cuối kỳ Lập trình Di động 2025*
3. Bấm nút menu (3 chấm): User A có toàn quyền: **Chỉnh sửa**, **Chia sẻ quyền**, **Xóa tài liệu**.
4. Bấm **Tải tài liệu lên (+)** -> Chọn file -> Điền thông tin -> Bấm Tải lên -> Tài liệu mới xuất hiện.
5. Bấm vào tài liệu -> Chọn **Chia sẻ quyền**:
   - Nhập email `userb_viewer@gmail.com` -> Chọn quyền **Chỉ xem (Viewer)**.
   - Nhập email `userc_editor@gmail.com` -> Chọn quyền **Được chỉnh sửa (Editor)**.

### Bước 2: Chuyển sang User B (Viewer - Người chỉ xem)
1. Bấm icon **Chuyển tài khoản (góc trên phải AppBar)** -> Chọn **User B (Viewer)**.
2. Bạn chỉ thấy tài liệu mà User A đã chia sẻ (*Bài giảng Giải tích 1*). Tài liệu *Đề thi di động* biến mất (do RLS chặn).
3. Thử kiểm tra phân quyền:
   - Thử bấm **Chỉnh sửa** -> App hoặc Supabase RLS sẽ **báo đỏ chặn ngay**: *"RLS Chặn: Bạn chỉ có quyền XEM"*.
   - Thử bấm **Xóa tài liệu** -> Bị **chặn**: *"Chỉ chủ sở hữu mới có quyền XÓA"*.
   - Thử bấm **Chia sẻ** -> Bị **chặn**: *"Chỉ chủ sở hữu mới có quyền chia sẻ"*.

### Bước 3: Chuyển sang User C (Editor - Người chỉnh sửa)
1. Bấm icon **Chuyển tài khoản** -> Chọn **User C (Editor)**.
2. Thấy tài liệu được chia sẻ với nhãn màu xanh dương: **Được phép sửa (Editor)**.
3. Bấm **Chỉnh sửa** -> Đổi tiêu đề hoặc năm -> Bấm **Lưu thay đổi** -> **Thành công**.
4. Thử bấm **Xóa tài liệu** -> Bị **RLS chặn**: *"Chỉ chủ sở hữu mới có quyền XÓA"*.

---

## 5. BẢNG TỔNG KẾT MINH CHỨNG HOÀN THÀNH

| Tiêu chuẩn yêu cầu | Trạng thái | Nơi lưu mã nguồn |
|---|---|---|
| **1. Firebase Google Sign-In** | ✅ Hoàn thành | `lib/services/auth_service.dart`, `lib/screens/login_screen.dart` |
| **2. Firebase Storage kết nối Supabase** | ✅ Hoàn thành | `lib/services/document_service.dart` (`uploadDocument`) |
| **3. Database Supabase 3 bảng** | ✅ Hoàn thành | `scripts/supabase_schema_and_rls.sql` |
| **4. Tìm kiếm, Cập nhật, Chia sẻ** | ✅ Hoàn thành | `lib/screens/document_list_screen.dart`, `share_screen.dart`, `edit_document_screen.dart` |
| **5. Row Level Security (RLS)** | ✅ Hoàn thành | 8 chính sách RLS trong `scripts/supabase_schema_and_rls.sql` |
| **6. Kiểm thử 3 tài khoản** | ✅ Hoàn thành | Tích hợp sẵn nút chuyển tài khoản A/B/C trực tiếp trên giao diện |
