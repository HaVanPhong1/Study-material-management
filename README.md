# Ứng dụng Quản lý Tài liệu Học tập — KIẾN TRÚC CASHEW

> Dự án bài tập lớn: xây dựng ứng dụng quản lý tài liệu học tập với đầy đủ chức năng
> CRUD + Tìm kiếm/Lọc, theo kiến trúc phân tầng **Cashew** (tách biệt trách nhiệm,
> phụ thuộc một chiều, đảo ngược phụ thuộc).

---

## 1. Chạy nhanh (3 lệnh)

```bash
# 1) Cài thư viện
pip install -r requirements.txt

# 2) Chạy ứng dụng
uvicorn app.main:app --reload

# 3) Mở trình duyệt
#    Giao diện web  : http://127.0.0.1:8000/        <- mở trực tiếp, có đầy đủ chức năng
#    Tài liệu API  : http://127.0.0.1:8000/docs
```

Sau khi chạy:

- **Giao diện web** tại `/` — form thêm/sửa, bảng danh sách, ô tìm kiếm & lọc, nút xoá,
  có phân trang và hiển thị thông báo lỗi 404/409/422.
- **Swagger UI** tại `/docs` — dùng để kiểm chứng API thủ công.

Chạy bộ kiểm thử (149 test):

```bash
pip install -r requirements-dev.txt
pytest
```

Nạp dữ liệu mẫu để demo:

```bash
python -m scripts.seed_data
```

## 2. Công nghệ sử dụng

| Thành phần     | Lựa chọn              | Vai trò trong kiến trúc                        |
|----------------|-----------------------|-------------------------------------------------|
| Python         | 3.11+                 | Ngôn ngữ                                       |
| FastAPI        | 0.110+                | **Tầng Presentation** (HTTP, OpenAPI)           |
| Pydantic       | 2.x                   | Kiểm tra dữ liệu ở biên, sinh tài liệu API      |
| SQLAlchemy     | 2.x                   | **Tầng Infrastructure** (ORM)                   |
| SQLite         | mặc định              | Hệ quản trị CSDL ở mức demo/kỳ thi             |
| pytest         | 8+                    | Mục 4 — kiểm thử & kiểm chứng luật kiến trúc    |

## 3. Danh mục chức năng (Checklist)

| # | Chức năng                     | Endpoint                                          |
|---|-------------------------------|---------------------------------------------------|
| 1 | Thêm tài liệu                 | `POST   /api/documents`                           |
| 2 | Xem danh sách / Tìm kiếm     | `GET    /api/documents?keyword=&subject=&doc_type=&year_from=&year_to=&limit=&offset=` |
| 3 | Xem chi tiết                  | `GET    /api/documents/{id}`                      |
| 4 | Cập nhật tài liệu             | `PUT    /api/documents/{id}`                      |
| 5 | Xóa tài liệu                  | `DELETE /api/documents/{id}`                      |
| 6 | Kiểm tra sức khoẻ dịch vụ     | `GET    /api/health`                              |

## 4. Cấu trúc thư mục (Cashew 4 tầng)

```text
TH1/
├── app/
│   ├── main.py                     # Điểm khởi động + Application Factory
│   ├── config.py                   # Cấu hình (đọc biến môi trường)
│   ├── container.py                # ★ COMPOSITION ROOT: lắp ráp dependency
│   │
│   ├── domain/                     # TẦNG LÕI — không biết công nghệ
│   │   ├── entities.py             #   Entity Document, enum DocumentType, DocumentFilter
│   │   ├── rules.py                #   Quy tắc nghiệp vụ bất biến
│   │   ├── repository.py           #   ★ INTERFACE DocumentRepository (ABC)
│   │   └── exceptions.py           #   Lỗi nghiệp vụ (không chứa mã HTTP)
│   │
│   ├── application/                # TẦNG NGHIỆP VỤ — điều phối use-case
│   │   ├── document_service.py     #   ★ 5 use-case: Create/Read/Update/Delete/Search
│   │   └── dto.py                  #   DTO vào/ra ranh giới ứng dụng
│   │
│   ├── infrastructure/             # TẦNG KỸ THUẬT — biết CÁCH lưu trữ
│   │   ├── db.py                   #   Engine, Session, transaction
│   │   ├── orm_models.py           #   Bảng `documents` (khác entity Domain!)
│   │   ├── sql_alchemy_document_repository.py   # Hiện thực #1: SQL
│   │   └── in_memory_document_repository.py     # Hiện thực #2: RAM
│   │
│   └── presentation/               # TẦNG TRÌNH BÀY — biết HTTP
│       ├── dependencies.py         #   Cấp Service cho từng request
│       ├── error_handlers.py       #   Ánh xạ lỗi nghiệp vụ -> mã HTTP
│       ├── schemas.py              #   Pydantic: Request/Response
│       ├── web/index.html          #   ★ Giao diện web (HTML/CSS/JS thuần)
│       └── api/
│           └── documents_router.py #   Định nghĩa endpoint (mỏng)
│
├── tests/                          # MỤC 4
│   ├── fakes.py                    #   Fake + Exploding repository
│   ├── conftest.py                 #   Fixture dùng chung
│   ├── test_domain.py              #   Unit test Domain
│   ├── test_document_service.py    #   Unit test Service (không cần DB)
│   ├── test_repositories.py        #   Unit test từng repository
│   ├── test_repository_independence.py  # ★ BẢO CHỨNG độc lập tầng
│   ├── test_api.py                 #   Integration/E2E test
│   ├── test_architecture.py        # ★ Tự kiểm tra luật phụ thuộc một chiều
│   └── test_web_ui.py              #   Kiểm thử giao diện
│
├── scripts/seed_data.py            # Nạp dữ liệu mẫu
├── docs/                           # BÁO CÁO (Mục 1, 2, 5)
├── requirements.txt
├── requirements-dev.txt
├── pytest.ini
└── README.md
```

