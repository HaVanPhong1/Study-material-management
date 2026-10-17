"""
TẦNG APPLICATION — Data Transfer Object (DTO).

Vì sao cần DTO nếu đã có Entity?
  - Entity là đồ vật "sống" của Domain, có id/timestamps/quy tắc.
  - DTO là đồ vật "chết", chỉ mang dữ liệu, dùng để truyền vào/ra ranh giới ứng dụng.
  - Nhờ đó, thêm/bớt trường trong Entity KHÔNG làm vỡ hợp đồng với tầng Presentation,
    và ngược lại tầng Presentation không thể tuỳ ý sửa dữ liệu lõi vì nó chỉ nhận DTO.
Đây là cơ chế "encapsulation boundary" đặc trưng của Cashew.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from uuid import UUID

from ..domain.entities import Document, DocumentType


@dataclass
class DocumentCreateData:
    """Dữ liệu đầu vào cho use-case 'Tạo tài liệu'."""

    title: str
    subject: str
    doc_type: DocumentType
    author: str
    year: int
    file_url: Optional[str] = None

    def to_entity(self) -> Document:
        """Chuyển DTO -> Domain entity (kèm chuẩn hoá dữ liệu)."""
        return Document(
            title=self.title,
            subject=self.subject,
            doc_type=self.doc_type,
            author=self.author,
            year=self.year,
            file_url=self.file_url,
        )


@dataclass
class DocumentUpdateData:
    """
    Dữ liệu đầu vào cho use-case 'Cập nhật tài liệu'.
    Mọi trường đều Optional = chỉ cập nhật trường được cung cấp
    (tuân theo nguyên tắc PATCH: thay đổi một phần).
    """

    title: Optional[str] = None
    subject: Optional[str] = None
    doc_type: Optional[DocumentType] = None
    author: Optional[str] = None
    year: Optional[int] = None
    file_url: Optional[str] = None

    def is_empty(self) -> bool:
        return all(getattr(self, f.name) is None for f in self.__dataclass_fields__.values())


@dataclass
class DocumentSearchData:
    """Dữ liệu đầu vào cho use-case 'Tìm kiếm tài liệu'."""

    keyword: Optional[str] = None
    subject: Optional[str] = None
    doc_type: Optional[DocumentType] = None
    year_from: Optional[int] = None
    year_to: Optional[int] = None
    limit: int = 20
    offset: int = 0


@dataclass
class DocumentView:
    """
    Dữ liệu ĐẦU RA mà tầng Application trả về cho tầng Presentation.
    Tầng Presentation chỉ được phép nhìn thấy type này, không chạm vào Entity.
    """

    id: UUID
    title: str
    subject: str
    doc_type: DocumentType
    doc_type_label: str
    author: str
    year: int
    file_url: Optional[str]
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_entity(cls, entity: Document) -> "DocumentView":
        """Ánh xạ Domain entity -> DTO đầu ra."""
        return cls(
            id=entity.id,
            title=entity.title,
            subject=entity.subject,
            doc_type=entity.doc_type,
            doc_type_label=entity.doc_type.display_name,
            author=entity.author,
            year=entity.year,
            file_url=entity.file_url,
            created_at=entity.created_at,
            updated_at=entity.updated_at,
        )
