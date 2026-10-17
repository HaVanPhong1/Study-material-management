"""
TẦNG DOMAIN — Định nghĩa GIAO DIỆN kho dữ liệu (Repository Interface).

ĐÂY LÀ TRÁI TIM CỦA KIẾN TRÚC CASHEW.

Nguyên tắc "Đảo ngược phụ thuộc" (Dependency Inversion):
  - Tầng Application cần một kho chứa dữ liệu.
  - Thay vì phụ thuộc vào SQLAlchemy (hạ tầng), nó phụ thuộc vào ABSTRACT CLASS này.
  - Mũi tên phụ thuộc được đảo chiều: Infrastructure -> Domain.

  Trước Cashew : Application ---> SQLAlchemy        (phụ thuộc xuống, khó test)
  Sau Cashew   : Application ---> <<interface>> <--- SQLAlchemy   (phụ thuộc vào trong)

Hệ quả thực tế: muốn đổi SQLite -> PostgreSQL, hay thay bằng HTTP gọi
API bên ngoài, ta chỉ viết thêm một class mới trong `infrastructure/`.
Không một dòng code nào của `application/` hay `domain/` phải sửa.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from .entities import Document, DocumentFilter


class DocumentRepository(ABC):
    """
    Hợp đồng (contract) của kho lưu trữ tài liệu.

    Lưu ý: interface này được viết bằng NGÔN NGỮ NGHIỆP VỤ, không phải ngôn ngữ SQL.
    - `search` trả về list domain entity, không phải Row/ORM object.
    - Việc phân trang được tham số hoá (limit/offset) để tầng trên không cần
      biết chi tiết "phân trang" được thực hiện bằng SQL LIMIT hay trong RAM.
    """

    # ---- Ghi (Write) ----
    @abstractmethod
    def create(self, document: Document) -> Document:
        """Lưu mới một tài liệu và trả về bản đã lưu (có id/timestamps)."""

    @abstractmethod
    def update(self, document: Document) -> Document:
        """Ghi đè bản cập nhật của một tài liệu đã tồn tại."""

    @abstractmethod
    def delete(self, document_id: UUID) -> bool:
        """Xóa theo mã. Trả True nếu thực sự xóa, False nếu không tồn tại."""

    # ---- Đọc (Read) ----
    @abstractmethod
    def get_by_id(self, document_id: UUID) -> Optional[Document]:
        """Lấy một tài liệu theo mã, hoặc None nếu không có."""

    @abstractmethod
    def search(
        self,
        criteria: DocumentFilter,
        *,
        limit: int = 20,
        offset: int = 0,
    ) -> list[Document]:
        """Tìm kiếm/lọc tài liệu theo tiêu chí nghiệp vụ, có phân trang."""

    @abstractmethod
    def count(self, criteria: DocumentFilter) -> int:
        """Đếm tổng số bản ghi thỏa tiêu chí (dùng cho phân trang)."""

    @abstractmethod
    def exists_same_title_and_subject(
        self,
        *,
        title: str,
        subject: str,
        exclude_id: Optional[UUID] = None,
    ) -> bool:
        """
        Kiểm tra trùng lặp theo (tiêu đề, môn học).
        `exclude_id` cho phép dùng chung hàm này cho cả thêm mới và cập nhật
        (khi sửa thì bỏ qua chính bản thân nó).
        """
