# KỊCH BẢN VIDEO 2 PHÚT — 5 TIÊU CHÍ KIẾN TRÚC CASHEW

> **Cách dùng:** mở file này in ra, đặt cạnh màn hình. Cột **"CHỈ VÀO"** là nơi bạn
> dùng chuột (hoặc dùng `Ctrl+G` trong VS Code) nhảy tới trước khi đọc câu thoại.
> Mỗi khối bắt đầu bằng `⏱` là mốc thời gian.

---

## CHUẨN BỊ (làm 1 lần, TRƯỚC khi bấm quay — không quay phần này)

```powershell
cd F:\APP_MOBILE\TH1
pip install -r requirements.txt -r requirements-dev.txt
python -m scripts.seed_data          # tạo sẵn dữ liệu mẫu
python -m uvicorn app.main:app      # để nguyên terminal này, không tắt
```

Mở sẵn 3 tab Chrome (xếp cạnh nhau):

| Tab | Nội dung | Dùng cho |
|-----|----------|---------|
| 1 | `http://127.0.0.1:8000/` | Mục 3 — demo giao diện |
| 2 | VS Code, mở `app/domain/repository.py` | Mục 2 — chỉ interface |
| 3 | VS Code, mở `tests/test_repository_independence.py` | Mục 4 — chạy test |

Tắt thông báo Windows, tắt WiFi popup, không để màn hình hiện tên/email cá nhân.

---

## PHẦN A — MỞ ĐẦU (5 giây)

**⏱ 0:00**

> **CHỈ VÀO:** màn hình đen → bật tab 1 (giao diện).

**LỜI THOẠI:**
> "Em xin phép trình bày ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew."

---

## PHẦN B — TIÊU CHÍ 1: PHÂN TÍCH YÊU CẦU + SƠ ĐỒ LUỒNG DỮ LIỆU (20 giây)

**⏱ 0:05**

> **CHỈ VÀO:** `docs/01_phan_tich_yeu_cau.md` — cuộn tới bảng FR-01, rồi tới sơ đồ DFD mức 1.

**LỜI THOẠI:**
> "Mục một: em phân tích **14 yêu cầu chức năng** — CRUD tài liệu, tìm kiếm theo từ khoá, môn học, loại tài liệu, khoảng năm — và **6 yêu cầu phi chức năng**.
> DFD mức một em thiết kế **cố ý trùng với 4 tầng kiến trúc**, để DFD và sơ đồ phần mềm là hai cách nhìn của cùng một hệ thống."

---

## PHẦN C — TIÊU CHÍ 2: CẤU TRÚC THƯ MỤC VÀ PHÂN LỚP (20 giây)

**⏱ 0:25**

> **CHỈ VÀO:** VS Code Explorer — mở rộng `app/`. Sau đó nhảy `app/domain/repository.py:28`.

**LỜI THOẠI:**
> "Mục hai: hệ thống có **4 tầng** — `domain`, `application`, `infrastructure`, `presentation` — cùng `container.py` làm Composition Root.
> Trái tim là **interface** `DocumentRepository` nằm ngay trong Domain. Tầng nghiệp vụ phụ thuộc vào *hợp đồng* này, không phụ thuộc vào SQLAlchemy. Mũi tên phụ thuộc luôn hướng **vào trong**."

---

## PHẦN D — TIÊU CHÍ 3: CÁC CHỨC NĂNG CỐT LÕI (35 giây)

**⏱ 0:45**

> **CHỈ VÀO:** tab 1. Thêm một tài liệu mới → bấm **Thêm**. Bấm **Sửa** trên một dòng, sửa năm, bấm **Lưu thay đổi**.

**LỜI THOẠI:**
> "Mục ba: em triển khai đủ **Thêm, Sửa, Xóa, Tìm kiếm**. Mỗi thao tác đi xuyên suốt từ giao diện → Service → Repository."

**⏱ 1:00** — *chỉ tìm kiếm*

> **CHỈ VÀO:** ô "từ khoá", gõ `giáo`, chọn loại `Tài liệu tham khảo`, bấm **Tìm kiếm**.

**LỜI THOẠI:**
> "Tìm kiếm kết hợp được từ khoá, môn học, loại tài liệu và khoảng năm. Kết quả **phân trang** sẵn."

**⏱ 1:10** — *demo lỗi nghiệp vụ*

> **CHỈ VÀO:** bấm **Thêm tài liệu** lại với đúng tiêu đề và môn vừa tạo → thông báo đỏ hiện ra.

**LỜI THOẠI:**
> "Thêm trùng tiêu đề và môn, giao diện báo lỗi **409**. Mã lỗi do tầng nghiệp vụ quyết định và được ánh xạ sang HTTP tại `error_handlers.py`, không viết trong giao diện."

---

## PHẦN E — TIÊU CHÍ 4: KIỂM THỬ TÍNH ĐỘC LẬP GIỮA CÁC LỚP (35 giây)

**⏱ 1:20** — *chạy test, quay màn hình terminal*

> **CHỈ VÀO:** VS Code, file `tests/test_repository_independence.py:61`.

**LỜI THOẠI:**
> "Mục bốn: em có **149 test, tất cả đều pass** trong 1,3 giây, không cần cài database."

**⏱ 1:30** — *chạy lệnh, chờ xanh*

```powershell
pytest tests/test_repository_independence.py -q
```

> **CHỈ VÀO:** dòng `@pytest.fixture(params=["fake", "in_memory", "sqlite"])` trong file đang mở.

