"""
MỤC 4.2 — UNIT TEST TẦNG APPLICATION (DocumentService).

Đối tượng kiểm thử: app/application/document_service.py
Cách chạy: pytest tests/test_document_service.py

CHỨNG CỨ CỦA KIẾN TRÚC CASHEW:
    Toàn bộ file test này chạy với `FakeDocumentRepository` (tests/fakes.py).
    KHÔNG có import sqlite3, sqlalchemy, fastapi, TestClient hay file .db.
    => Tầng nghiệp vụ kiểm thử được trong mili giây, hoàn toàn độc lập hạ tầng.
"""

from __future__ import annotations

from uuid import uuid4

import pytest

from app.application import (
    DocumentCreateData,
    DocumentSearchData,
    DocumentService,
    DocumentUpdateData,
)
from app.domain import (
    Document,
    DocumentNotFoundError,
    DocumentType,
    DuplicateDocumentError,
    InvalidDocumentError,
)

from .fakes import FakeDocumentRepository


# ===================================================================== #
# THIẾT LẬP DỮ LIỆU
# ===================================================================== #
def make_create_data(**overrides) -> DocumentCreateData:
    data = dict(
        title="Giải tích 1 - Đạo hàm",
        subject="Toán học",
        doc_type=DocumentType.BAI_GIANG,
        author="Nguyễn Văn A",
        year=2024,
    )
    data.update(overrides)
    return DocumentCreateData(**data)  # type: ignore[arg-type]


@pytest.fixture
def service(fake_repository: FakeDocumentRepository) -> DocumentService:
    return DocumentService(fake_repository)


# ===================================================================== #
# USE-CASE: TẠO TÀI LIỆU
# ===================================================================== #
def test_create_document_success(service, fake_repository):
    view = service.create_document(make_create_data())

    assert view.title == "Giải tích 1 - Đạo hàm"
    assert view.doc_type_label == "Bài giảng"
    assert len(fake_repository) == 1
    assert "create" in fake_repository.call_names


def test_create_document_normalizes_whitespace(service, fake_repository):
    view = service.create_document(make_create_data(title="  Toán  ", subject=" Lý "))

    # Dữ liệu được chuẩn hoá TRƯỚC khi lưu -> DB luôn sạch
    assert view.title == "Toán"
    assert view.subject == "Lý"
    assert fake_repository.documents[0].title == "Toán"


@pytest.mark.parametrize(
    "overrides",
    [
        {"title": "   "},
        {"subject": ""},
        {"author": "  "},
        {"year": 1500},
        {"year": 3000},
        {"file_url": "not-a-valid-url"},
    ],
)
def test_create_document_rejects_invalid_data(service, fake_repository, overrides):
    with pytest.raises(InvalidDocumentError):
        service.create_document(make_create_data(**overrides))
    assert len(fake_repository) == 0      # dữ liệu rác KHÔNG lọt xuống tầng dữ liệu


def test_create_document_rejects_duplicate(service):
    service.create_document(make_create_data())
    with pytest.raises(DuplicateDocumentError):
        service.create_document(make_create_data(author="Tác giả khác"))


def test_create_document_allows_same_title_different_subject(service):
    service.create_document(make_create_data(subject="Toán học"))
    view = service.create_document(make_create_data(subject="Vật lý"))
    assert view.subject == "Vật lý"


# ===================================================================== #
# USE-CASE: XEM CHI TIẾT
# ===================================================================== #
def test_get_document_returns_view(service):
    created = service.create_document(make_create_data())
    fetched = service.get_document(created.id)
    assert fetched.id == created.id
    assert fetched.title == created.title


def test_get_document_raises_business_error_when_missing(service):
    with pytest.raises(DocumentNotFoundError):
        service.get_document(uuid4())


# ===================================================================== #
# USE-CASE: TÌM KIẾM & LỌC
# ===================================================================== #
@pytest.fixture
def populated_service(fake_repository) -> DocumentService:
    service = DocumentService(fake_repository)
    service.create_document(make_create_data(title="Đạo hàm", subject="Toán học",
                                             doc_type=DocumentType.BAI_GIANG, year=2024))
    service.create_document(make_create_data(title="Bài tập đạo hàm", subject="Toán học",
                                             doc_type=DocumentType.BAI_TAP, year=2023))
    service.create_document(make_create_data(title="Giáo trình Python", subject="Lập trình",
                                             doc_type=DocumentType.TAI_LIEU_THAM_KHAO,
                                             author="Trần Thị B", year=2022))
    return service


def test_search_by_keyword_matches_title_subject_and_author(populated_service):
    assert len(populated_service.search_documents(DocumentSearchData(keyword="đạo hàm"))) == 2
    assert len(populated_service.search_documents(DocumentSearchData(keyword="Lập trình"))) == 1
    assert len(populated_service.search_documents(DocumentSearchData(keyword="Trần"))) == 1
    assert len(populated_service.search_documents(DocumentSearchData(keyword="vô hạn"))) == 0


def test_search_by_subject(populated_service):
    results = populated_service.search_documents(DocumentSearchData(subject="Toán học"))
    assert len(results) == 2


def test_search_by_document_type(populated_service):
    results = populated_service.search_documents(
        DocumentSearchData(doc_type=DocumentType.BAI_TAP)
    )
    assert [r.title for r in results] == ["Bài tập đạo hàm"]


