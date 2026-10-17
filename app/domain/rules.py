"""
TẦNG DOMAIN — Quy tắc nghiệp vụ bất biến (Business Rules).

Rút riêng thành module để bảo đảm tính "Single Source of Truth":
cùng một quy tắc được áp dụng cho cả tạo mới lẫn cập nhật, không bị lặp code
ở tầng trên. Tầng trên (Application) chỉ GỌI hàm ở đây, không tự viết lại.
"""

from __future__ import annotations

from .entities import Document

MIN_YEAR = 1990
MAX_YEAR = 2100
MAX_TITLE_LENGTH = 200


def validate_title(title: str) -> str:
    """Tiêu đề: bắt buộc có, đã trim, không vượt quá độ dài cho phép."""
    cleaned = (title or "").strip()
    if not cleaned:
        raise ValueError("Tiêu đề tài liệu không được để trống.")
    if len(cleaned) > MAX_TITLE_LENGTH:
        raise ValueError(f"Tiêu đề tài liệu tối đa {MAX_TITLE_LENGTH} ký tự.")
    return cleaned


def validate_required_text(value: str, field_label: str) -> str:
    """Mọi trường văn bản bắt buộc khác (môn học, tác giả)."""
    cleaned = (value or "").strip()
    if not cleaned:
        raise ValueError(f"{field_label} không được để trống.")
    return cleaned


def validate_year(year: int) -> int:
    """Năm phát hành phải nằm trong khoảng hợp lý."""
    if not isinstance(year, int):
        raise ValueError("Năm phải là số nguyên.")
    if not (MIN_YEAR <= year <= MAX_YEAR):
        raise ValueError(f"Năm phải nằm trong khoảng [{MIN_YEAR}, {MAX_YEAR}].")
    return year


def validate_url(file_url: str | None) -> str | None:
    """Đường dẫn tệp (không bắt buộc): chỉ chấp nhận http/https hoặc đường dẫn nội bộ."""
    if file_url is None:
        return None
    cleaned = file_url.strip()
    if not cleaned:
        return None
    if not (cleaned.startswith("http://") or cleaned.startswith("https://") or cleaned.startswith("/")):
        raise ValueError("Đường dẫn tệp phải bắt đầu bằng http://, https:// hoặc /.")
    return cleaned


def assert_document_is_valid(document: Document) -> None:
    """
    Kiểm tra tính toàn vẹn của cả một tài liệu trước khi lưu.
    Đây là "cổng kiểm soát" (gate) cuối cùng, đảm bảo dữ liệu nào cũng đi qua
    cổng này trước khi tới tầng dữ liệu — kể cả dữ liệu đến từ script, import
    file CSV, hay test.
    """
    validate_title(document.title)
    validate_required_text(document.subject, "Môn học")
    validate_required_text(document.author, "Tác giả")
    validate_year(document.year)
    validate_url(document.file_url)