**LỜI THOẠI:**
> "Đây là bằng chứng quan trọng nhất: **một bộ test nghiệp vụ, viết một lần**, được chạy lại trên **ba tầng lưu trữ** — giả lập, trong RAM, và SQLite thật. Cả ba đều xanh. Nghĩa là đổi tầng dữ liệu thì tầng nghiệp vụ **không một dòng nào phải sửa**."

**⏱ 1:42** — *luật kiến trúc tự kiểm tra*

```powershell
pytest tests/test_architecture.py -q
```

> **CHỈ VÀO:** `tests/test_architecture.py:32` — bảng `FORBIDDEN_IMPORTS`.

**LỜI THOẠI:**
> "Thêm nữa, em mã hóa luật kiến trúc thành **test tự động**: đọc AST của toàn bộ mã nguồn và cấm import sai tầng. Nếu ai đó lỡ tay thêm SQL vào tầng nghiệp vụ, `pytest` sẽ **báo đỏ ngay**."

---

## PHẦN F — TIÊU CHÍ 5: ĐÓNG GÓI VÀ BÁO CÁO GIẢI TRÌNH (20 giây)

**⏱ 1:50**

> **CHỈ VÀO:** VS Code Explorer — `README.md`, `requirements.txt`, rồi thư mục `docs/`.

**LỜI THOẠI:**
> "Mục năm: mã nguồn đã đóng gói đầy đủ — `README.md` hướng dẫn cài và chạy, `requirements.txt` khai báo phụ thuộc, toàn bộ mã nằm trong `app`, kiểm thử trong `tests`.
> Báo cáo giải trình gồm **4 tài liệu** với **12 sơ đồ Mermaid**: phân tích yêu cầu và DFD, kiến trúc kèm giải thích vì sao tách vậy, kế hoạch kiểm thử, và báo cáo tổng hợp phân tích tính mô-đun hoá, khả năng mở rộng."

**⏱ 2:00**

> **LỜI THOẠI:**
> "Ứng dụng đáp ứng đủ năm tiêu chí. Em xin phép nhận câu hỏi. Em cảm ơn thầy."

---

## BẢNG ĐỐI CHIẾU NHANH (dán cạnh màn hình khi quay)

| Mốc | Tiêu chí | Bằng chứng trên màn hình | Câu then chốt |
|------|----------|---------------------------|----------------|
| 0:05 | **1** | `docs/01_...md` — bảng FR + DFD mức 1 | "14 FR + 6 NFR, DFD trùng 4 tầng kiến trúc" |
| 0:25 | **2** | Explorer `app/` → `repository.py:28` | "Interface nằm trong Domain, mũi tên hướng vào trong" |
| 0:45 | **3** | Giao diện: thêm → sửa → tìm → xoá → lỗi 409 | "Thêm, Sửa, Xóa, Tìm kiếm đi xuyên suốt 4 tầng" |
| 1:20 | **4** | `pytest` xanh + `test_repository_independence.py:61` | "1 bộ test × 3 tầng lưu trữ — đổi DB không ảnh hưởng nghiệp vụ" |
| 1:50 | **5** | `README.md` + thư mục `docs/` | "12 sơ đồ Mermaid, phân tích mô-đun hoá & mở rộng" |

---

## NẾU BỊ HỎI CÂU NÀY (nói ngắn, đủ ý)

| Câu hỏi | Trả lời 1–2 câu |
|---------|-----------------|
| "Vì sao interface đặt ở Domain mà không ở Infrastructure?" | Vì đó là hợp đồng mà tầng trên cần. Đặt ở Domain thì Application được phép biết; đặt ở Infrastructure thì Application phải import hạ tầng, mất đảo ngược phụ thuộc. |
| "Document và DocumentORM khác nhau gì?" | `Document` là khái niệm nghiệp vụ, bất biến, nằm ở Domain. `DocumentORM` là hình dạng bảng CSDL, nằm ở Infrastructure. Tách để đổi schema không kéo theo logic. |
| "DTO khác Entity ở chỗ nào?" | Entity sống, có quy tắc, có thể sửa hỏng. DTO chỉ mang dữ liệu qua ranh giới ứng dụng, nên tầng trên không thể sửa dữ liệu lõi. |
| "Làm sao biết không có phụ thuộc ngược?" | `tests/test_architecture.py` đọc AST và kiểm tra tự động 4 luật. Vi phạm là test đỏ. |
| "Đổi SQLite sang PostgreSQL cần làm gì?" | Chỉ đặt biến `DATABASE_URL`. Không sửa dòng nào trong `domain`, `application`, `presentation`. |
| "Sao chặn `limit` tối đa 100?" | Chống truy vấn quá lớn làm cạn tài nguyên — bảo vệ tầng trình bày trước khi xuống tới hạ tầng. |

---

## MẸO KHI QUAY

- **Tốc độ nói:** hơi chậm hơn bình thường một chút; 2 phút khoảng **280 từ**.
- **Chỉ chuột, đừng di chuyển cửa sổ vô tình** — mọi thao tác phải có chủ đích.
- **Không đọc nguyên văn câu thoại**; nhìn vào cột `CHỈ VÀO`, rồi nói lại bằng lời của mình.
- **Luôn để terminal hiện kết quả xanh** trước khi quay cảnh `pytest`.
- **Thu âm rõ**, để nguyên 2 phút không cắt ghép — GV xem video liền mạch sẽ dễ chấm điểm hơn.