def test_search_by_year_range(populated_service):
    results = populated_service.search_documents(
        DocumentSearchData(year_from=2023, year_to=2024)
    )
    assert {r.year for r in results} == {2023, 2024}


def test_search_combines_multiple_criteria(populated_service):
    results = populated_service.search_documents(
        DocumentSearchData(subject="Toán học", year_from=2024)
    )
    assert [r.title for r in results] == ["Đạo hàm"]


def test_search_without_criteria_returns_all_sorted(populated_service):
    results = populated_service.search_documents(DocumentSearchData())
    # Sắp xếp theo năm giảm dần
    assert [r.year for r in results] == [2024, 2023, 2022]


def test_search_pagination(populated_service):
    page1 = populated_service.search_documents(DocumentSearchData(limit=2, offset=0))
    page2 = populated_service.search_documents(DocumentSearchData(limit=2, offset=2))
    assert len(page1) == 2 and len(page2) == 1
    assert {r.id for r in page1} & {r.id for r in page2} == set()
    assert populated_service.count_documents(DocumentSearchData()) == 3


def test_search_limit_is_clamped_to_protect_resources(populated_service, fake_repository):
    populated_service.search_documents(DocumentSearchData(limit=9999))
    call = next(c for c in fake_repository.calls if c[0] == "search")
    assert call[2]["limit"] == 100          # bị chặn ở mức tối đa
    assert call[2]["offset"] >= 0


# ===================================================================== #
# USE-CASE: CẬP NHẬT
# ===================================================================== #
def test_update_document_partial_fields(service):
    created = service.create_document(make_create_data())
    updated = service.update_document(created.id, DocumentUpdateData(year=2025))

    assert updated.year == 2025
    assert updated.title == created.title      # trường khác giữ nguyên
    assert updated.updated_at >= created.updated_at


def test_update_document_rejects_empty_payload(service):
    created = service.create_document(make_create_data())
    with pytest.raises(InvalidDocumentError):
        service.update_document(created.id, DocumentUpdateData())


def test_update_document_validates_new_values(service):
    created = service.create_document(make_create_data())
    with pytest.raises(InvalidDocumentError):
        service.update_document(created.id, DocumentUpdateData(year=1000))


def test_update_document_raises_when_missing(service):
    with pytest.raises(DocumentNotFoundError):
        service.update_document(uuid4(), DocumentUpdateData(title="Mới"))


def test_update_document_allows_keeping_own_title(service):
    """Sửa `author` nhưng giữ nguyên `title`+`subject` -> KHÔNG bị báo trùng."""
    created = service.create_document(make_create_data())
    updated = service.update_document(created.id, DocumentUpdateData(author="Tác giả mới"))
    assert updated.author == "Tác giả mới"


def test_update_document_detects_duplicate_with_another_record(service):
    first = service.create_document(make_create_data(title="Tài liệu A", subject="Toán"))
    service.create_document(make_create_data(title="Tài liệu B", subject="Toán"))

    with pytest.raises(DuplicateDocumentError):
        service.update_document(first.id, DocumentUpdateData(title="Tài liệu B"))


# ===================================================================== #
# USE-CASE: XÓA
# ===================================================================== #
def test_delete_document(service, fake_repository):
    created = service.create_document(make_create_data())
    service.delete_document(created.id)
    assert len(fake_repository) == 0
    assert fake_repository.get_by_id(created.id) is None


def test_delete_document_raises_when_missing(service):
    with pytest.raises(DocumentNotFoundError):
        service.delete_document(uuid4())


# ===================================================================== #
# TRÁCH NHIỆM VÀ THỨ TỰ XỬ LÝ (kiểm chứng bằng lịch sử lời gọi)
# ===================================================================== #
def test_create_flow_order_validates_before_storing(service, fake_repository):
    """Nguyên tắc 'fail fast': kiểm tra trùng lặp PHẢI diễn ra trước khi ghi."""
    service.create_document(make_create_data())
    fake_repository.calls.clear()

    with pytest.raises(DuplicateDocumentError):
        service.create_document(make_create_data(author="Khác"))   # trùng tiêu đề + môn

    names = fake_repository.call_names
    assert names[0] == "exists_same_title_and_subject"
    assert "create" not in names            # đã dừng trước bước ghi


def test_update_flow_reads_before_writes(service, fake_repository):
    created = service.create_document(make_create_data())
    fake_repository.calls.clear()

    service.update_document(created.id, DocumentUpdateData(author="Mới"))

    assert fake_repository.call_names[0] == "get_by_id"
    assert "update" in fake_repository.call_names


# ===================================================================== #
# BẢN CHẤT: TẦNG APPLICATION KHÔNG CẦN KHO LƯU TRỮ (Mục 4 - trọng tâm)
# ===================================================================== #
def test_application_can_run_without_any_storage_implementation():
    """
    Câu hỏi kiểm chứng: nếu validation thất bại, service có cần kho lưu trữ không?
    Trả lời: KHÔNG. Với kho giả 'nổ' (ExplodingRepository), mọi test validation
    vẫn chạy được -> chứng minh nghiệp vụ và hạ tầng là hai thứ độc lập.
    """
    from .fakes import ExplodingRepository

    service = DocumentService(ExplodingRepository())
    with pytest.raises(InvalidDocumentError):
        service.create_document(make_create_data(year=999))
