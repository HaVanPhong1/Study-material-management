"""
TẦNG APPLICATION — Lớp Dịch vụ Nghiệp vụ (DocumentService).

Đây là nơi chứa TOÀN BỘ quy trình nghiệp vụ của ứng dụng:
  - Tạo / Đọc / Sửa / Xóa / Tìm kiếm tài liệu.

ĐẶC ĐIỂM CỦA TẦNG NÀY (điểm chấm điểm của bài Cashew):
  1. Chỉ nhận đầu vào/đầu ra là DTO, không lộ Entity ra ngoài.
  2. CHỈ phụ thuộc vào `domain.repository.DocumentRepository` (một interface).
  3. Không import fastapi, sqlalchemy, sqlite, os, open() ...
     => Không thể viết test cho tầng này mà không động tới database. Đó là chứng cứ.
"""

from __future__ import annotations

from typing import Optional
from uuid import UUID

from ..domain import (
    DocumentFilter,
    DocumentNotFoundError,
    DocumentRepository,
    DuplicateDocumentError,
    InvalidDocumentError,
    rules,
)
from .dto import (
    DocumentCreateData,
    DocumentSearchData,
    DocumentUpdateData,
    DocumentView,
)


class DocumentService:
    """
    Use-case service. Được cấu tình qua CONSTRUCTOR INJECTION: kho dữ liệu được
    "tiêm vào" từ bên ngoài (Composition Root), chứ không tự khởi tạo.
    Đây là điểm khác biệt giữa "code chạy được" và "code kiểm thử được".
    """

    def __init__(self, repository: DocumentRepository) -> None:
        self._repository = repository

    # ------------------------------------------------------------------ #
    # Use-case 1: TẠO TÀI LIỆU
    # ------------------------------------------------------------------ #
    def create_document(self, data: DocumentCreateData) -> DocumentView:
        """
        Quy trình nghiệp vụ thêm tài liệu:
            1. Chuẩn hoá + kiểm tra hợp lệ dữ liệu đầu vào.
            2. Kiểm tra trùng lặp (cùng tiêu đề + cùng môn học).
            3. Chuyển DTO thành Entity và giao cho tầng dữ liệu lưu.
            4. Trả về DTO đầu ra.
        """
        entity = self._build_validated_entity(data)
        self._ensure_not_duplicate(entity.title, entity.subject)
        saved = self._repository.create(entity)
        return DocumentView.from_entity(saved)

    # ------------------------------------------------------------------ #
    # Use-case 2: XEM CHI TIẾT
    # ------------------------------------------------------------------ #
    def get_document(self, document_id: UUID) -> DocumentView:
        """Lấy chi tiết một tài liệu; nếu không có thì ném lỗi nghiệp vụ chuẩn hoá."""
        document = self._repository.get_by_id(document_id)
        if document is None:
            # Tầng Domain KHÔNG biết 404 là gì; nó chỉ biết "không tìm thấy".
            # Việc ánh xạ sang HTTP 404 là trách nhiệm của tầng Presentation.
            raise DocumentNotFoundError(str(document_id))
        return DocumentView.from_entity(document)

    # ------------------------------------------------------------------ #
    # Use-case 3: TÌM KIẾM & LỌC
    # ------------------------------------------------------------------ #
    def search_documents(self, data: DocumentSearchData) -> list[DocumentView]:
        """
        Tìm kiếm tài liệu theo: từ khoá, môn học, loại tài liệu, khoảng năm.
        Service chỉ chịu trách nhiệm chuẩn hoá điều kiện lọc; CÁCH lọc
        (SQL LIKE, quét RAM...) do Repository quyết định.
        """
        criteria, limit, offset = self._build_filter(data)
        documents = self._repository.search(criteria, limit=limit, offset=offset)
        return [DocumentView.from_entity(doc) for doc in documents]

    def count_documents(self, data: DocumentSearchData) -> int:
        """Đếm tổng số kết quả (dùng cho thông báo phân trang)."""
        criteria, _, _ = self._build_filter(data)
        return self._repository.count(criteria)

    # ------------------------------------------------------------------ #
    # Use-case 4: CẬP NHẬT
    # ------------------------------------------------------------------ #
    def update_document(self, document_id: UUID, data: DocumentUpdateData) -> DocumentView:
        """
        Quy trình cập nhật:
            1. Lấy tài liệu hiện tại (không có -> lỗi).
            2. Áp dụng thay đổi vào entity.
            3. Kiểm tra lại tính hợp lệ + trùng lặp (loại trừ chính nó).
            4. Lưu lại.
        """
        if data.is_empty():
            raise InvalidDocumentError("Không có trường nào để cập nhật.")

        current = self._repository.get_by_id(document_id)
        if current is None:
            raise DocumentNotFoundError(str(document_id))

        current.apply_change(
            title=data.title,
            subject=data.subject,
            doc_type=data.doc_type,
            author=data.author,
            year=data.year,
            file_url=data.file_url,
        )

        # Tái sử dụng ĐÚNG bộ quy tắc của lúc tạo mới -> không lệch logic.
        self._build_validated_entity_from_entity(current)
        self._ensure_not_duplicate(
            current.title, current.subject, exclude_id=current.id
        )

        updated = self._repository.update(current)
        return DocumentView.from_entity(updated)

    # ------------------------------------------------------------------ #
    # Use-case 5: XÓA
    # ------------------------------------------------------------------ #
    def delete_document(self, document_id: UUID) -> None:
        """Xóa tài liệu; nếu không tồn tại thì ném lỗi chuẩn hoá."""
        deleted = self._repository.delete(document_id)
        if not deleted:
            raise DocumentNotFoundError(str(document_id))

    # ================================================================== #
    # HÀM NỘI BỘ (private) — tách riêng để mỗi hàm chỉ làm một việc
    # ================================================================== #
    @staticmethod
    def _build_validated_entity(data: DocumentCreateData) -> Document:
        """Chuẩn hoá + kiểm tra hợp lệ, trả về entity sẵn sàng lưu."""
        entity = data.to_entity()
        DocumentService._build_validated_entity_from_entity(entity)
        return entity

    @staticmethod
    def _build_validated_entity_from_entity(entity: Document) -> None:
        """
        Áp dụng bộ quy tắc của Domain rồi GHI KẾT QUẢ chuẩn hoá trở lại entity
        (vd: "  Toán  " -> "Toán"). Việc ghi lại giúp dữ liệu lưu xuống DB
        luôn sạch, không phụ thuộc tầng dưới có làm sạch hay không.
        """
        try:
            entity.title = rules.validate_title(entity.title)
            entity.subject = rules.validate_required_text(entity.subject, "Môn học")
            entity.author = rules.validate_required_text(entity.author, "Tác giả")
            entity.year = rules.validate_year(entity.year)
            entity.file_url = rules.validate_url(entity.file_url)
        except ValueError as exc:
            # Đổi lỗi kỹ thuật (ValueError) thành lỗi NGHIỆP VỤ chuẩn hoá,
            # để tầng trên chỉ cần bắt một loại ngoại lệ duy nhất.
            raise InvalidDocumentError(str(exc)) from exc

    def _ensure_not_duplicate(
        self, title: str, subject: str, exclude_id: Optional[UUID] = None
    ) -> None:
        if self._repository.exists_same_title_and_subject(
            title=title, subject=subject, exclude_id=exclude_id
        ):
            raise DuplicateDocumentError(title, subject)

    @staticmethod
    def _build_filter(data: DocumentSearchData) -> tuple[DocumentFilter, int, int]:
        """
        Chuẩn hoá điều kiện lọc trước khi đưa xuống tầng dữ liệu.
        Trả về 3 giá trị: (điều kiện lọc, limit đã chuẩn hoá, offset đã chuẩn hoá).
        """
        keyword = (data.keyword or "").strip() or None
        subject = (data.subject or "").strip() or None
        limit = min(max(data.limit, 1), 100)     # chặn limit khổng lồ (bảo vệ tài nguyên)
        offset = max(data.offset, 0)
        criteria = DocumentFilter(
            keyword=keyword,
            subject=subject,
            doc_type=data.doc_type,
            year_from=data.year_from,
            year_to=data.year_to,
        )
        return criteria, limit, offset
