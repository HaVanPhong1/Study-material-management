"""
Script nạp dữ liệu mẫu — chạy:  python -m scripts.seed_data

Script này cũng là MINH CHỨNG cho tính linh hoạt của kiến trúc:
cùng một mã nghiệp vụ chạy được trên 3 tầng lưu trữ, chỉ khác tham số cấu hình.
Thử đổi backend bằng biến môi trường, ví dụ:

    STORAGE_BACKEND=in_memory python -m scripts.seed_data
"""

from __future__ import annotations

import sys

from app.application import DocumentCreateData, DocumentService
from app.config import Settings
from app.container import build_container
from app.domain import DuplicateDocumentError, DocumentType

SAMPLES = [
    ("Giải tích 1 - Chương 3: Đạo hàm", "Toán học", DocumentType.BAI_GIANG, "Nguyễn Văn A", 2024, "https://example.com/dao-ham.pdf"),
    ("Bài tập Giải tích 1 - Học kỳ 1", "Toán học", DocumentType.BAI_TAP, "Nguyễn Văn A", 2023, None),
    ("Giáo trình Lập trình Python", "Lập trình", DocumentType.TAI_LIEU_THAM_KHAO, "Trần Thị B", 2022, None),
    ("Đề thi cuối kỳ Lập trình Python 2023", "Lập trình", DocumentType.DE_THI, "Trần Thị B", 2023, None),
    ("Slide Cấu trúc dữ liệu và Giải thuật", "Cấu trúc dữ liệu", DocumentType.BAI_GIANG, "Lê Văn C", 2025, None),
    ("Bài giảng Cấu trúc dữ liệu - Cây nhị phân", "Cấu trúc dữ liệu", DocumentType.BAI_GIANG, "Lê Văn C", 2024, None),
    ("Tài liệu ôn thi môn Lập trình", "Lập trình", DocumentType.TAI_LIEU_THAM_KHAO, "Phạm Thị D", 2025, None),
]


def seed(service: DocumentService) -> int:
    created = 0
    for title, subject, doc_type, author, year, file_url in SAMPLES:
        try:
            service.create_document(
                DocumentCreateData(
                    title=title, subject=subject, doc_type=doc_type,
                    author=author, year=year, file_url=file_url,
                )
            )
            created += 1
        except DuplicateDocumentError:
            print(f"  - Bỏ qua (đã tồn tại): {title}")
    return created


def main() -> int:
    # Console Windows mặc định dùng cp1252/cp1258, không in được tiếng Việt có dấu.
    # Chuyển stdout sang UTF-8 để script chạy được trên mọi máy.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    settings = Settings.from_env()
    container = build_container(settings)
    print(f"> Đang nạp dữ liệu lên backend: {container.backend}")

    service = container.create_document_service()
    created = seed(service)

    # Đọc lại để chứng minh dữ liệu thật sự nằm trong kho lưu trữ.
    from app.application import DocumentSearchData

    total = service.count_documents(DocumentSearchData())
    print(f"> Đã tạo {created}/{len(SAMPLES)} tài liệu. Tổng số trong kho: {total}")

    container.dispose()
    return 0


if __name__ == "__main__":
    sys.exit(main())
