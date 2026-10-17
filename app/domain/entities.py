"""
TẦNG DOMAIN (Lõi nghiệp vụ) — Tài liệu học tập.

Đây là tầng trong cùng của Kiến trúc Cashew. Nó chứa:
  1. Dữ liệu nghiệp vụ thuần (Entity + Enum).
  2. Các quy tắc nghiệp vụ bất biến (không phụ thuộc công nghệ).

QUY TẮC VÀNG của tầng này (bộ phận kiểm tra sẽ tự động kiểm tra ở Mục 4):
  - KHÔNG được import fastapi, pydantic, sqlalchemy, sqlite3...
  - KHÔNG biết HTTP, database, framework nào tồn tại.
  - Nó là nơi duy nhất được phép được phụ thuộc vào bởi mọi tầng khác.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from uuid import UUID, uuid4


def _utc_now() -> datetime:
    """Hàm phụ trợ: lấy thời điểm hiện tại theo chuẩn UTC có múi giờ."""
    return datetime.now(timezone.utc)


class DocumentType(str, Enum):
    """Loại tài liệu học tập — là một khái niệm nghiệp vụ, không phải mã số trong DB."""

    BAI_GIANG = "bai_giang"                  # Bài giảng
    BAI_TAP = "bai_tap"                      # Bài tập
    TAI_LIEU_THAM_KHAO = "tai_lieu_tham_khao"  # Tài liệu tham khảo
    DE_THI = "de_thi"                        # Đề thi

    @property
    def display_name(self) -> str:
        """Nhãn tiếng Việt dùng cho thông báo lỗi/giao diện."""
        return {
            DocumentType.BAI_GIANG: "Bài giảng",
            DocumentType.BAI_TAP: "Bài tập",
            DocumentType.TAI_LIEU_THAM_KHAO: "Tài liệu tham khảo",
            DocumentType.DE_THI: "Đề thi",
        }[self]


@dataclass
class Document:
    """
    Entity gốc của hệ thống: một tài liệu học tập.

    Dùng dataclass thuần (không kế thừa ORM, không kế thừa Pydantic) để bảo đảm
    tầng Domain hoàn toàn độc lập với hạ tầng lưu trữ và framework web.
    Việc ánh xạ sang SQLAlchemy / Pydantic do tầng khác chịu trách nhiệm.
    """

    title: str
    subject: str
    doc_type: DocumentType
    author: str
    year: int
    file_url: str | None = None
    id: UUID = field(default_factory=uuid4)
    created_at: datetime = field(default_factory=_utc_now)
    updated_at: datetime = field(default_factory=_utc_now)

    def apply_change(
        self,
        *,
        title: str | None = None,
        subject: str | None = None,
        doc_type: DocumentType | None = None,
        author: str | None = None,
        year: int | None = None,
        file_url: str | None = None,
    ) -> "Document":
        """
        Hành vi của Entity: áp dụng một thay đổi lên chính nó và cập nhật
        mốc thời gian sửa đổi. Việc kiểm tra hợp lệ (validity) do
        tầng Domain bảo đảm, xem `domain.rules`.
        """
        if title is not None:
            self.title = title
        if subject is not None:
            self.subject = subject
        if doc_type is not None:
            self.doc_type = doc_type
        if author is not None:
            self.author = author
        if year is not None:
            self.year = year
        if file_url is not None:
            self.file_url = file_url
        self.updated_at = _utc_now()
        return self


@dataclass(frozen=True)
class DocumentFilter:
    """
    Đối tượng truy vấn (Query Object) của Domain — mô tả điều kiện TÌM KIẾM.

    Nhờ đặc tượng hóa điều kiện lọc thành một value object thay vì truyền
    tham số rời rạc, interface Repository chỉ cần đúng MỘT phương thức `search`,
    và việc thêm tiêu chí lọc mới không phải sửa interface (đúng tinh thần
    Open/Closed của Cashew).
    """

    keyword: str | None = None        # Từ khóa tìm trong tên/môn/tác giả
    subject: str | None = None        # Lọc chính xác theo môn học
    doc_type: DocumentType | None = None  # Lọc theo loại tài liệu
    year_from: int | None = None      # Năm tối thiểu
    year_to: int | None = None        # Năm tối đa

    def is_empty(self) -> bool:
        """True nếu không có tiêu chí lọc nào -> coi như xem toàn bộ danh mục."""
        return all(
            v is None
            for v in (self.keyword, self.subject, self.doc_type, self.year_from, self.year_to)
        )
