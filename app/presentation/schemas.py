"""
TẦNG PRESENTATION — HỢP ĐỒNG HTTP (Pydantic Schema).

Nguyên tắc: tầng Presentation KHÔNG được nhận/ trả Domain Entity.
- Đầu vào  : Schema Request  -> chuyển thành DTO của tầng Application.
- Đầu ra   : DTO của Application -> chuyển thành Schema Response.
Nhờ đó, kể cả khi ai đó vô tình đổi cấu trúc Entity trong tương lai,
API vẫn giữ nguyên hợp đồng với client.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from ..application import DocumentCreateData, DocumentUpdateData, DocumentView
from ..domain import DocumentType


# --------------------------------------------------------------------- #
# SCHEMA ĐẦU VÀO
# --------------------------------------------------------------------- #
class DocumentCreateRequest(BaseModel):
    """
    Ràng buộc ở biên HTTP (fail fast): FastAPI trả 422 ngay khi dữ liệu sai,
    thay vì đẩy xuống tầng dưỡng dữ liệu rồi mới phát hiện.
    Lưu ý: đây là kiểm tra HÌNH THỨC. Kiểm tra NGHIỆP VỆ (vd: tài liệu trùng)
    vẫn thuộc về tầng Application/Domain.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "title": "Giải tích 1 - Chương 3: Đạo hàm",
                "subject": "Toán học",
                "doc_type": "bai_giang",
                "author": "Nguyễn Văn A",
                "year": 2024,
                "file_url": "https://example.com/dao-ham.pdf",
            }
        }
    )

    title: str = Field(min_length=1, max_length=200, description="Tiêu đề tài liệu")
    subject: str = Field(min_length=1, max_length=120, description="Môn học")
    doc_type: DocumentType = Field(description="Loại tài liệu")
    author: str = Field(min_length=1, max_length=120, description="Tác giả")
    year: int = Field(ge=1900, le=2100, description="Năm phát hành")
    file_url: Optional[str] = Field(default=None, description="Đường dẫn tệp (tuỳ chọn)")

    def to_command(self) -> DocumentCreateData:
        """Chuyển schema HTTP -> DTO của tầng Application."""
        return DocumentCreateData(
            title=self.title,
            subject=self.subject,
            doc_type=self.doc_type,
            author=self.author,
            year=self.year,
            file_url=self.file_url,
        )


class DocumentUpdateRequest(BaseModel):
    """Cập nhật một phần: chỉ gửi trường muốn sửa, trường khác giữ nguyên."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {"title": "Giải tích 1 (2025 - bản sửa đổi)", "year": 2025}
        }
    )

    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    subject: Optional[str] = Field(default=None, min_length=1, max_length=120)
    doc_type: Optional[DocumentType] = None
    author: Optional[str] = Field(default=None, min_length=1, max_length=120)
    year: Optional[int] = Field(default=None, ge=1900, le=2100)
    file_url: Optional[str] = Field(default=None)

    def to_command(self) -> DocumentUpdateData:
        return DocumentUpdateData(
            title=self.title,
            subject=self.subject,
            doc_type=self.doc_type,
            author=self.author,
            year=self.year,
            file_url=self.file_url,
        )


# --------------------------------------------------------------------- #
# SCHEMA ĐẦU RA
# --------------------------------------------------------------------- #
class DocumentResponse(BaseModel):
    """Cấu trúc tài liệu trả về cho client."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    subject: str
    doc_type: DocumentType
    doc_type_label: str = Field(description="Nhãn tiếng Việt của loại tài liệu")
    author: str
    year: int
    file_url: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_view(cls, view: DocumentView) -> "DocumentResponse":
        return cls.model_validate(view, from_attributes=True)


class DocumentListResponse(BaseModel):
    """Kết quả tìm kiếm kèm thông tin phân trang."""

    total: int = Field(description="Tổng số bản ghi thỏa điều kiện lọc")
    limit: int
    offset: int
    items: list[DocumentResponse]


class ErrorResponse(BaseModel):
    """Định dạng lỗi thống nhất của toàn hệ thống (chuyển DomainError -> HTTP)."""

    code: str = Field(description="Mã lỗi nghiệp vụ, vd: DOCUMENT_NOT_FOUND")
    message: str = Field(description="Thông điệp thân thiện cho người dùng")