## 5. Quy tắc vàng của dự án

> **Mũi tên phụ thuộc chỉ được hướng VÀO TRONG.**
> Presentation → Application → Domain ← Infrastructure

1. `app/domain/` **không** được import FastAPI, Pydantic, SQLAlchemy.
2. `app/application/` **không** được import FastAPI, SQLAlchemy, `infrastructure`.
3. `app/presentation/` **không** được biết SQL.
4. Chỉ `app/container.py` được phép "biết" cả `application` lẫn `infrastructure`.

Các quy tắc trên **được kiểm tra tự động** bởi `tests/test_architecture.py`
(đọc AST của toàn bộ mã nguồn). Nếu ai đó vi phạm, `pytest` sẽ báo đỏ ngay.

## 6. Đổi tầng dữ liệu chỉ bằng 1 dòng cấu hình

```bash
# SQLite trên đĩa (mặc định)
uvicorn app.main:app

# Chạy hoàn toàn trong RAM, không cần database
$env:STORAGE_BACKEND="in_memory"; uvicorn app.main:app --reload

# Trỏ sang PostgreSQL
$env:STORAGE_BACKEND="sqlite"; $env:DATABASE_URL="postgresql://user:pass@localhost/db"
uvicorn app.main:app
```

**Không một dòng code nghiệp vụ nào phải sửa.**

## 7. Vài ví dụ gọi API

> Giao diện web đã gọi sẵn các endpoint dưới đây. Phần này dùng khi cần kiểm chứng
> API thủ công hoặc trình bày trong báo cáo.

```bash
# Thêm mới
curl -X POST http://127.0.0.1:8000/api/documents -H "Content-Type: application/json" -d '{
  "title": "Giải tích 1 - Chương 3: Đạo hàm",
  "subject": "Toán học",
  "doc_type": "bai_giang",
  "author": "Nguyễn Văn A",
  "year": 2024,
  "file_url": "https://example.com/dao-ham.pdf"
}'

# Tìm kiếm theo từ khoá + lọc loại + khoảng năm
curl "http://127.0.0.1:8000/api/documents?keyword=giáo trình&doc_type=bai_giang&year_from=2020"

# Cập nhật (chỉ gửi trường muốn sửa)
curl -X PUT http://127.0.0.1:8000/api/documents/<id> -H "Content-Type: application/json" -d '{"year": 2025}'

# Xóa
curl -X DELETE http://127.0.0.1:8000/api/documents/<id>
```

## 8. Tài liệu báo cáo

| File | Nội dung |
|------|----------|
| [`docs/01_phan_tich_yeu_cau.md`](docs/01_phan_tich_yeu_cau.md) | **Mục 1** — Yêu cầu chức năng, DFD, luồng dữ liệu |
| [`docs/02_kien_truc_cashew.md`](docs/02_kien_truc_cashew.md) | **Mục 2** — Cấu trúc thư mục, trách nhiệm từng tầng |
| [`docs/03_ke_hoach_kiem_thu.md`](docs/03_ke_hoach_kiem_thu.md) | **Mục 4** — Chiến lược & kết quả kiểm thử |
| [`docs/04_bao_cao_giiai_trinh.md`](docs/04_bao_cao_giiai_trinh.md) | **Mục 5** — Báo cáo giải trình tổng hợp kèm sơ đồ |
