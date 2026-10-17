"""
Bộ GIẢ LẬP KHO DỮ LIỆU cho unit test (Test Double).

Vì sao cần file này?
  - `DocumentService` chỉ phụ thuộc vào INTERFACE `DocumentRepository`.
  - Ta viết một lớp giả (Fake) độc lập hoàn toàn với SQLAlchemy/SQLite,
    thậm chí còn ghi lại các lời gọi để kiểm chứng service gọi đúng phương thức.
  - Nhờ đó, unit test tầng nghiệp vụ chạy trong mili giây, không cần database.

Lưu ý về mức độ "giả":
  - `Fake`  : có logic tối thiểu, dùng trong unit test (có thể dùng chung cho nhiều test).
  - `Mock`  : chỉ ghi nhận lời gọi, không có hành vi (dùng để verify).
  - `Stub`  : trả về giá trị cố định.
Ta dùng Fake vì cho phép kiểm thử luồng nghiệp vụ đầy đủ (CRUD + lọc).
"""

from __future__ import annotations

from typing import Optional
from uuid import UUID

from app.domain import Document, DocumentFilter, DocumentRepository


class FakeDocumentRepository(DocumentRepository):
    """
    Kho dữ liệu giả lập, cài đặt đầy đủ interface của Domain.
    Ở đây KHÔNG có bất kỳ dòng nào import SQLAlchemy hay mở file SQLite.
    """

    def __init__(self, documents: list[Document] | None = None) -> None:
        self._storage: dict[str, Document] = {}
        #: Lịch sử các lời gọi — dùng để chứng minh Service đi đúng quy trình.
        self.calls: list[tuple[str, tuple, dict]] = []
        for doc in documents or []:
            self._storage[str(doc.id)] = doc

    # ---------------- WRITE ---------------- #
    def create(self, document: Document) -> Document:
        self.calls.append(("create", (document,), {}))
        self._storage[str(document.id)] = document
        return document

    def update(self, document: Document) -> Document:
        self.calls.append(("update", (document,), {}))
        self._storage[str(document.id)] = document
        return document

    def delete(self, document_id: UUID) -> bool:
        self.calls.append(("delete", (document_id,), {}))
        return self._storage.pop(str(document_id), None) is not None

    # ---------------- READ ---------------- #
    def get_by_id(self, document_id: UUID) -> Optional[Document]:
        self.calls.append(("get_by_id", (document_id,), {}))
        return self._storage.get(str(document_id))

    def search(
        self, criteria: DocumentFilter, *, limit: int = 20, offset: int = 0
    ) -> list[Document]:
        self.calls.append(("search", (criteria,), {"limit": limit, "offset": offset}))
        matched = [d for d in self._storage.values() if self._match(d, criteria)]
        matched.sort(key=lambda d: (-d.year, d.title))
        return matched[offset : offset + limit]

    def count(self, criteria: DocumentFilter) -> int:
        self.calls.append(("count", (criteria,), {}))
        return sum(1 for d in self._storage.values() if self._match(d, criteria))

    def exists_same_title_and_subject(
        self, *, title: str, subject: str, exclude_id: Optional[UUID] = None
    ) -> bool:
        self.calls.append(
            ("exists_same_title_and_subject", (), {"title": title, "subject": subject,
                                                   "exclude_id": exclude_id})
        )
        exclude = str(exclude_id) if exclude_id else None
        return any(
            d.title == title and d.subject == subject and str(d.id) != exclude
            for d in self._storage.values()
        )

    # ---------------- Tiện ích cho test ---------------- #
    @property
    def call_names(self) -> list[str]:
        return [name for name, _, _ in self.calls]

    @property
    def documents(self) -> list[Document]:
        return list(self._storage.values())

    def __len__(self) -> int:
        return len(self._storage)

    @staticmethod
    def _match(doc: Document, criteria: DocumentFilter) -> bool:
        if criteria.keyword:
            kw = criteria.keyword.casefold()
            if kw not in f"{doc.title} {doc.subject} {doc.author}".casefold():
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


class ExplodingRepository(DocumentRepository):
    """
    Kho dữ liệu "nổ" khi bị gọi bất kỳ phương thức nào.

    Mục đích: dùng trong test `test_application_layer_does_not_touch_storage` để
    chứng minh tầng Application, khi CHỈ chạy phần kiểm tra hợp lệ (validation),
    thì không hề chạm tới tầng lưu trữ.
    """

    def _boom(self, *_: object, **__: object):
        raise AssertionError("Tầng Application đã gọi tới tầng lưu trữ!")

    create = update = delete = get_by_id = search = count = _boom  # type: ignore[assignment]
    exists_same_title_and_subject = _boom  # type: ignore[assignment]
