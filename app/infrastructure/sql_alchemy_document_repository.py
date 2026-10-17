"""
TẦNG INFRASTRUCTURE — Repository hiện thực bằng SQLAlchemy.

Đây là MỘT TRONG HAI hiện thực của interface `domain.repository.DocumentRepository`.
Cùng một interface được hiện thực lần thứ hai bởi
`in_memory_document_repository.InMemoryDocumentRepository` — đó là bằng chứng
cho tính đa triển khai (đúng yêu cầu "loose coupling" của kiến trúc Cashew).

Trách nhiệm DUY NHẤT của file này:
  - Dịch giữa Schema của DB  <->  Entity của Domain.
  - Thực hiện truy vấn. KHÔNG chứa quy tắc nghiệp vụ, KHÔNG quyết định lỗi HTTP.
"""

from __future__ import annotations

from datetime import timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from ..domain import Document, DocumentFilter, DocumentRepository, DocumentType
from .orm_models import DocumentORM


class SqlAlchemyDocumentRepository(DocumentRepository):
    """
    Hiện thực của kho dữ liệu trên SQLAlchemy.

    Mỗi phương thức nhận Session qua constructor. Ở đây ta dùng Session có sẵn
    (mỗi request một Session) thay vì session_scope() tự mở/đóng, để tầng
    Presentation kiểm soát vòng đời giao dịch (Unit of Work).
    """

    def __init__(self, session: Session) -> None:
        self._session = session

    # ------------------------------------------------------------------ #
    # WRITE
    # ------------------------------------------------------------------ #
    def create(self, document: Document) -> Document:
        row = self._to_orm(document)
        self._session.add(row)
        self._session.flush()          # đẩy xuống DB để nhận lỗi ràng buộc sớm
        self._session.refresh(row)     # nạp lại giá trị do DB sinh ra
        return self._to_domain(row)

    def update(self, document: Document) -> Document:
        row = self._session.get(DocumentORM, str(document.id))
        if row is None:
            return self.create(document)   # upsert: coi như chưa tồn tại thì tạo mới

        # Cập nhật TỪNG TRƯỜNG tường minh.
        # (Nếu dùng `row = document` thì sẽ vỡ tính lập trình hướng đối tượng:
        #  thay thế object đã được Session theo dõi là object LẠ.)
        row.title = document.title
        row.subject = document.subject
        row.doc_type = document.doc_type.value
        row.author = document.author
        row.year = document.year
        row.file_url = document.file_url
        row.updated_at = self._to_naive_utc(document.updated_at)
        # Phải cập nhật cả vùng tìm kiếm, nếu không tìm kiếm sẽ trả kết quả cũ.
        row.search_text = self._build_search_text(document)

        self._session.flush()
        self._session.refresh(row)
        return self._to_domain(row)

    def delete(self, document_id: UUID) -> bool:
        row = self._session.get(DocumentORM, str(document_id))
        if row is None:
            return False
        self._session.delete(row)
        self._session.flush()
        return True

    # ------------------------------------------------------------------ #
    # READ
    # ------------------------------------------------------------------ #
    def get_by_id(self, document_id: UUID) -> Optional[Document]:
        row = self._session.get(DocumentORM, str(document_id))
        return self._to_domain(row) if row else None

    def search(
        self, criteria: DocumentFilter, *, limit: int = 20, offset: int = 0
    ) -> list[Document]:
        stmt = self._build_select(criteria).order_by(DocumentORM.year.desc(), DocumentORM.title.asc())
        stmt = stmt.limit(limit).offset(offset)
        rows = self._session.scalars(stmt).all()
        return [self._to_domain(row) for row in rows]

    def count(self, criteria: DocumentFilter) -> int:
        # `maintain_column_froms=True` là BẮT BUỘC: mặc định SQLAlchemy 2.0 sẽ bỏ
        # mệnh đề FROM khi thay toàn bộ danh sách cột, khiến truy vấn thành
        # "SELECT count(*)" không có bảng và luôn trả về 1.
        stmt = self._build_select(criteria).with_only_columns(
            func.count(DocumentORM.id), maintain_column_froms=True
        )
        return int(self._session.scalar(stmt) or 0)

    def exists_same_title_and_subject(
        self, *, title: str, subject: str, exclude_id: Optional[UUID] = None
    ) -> bool:
        stmt = select(func.count()).where(
            DocumentORM.title == title, DocumentORM.subject == subject
        )
        if exclude_id is not None:
            stmt = stmt.where(DocumentORM.id != str(exclude_id))
        return int(self._session.scalar(stmt) or 0) > 0

    # ================================================================== #
    # HÀM NỘI BỘ
    # ================================================================== #
    def _build_select(self, criteria: DocumentFilter) -> Select:
        """
        Dựng câu truy vấn động từ điều kiện lọc của Domain.
        Đây là nơi duy nhất trong hệ thống "dịch" yêu cầu nghiệp vụ thành SQL.
        """
        stmt = select(DocumentORM)
        if criteria.keyword:
            # So khớp trên cột đã casefold sẵn -> đúng với cả chữ có dấu tiếng Việt.
            stmt = stmt.where(DocumentORM.search_text.contains(criteria.keyword.casefold()))
        if criteria.subject:
            stmt = stmt.where(DocumentORM.subject.ilike(criteria.subject))
        if criteria.doc_type:
            stmt = stmt.where(DocumentORM.doc_type == criteria.doc_type.value)
        if criteria.year_from is not None:
            stmt = stmt.where(DocumentORM.year >= criteria.year_from)
        if criteria.year_to is not None:
            stmt = stmt.where(DocumentORM.year <= criteria.year_to)
        return stmt

    # ---- Ánh xạ dữ liệu (Mapping) ----
    @staticmethod
    def _to_orm(entity: Document) -> DocumentORM:
        return DocumentORM(
            id=str(entity.id),
            title=entity.title,
            subject=entity.subject,
            doc_type=entity.doc_type.value,
            author=entity.author,
            year=entity.year,
            file_url=entity.file_url,
            created_at=SqlAlchemyDocumentRepository._to_naive_utc(entity.created_at),
            updated_at=SqlAlchemyDocumentRepository._to_naive_utc(entity.updated_at),
            search_text=SqlAlchemyDocumentRepository._build_search_text(entity),
        )

    @staticmethod
    def _build_search_text(entity: Document) -> str:
        """
        Chuẩn hoá vùng tìm kiếm về chữ thường (casefold) để hỗ trợ tiếng Việt
        không phân biệt hoa/thường. Xem giải thích ở cột `search_text` của ORM.
        """
        return " ".join((entity.title, entity.subject, entity.author)).casefold()

    @staticmethod
    def _to_domain(row: DocumentORM) -> Document:
        return Document(
            id=UUID(row.id),
            title=row.title,
            subject=row.subject,
            doc_type=DocumentType(row.doc_type),
            author=row.author,
            year=row.year,
            file_url=row.file_url,
            created_at=SqlAlchemyDocumentRepository._to_aware_utc(row.created_at),
            updated_at=SqlAlchemyDocumentRepository._to_aware_utc(row.updated_at),
        )

    @staticmethod
    def _to_naive_utc(value):
        """
        Domain dùng datetime CÓ múi giờ (timezone-aware, chuẩn khuyến nghị).
        SQLite không hỗ trợ kiểu datetime có timezone, nên ta bỏ múi giờ khi ghi
        (nhưng luôn quy ước là UTC) và gắn lại khi đọc.
        => Việc "lệch múi giờ" chỉ xảy ra ở đúng tầng hạ tầng, không lan sang Domain.
        """
        return value.astimezone(timezone.utc).replace(tzinfo=None) if value.tzinfo else value

    @staticmethod
    def _to_aware_utc(value):
        return value.replace(tzinfo=timezone.utc) if value and not value.tzinfo else value
