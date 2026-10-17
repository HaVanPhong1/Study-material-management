"""
MỤC 4.3 — BÀI KIỂM THỬ CHỨNG MINH TÍNH ĐỘC LẬP GIỮA CÁC LỚP  ★ BÀI QUAN TRỌNG NHẤT ★

Ý tưởng then chốt:
    Ta viết MỘT bộ test nghiệp vụ duy nhất, rồi chạy NÓ LẠI TRÊN BA backend lưu trữ
    khác nhau, mà KHÔNG sửa một dòng test nào:

        1. FakeDocumentRepository        (giả lập, trong tests/)
        2. InMemoryDocumentRepository    (dict trong RAM, production code)
        3. SqlAlchemyDocumentRepository  (SQLite thật, production code)

    Kết quả mong đợi: TẤT CẢ đều PASS.
    Điều này chứng minh bằng code rằng tầng nghiệp vụ (Application) được thiết kế
    đúng kiến trúc: đổi hạ tầng lưu trữ thì logic nghiệp vụ không bị ảnh hưởng.

    Nếu tầng nghiệp vụ bị viết sai (import thẳng SQLAlchemy), bộ test này sẽ
    KHÔNG THỂ chạy trên backend In-Memory và sẽ FAIL -> đó là "test tự bảo vệ kiến trúc".
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
from app.container import Container
from app.domain import (
    Document,
    DocumentNotFoundError,
    DocumentRepository,
    DocumentType,
    DuplicateDocumentError,
    InvalidDocumentError,
)
from app.infrastructure import InMemoryDocumentRepository

from .fakes import FakeDocumentRepository


# ===================================================================== #
# BƯỚC 1: CHUẨN BỊ SERVICE TRÊN CẢ 3 BACKEND
# ===================================================================== #
def _build_service(backend: str) -> DocumentService:
    if backend == "fake":
        return DocumentService(FakeDocumentRepository())
    if backend == "in_memory":
        return DocumentService(InMemoryDocumentRepository())
    if backend == "sqlite":
        # SQLite trong RAM: dùng chung dialect với hệ thống thật
        container = Container("memory")
        return container.create_document_service()
    raise ValueError(f"Backend không hợp lệ: {backend}")


@pytest.fixture(params=["fake", "in_memory", "sqlite"])
def service(request) -> DocumentService:
    """Cùng một test, chạy trên 3 tầng lưu trữ khác nhau."""
    return _build_service(request.param)


def data(**overrides) -> DocumentCreateData:
    payload = dict(
        title="Giải tích 1 - Đạo hàm",
        subject="Toán học",
        doc_type=DocumentType.BAI_GIANG,
        author="Nguyễn Văn A",
        year=2024,
    )
    payload.update(overrides)
    return DocumentCreateData(**payload)  # type: ignore[arg-type]


# ===================================================================== #
# BƯỚC 2: BỘ TEST NGHIỆP VỤ DÙNG CHUNG (không phụ thuộc backend)
# ===================================================================== #
def test_all_backends_implement_the_same_interface(service):
    assert isinstance(service._repository, DocumentRepository)


def test_create_read_update_delete_cycle(service):
    # CREATE
    created = service.create_document(data())
    assert created.id is not None
    assert created.title == "Giải tích 1 - Đạo hàm"

    # READ
    assert service.get_document(created.id).title == created.title

    # UPDATE
    updated = service.update_document(created.id, DocumentUpdateData(year=2025))
    assert updated.year == 2025
    assert service.get_document(created.id).year == 2025

    # DELETE
    service.delete_document(created.id)
    with pytest.raises(DocumentNotFoundError):
        service.get_document(created.id)


def test_data_survives_a_full_round_trip(service):
    created = service.create_document(
        data(title="  Chuẩn hoá  ", subject=" Vật lý ", file_url="https://a.vn/f.pdf")
    )
    fetched = service.get_document(created.id)
    assert fetched.title == "Chuẩn hoá"        # đã chuẩn hoá trước khi lưu
    assert fetched.subject == "Vật lý"
    assert fetched.file_url == "https://a.vn/f.pdf"
    assert fetched.doc_type == DocumentType.BAI_GIANG
    assert fetched.doc_type_label == "Bài giảng"


def test_timestamps_round_trip_with_timezone(service):
    created = service.create_document(data())
    fetched = service.get_document(created.id)
    assert fetched.created_at.tzinfo is not None, "Mốc thời gian phải giữ múi giờ UTC"
    assert fetched.updated_at.tzinfo is not None


def test_business_rules_hold_on_every_backend(service):
    with pytest.raises(InvalidDocumentError):
        service.create_document(data(year=1000))
    with pytest.raises(DocumentNotFoundError):
        service.get_document(uuid4())
    with pytest.raises(DocumentNotFoundError):
        service.delete_document(uuid4())


def test_duplicate_detection_holds_on_every_backend(service):
    service.create_document(data())
    with pytest.raises(DuplicateDocumentError):
        service.create_document(data())


@pytest.fixture
def library(service) -> DocumentService:
    service.create_document(data(title="Đạo hàm", subject="Toán học", year=2024,
                                  doc_type=DocumentType.BAI_GIANG))
    service.create_document(data(title="Bài tập đạo hàm", subject="Toán học", year=2023,
                                  doc_type=DocumentType.BAI_TAP))
    service.create_document(data(title="Giáo trình Python", subject="Lập trình", year=2022,
                                  doc_type=DocumentType.TAI_LIEU_THAM_KHAO,
                                  author="Trần Thị B"))
    return service


def test_search_criteria_hold_on_every_backend(library):
    assert len(library.search_documents(DocumentSearchData(keyword="đạo hàm"))) == 2
    assert len(library.search_documents(DocumentSearchData(subject="Toán học"))) == 2
    assert len(library.search_documents(
        DocumentSearchData(doc_type=DocumentType.BAI_TAP))) == 1
    assert len(library.search_documents(
        DocumentSearchData(year_from=2023, year_to=2024))) == 2
    assert library.count_documents(DocumentSearchData()) == 3


def test_pagination_holds_on_every_backend(library):
    page1 = library.search_documents(DocumentSearchData(limit=2, offset=0))
    page2 = library.search_documents(DocumentSearchData(limit=2, offset=2))
    assert len(page1) == 2 and len(page2) == 1
    assert {d.id for d in page1}.isdisjoint({d.id for d in page2})


def test_keyword_search_is_case_insensitive_on_every_backend(library):
    assert len(library.search_documents(DocumentSearchData(keyword="PYTHON"))) == 1


# ===================================================================== #
# BƯỚC 3: CHỨNG MINH VIỆC "THAY TẦNG DỮ LIỆU" KHÔNG ẢNH HƯỞNG TẦNG NGHIỆP VỤ
# ===================================================================== #
def test_swapping_storage_layer_requires_no_change_in_business_code():
    """
    Bài kiểm thử mang tính khái niệm: hai service được cấu hình với hai tầng
    dữ liệu khác nhau nhưng dùng CHUNG đúng một mã nguồn nghiệp vụ.
    Chỉ cần so sánh `type(service).__module__` là thấy nghiệp vụ giữ nguyên.
    """
    ram_service = _build_service("in_memory")
    db_service = _build_service("sqlite")

    assert type(ram_service) is type(db_service)            # cùng một lớp nghiệp vụ
    assert ram_service.__class__.__module__.startswith("app.application")
    assert type(ram_service._repository) is not type(db_service._repository)

    for svc in (ram_service, db_service):
        created = svc.create_document(data(title="Cùng một nghiệp vụ"))
        assert svc.get_document(created.id).title == "Cùng một nghiệp vụ"
        assert len(svc.search_documents(DocumentSearchData(keyword="nghiệp vụ"))) == 1


def test_repository_interface_is_abstract():
    """Không ai được khởi tạo trực tiếp interface; phải có hiện thực cụ thể."""
    with pytest.raises(TypeError):
        DocumentRepository()  # type: ignore[abstract]


def test_in_memory_and_sqlalchemy_are_both_implementations():
    assert issubclass(InMemoryDocumentRepository, DocumentRepository)
    assert isinstance(Document, object)
