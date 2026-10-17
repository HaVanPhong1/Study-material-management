"""
TẦNG INFRASTRUCTURE — Repository hiện thực bằng bộ nhớ (In-Memory).

Vai trò trong bài Cashew:
  1. CHỨNG MINH tính đa triển khai: cùng interface, hai cách lưu trữ khác nhau.
  2. LÀ CÁCH LƯU TRỮ MẶC ĐỊNH CHO UNIT TEST: test nghiệp vụ chạy tức thì,
     không cần cài PostgreSQL, không cần fixture phức tạp, không rò rỉ
     trạng thái giữa các test.
  3. Nếu bài thi yêu cầu "chạy được không cần database", đây chính là lớp đó.

LƯU Ý: Dữ liệu KHÔNG tồn tại sau khi tiến trình kết thúc — đó là điểm yếu
cố ý, và cũng là lý do tầng này chỉ phù hợp cho test/demo, không phải production.
"""

from __future__ import annotations

from datetime import timezone
from typing import Optional
from uuid import UUID

from ..domain import Document, DocumentFilter, DocumentRepository


class InMemoryDocumentRepository(DocumentRepository):
    """Lưu trữ tài liệu bằng dict trong RAM, tuân thủ interface của Domain."""

    def __init__(self) -> None:
        self._storage: dict[str, Document] = {}

    # ------------------------------------------------------------------ #
    # WRITE
    # ------------------------------------------------------------------ #
    def create(self, document: Document) -> Document:
        self._storage[str(document.id)] = document
        return document

    def update(self, document: Document) -> Document:
        self._storage[str(document.id)] = document
        return document

    def delete(self, document_id: UUID) -> bool:
        return self._storage.pop(str(document_id), None) is not None

    # ------------------------------------------------------------------ #
    # READ
    # ------------------------------------------------------------------ #
    def get_by_id(self, document_id: UUID) -> Optional[Document]:
        return self._storage.get(str(document_id))

    def search(
        self, criteria: DocumentFilter, *, limit: int = 20, offset: int = 0
    ) -> list[Document]:
        matched = [doc for doc in self._storage.values() if self._match(doc, criteria)]
        matched.sort(key=lambda d: (-d.year, d.title))
        return matched[offset : offset + limit]

    def count(self, criteria: DocumentFilter) -> int:
        return sum(1 for doc in self._storage.values() if self._match(doc, criteria))

    def exists_same_title_and_subject(
        self, *, title: str, subject: str, exclude_id: Optional[UUID] = None
    ) -> bool:
        exclude = str(exclude_id) if exclude_id else None
        return any(
            doc.title == title
            and doc.subject == subject
            and str(doc.id) != exclude
            for doc in self._storage.values()
        )

    # ---- Tiện ích cho demo/test ----
    def clear(self) -> None:
        self._storage.clear()

    def __len__(self) -> int:
        return len(self._storage)

    # ================================================================== #
    # HÀM NỘI BỘ
    # ================================================================== #
    @staticmethod
    def _match(doc: Document, criteria: DocumentFilter) -> bool:
        """Định nghĩa cách lọc — CỐ TÌNH viết khác hẳn bản SQL.

        Cùng một `DocumentFilter`, hai cách diễn giải hoàn toàn khác nhau
        (so khớp chuỗi trong RAM vs. câu lệnh SQL). Đây chính là bằng chứng rõ
        ràng nhất cho tính trừu tượng: tầng dữ liệu thay đổi, tầng trên
        (Presentation + Application) không một dòng nào phải sửa.
        """
        if criteria.keyword:
            keyword = criteria.keyword.casefold()
            haystack = " ".join((doc.title, doc.subject, doc.author)).casefold()
            if keyword not in haystack:
                return False
        if criteria.subject and doc.subject.casefold() != criteria.subject.casefold():
            return False
        if criteria.doc_type and doc.doc_type is not criteria.doc_type:
            return False
        if criteria.year_from is not None and doc.year < criteria.year_from:
            return False
        if criteria.year_to is not None and doc.year > criteria.year_to:
            return False
        return True
