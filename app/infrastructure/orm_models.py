"""
TẦNG INFRASTRUCTURE — Model ORM (SQLAlchemy).

PHÂN BIỆT QUAN TRỌNG (thường bị hỏi trong vấn đề thi):
    `DocumentORM` (file này)      ≠   `Document` (app/domain/entities.py)
    - Là BẢNG trong database.     - Là KHÁI NIỆM NGHIỆP VỤ.
    - Có thể đổi hình dạng tuỳ DB. - Phải giữ ổn định vì nghiệp vụ dựa vào nó.
    - Chỉ tầng Infrastructure biết.

Tách hai thứ này là điểm mấu chốt giúp hệ thống không bị "coupling vào database":
ta có thể đổi cột, đổi kiểu dữ liệu, thậm chí đổi hệ quản trị mà không ảnh hưởng
tới bất kỳ logic nghiệp vụ nào.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Index, Integer, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Lớp cơ sở cho toàn bộ model ORM."""


class DocumentORM(Base):
    """
    Bảng `documents`.
    Dùng `Mapped[...]` + `mapped_column(...)` (SQLAlchemy 2.0 style) thay cho
    `Column(...)` (SQLAlchemy 1.x style) để có type-hint đầy đủ.
    """

    __tablename__ = "documents"

    # Khóa chính dạng chuỗi UUID: dễ sinh ở tầng nghiệp vụ trước khi insert,
    # nên khi tạo mới ta biết trước id mà không cần query thêm một lần nữa.
    id: Mapped[str] = mapped_column(String(36), primary_key=True)

    title: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    subject: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    doc_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    author: Mapped[str] = mapped_column(String(120), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    file_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    # Cột phái sinh chỉ phục vụ tìm kiếm: chứa "tên + môn + tác giả" đã chuyển
    # về chữ thường. Lý do tồn tại cột này:
    #   Hàm LIKE/lower() của SQLite chỉ phân biệt hoa thường với ký tự ASCII,
    #   nên tìm "đạo hàm" sẽ KHÔNG khớp với "Đạo hàm".
    #   Chuẩn hoá trước ở tầng hạ tầng giúp tìm kiếm tiếng Việt đúng như mong đợi
    #   mà không để tầng nghiệp vụ phải biết chi tiết này.
    search_text: Mapped[str] = mapped_column(String(600), nullable=False, index=True)

    # Index phục vụ truy vấn lọc theo khoảng năm (năm tăng dần).
    __table_args__ = (
        Index("ix_documents_year_range", "year"),
        # Ràng buộc nghiệp vụ được đẩy xuống DB để bảo vệ dữ liệu ở mức sâu nhất.
        # (Lưu ý: tầng Domain vẫn phải kiểm tra — DB không thay thế được Domain.)
    )

    def __repr__(self) -> str:
        return f"<DocumentORM id={self.id!r} title={self.title!r}>"
