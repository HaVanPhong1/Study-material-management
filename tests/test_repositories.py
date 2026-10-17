"""
MỤC 4.4 — KIỂM THỬ TẦNG INFRASTRUCTURE (Repository).

Tách riêng khỏi unit test nghiệp vụ, vì đây là kiểm thử ở MỨC HẠ TẦNG:
  - Nó đòi hỏi repository phải ánh xạ dữ liệu hai chiều đúng.
  - Nó KHÔNG chứa logic nghiệp vụ nào (vì theo kiến trúc, tầng này không được có).
"""

from __future__ import annotations

from uuid import uuid4

import pytest

from app.domain import Document, DocumentFilter, DocumentType
from app.infrastructure import InMemoryDocumentRepository


# ===================================================================== #
# IN-MEMORY REPOSITORY
# ===================================================================== #
@pytest.fixture
def repo() -> InMemoryDocumentRepository:
    return InMemoryDocumentRepository()


def make_doc(title="Tài liệu", subject="Toán", doc_type=DocumentType.BAI_GIANG,
             author="A", year=2024) -> Document:
    return Document(title=title, subject=subject, doc_type=doc_type,
                    author=author, year=year)


def test_in_memory_crud(repo):
    doc = make_doc()
    assert repo.create(doc) is doc
    assert repo.get_by_id(doc.id) is doc
    assert repo.delete(doc.id) is True
    assert repo.get_by_id(doc.id) is None


def test_in_memory_delete_missing_returns_false(repo):
    assert repo.delete(uuid4()) is False


def test_in_memory_search_and_count(repo):
    repo.create(make_doc(title="Đạo hàm", year=2024))
    repo.create(make_doc(title="Tích phân", year=2022, doc_type=DocumentType.BAI_TAP))

    assert len(repo.search(DocumentFilter())) == 2
    assert len(repo.search(DocumentFilter(keyword="đạo"))) == 1
    assert len(repo.search(DocumentFilter(doc_type=DocumentType.BAI_TAP))) == 1
    assert len(repo.search(DocumentFilter(year_from=2023))) == 1
    assert repo.count(DocumentFilter(subject="Toán")) == 2


def test_in_memory_exists_with_exclude_id(repo):
    a = make_doc(title="Trùng")
    repo.create(a)
    assert repo.exists_same_title_and_subject(title="Trùng", subject="Toán") is True
    assert repo.exists_same_title_and_subject(
        title="Trùng", subject="Toán", exclude_id=a.id) is False


# ===================================================================== #
# SQLALCHEMY REPOSITORY (trên SQLite trong RAM)
# ===================================================================== #
@pytest.fixture
def db_repo(sqlite_container):
    with sqlite_container.repository_scope() as repository:
        yield repository


def test_sqlalchemy_crud(db_repo):
    doc = make_doc()
    db_repo.create(doc)

    fetched = db_repo.get_by_id(doc.id)
    assert fetched is not None
    assert fetched.title == "Tài liệu"
    assert fetched.doc_type is DocumentType.BAI_GIANG

    fetched.author = "Nguyễn Văn B"
    db_repo.update(fetched)
    assert db_repo.get_by_id(doc.id).author == "Nguyễn Văn B"

    assert db_repo.delete(doc.id) is True
    assert db_repo.get_by_id(doc.id) is None
    assert db_repo.delete(doc.id) is False


def test_sqlalchemy_persists_across_sessions(sqlite_container):
    """Ghi ở session này, đọc ở session khác -> xác nhận dữ liệu thật sự nằm trên DB."""
    with sqlite_container.repository_scope() as repo1:
        doc = make_doc(title="Bền vững")
        repo1.create(doc)

    with sqlite_container.repository_scope() as repo2:
        fetched = repo2.get_by_id(doc.id)
        assert fetched is not None and fetched.title == "Bền vững"


def test_sqlalchemy_search_with_keyword(db_repo):
    db_repo.create(make_doc(title="Giải tích"))
    db_repo.create(make_doc(title="Lập trình", subject="Tin học"))
    assert len(db_repo.search(DocumentFilter(keyword="giải"))) == 1
    assert len(db_repo.search(DocumentFilter())) == 2


def test_sqlalchemy_keyword_search_is_case_insensitive(db_repo):
    db_repo.create(make_doc(title="GIÁO TRÌNH PYTHON"))
    assert len(db_repo.search(DocumentFilter(keyword="python"))) == 1


def test_sqlalchemy_count_and_exists(db_repo):
    doc = make_doc(title="Trùng")
    db_repo.create(doc)
    assert db_repo.count(DocumentFilter()) == 1
    assert db_repo.exists_same_title_and_subject(title="Trùng", subject="Toán") is True
    assert db_repo.exists_same_title_and_subject(
        title="Trùng", subject="Toán", exclude_id=doc.id) is False


def test_sqlalchemy_datetime_round_trip_keeps_utc(db_repo):
    doc = make_doc()
    db_repo.create(doc)
    fetched = db_repo.get_by_id(doc.id)
    assert fetched.created_at.tzinfo is not None
    assert fetched.updated_at.tzinfo is not None
