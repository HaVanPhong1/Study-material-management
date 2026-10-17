"""
TẦNG DOMAIN — Ngoại lệ nghiệp vụ.

Cách thiết kế: tầng trên (Application) bắt các lỗi NGHIỆP VỤ này và chuyển
thành mã lỗi HTTP. Nhờ vậy, Domain không bao giờ phải "biết" mã 404/409 là gì.
Đây chính là ranh giới (boundary) mà Cashew bảo vệ nghiêm ngặt.
"""

from __future__ import annotations


class DomainError(Exception):
    """Lỗi nghiệp vụ gốc. Mọi lỗi nghiệp vụ khác đều kế thừa từ đây."""

    code = "DOMAIN_ERROR"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class DocumentNotFoundError(DomainError):
    """Không tìm thấy tài liệu theo định danh."""

    code = "DOCUMENT_NOT_FOUND"

    def __init__(self, document_id: str) -> None:
        super().__init__(f"Không tìm thấy tài liệu với mã '{document_id}'.")
        self.document_id = document_id


class DuplicateDocumentError(DomainError):
    """Trùng tài liệu: cùng tiêu đề và cùng môn học đã tồn tại."""

    code = "DUPLICATE_DOCUMENT"

    def __init__(self, title: str, subject: str) -> None:
        super().__init__(f"Tài liệu '{title}' của môn '{subject}' đã tồn tại.")
        self.title = title
        self.subject = subject


class InvalidDocumentError(DomainError):
    """Dữ liệu vi phạm quy tắc nghiệp vụ (quy đổi từ ValueError của rules)."""

    code = "INVALID_DOCUMENT"

    def __init__(self, message: str) -> None:
        super().__init__(message)
