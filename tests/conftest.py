"""
CẤU HÌNH CHUNG CHO BỘ KIỂM THỬ (pytest fixtures).

Nguyên tắc: mỗi test phải độc lập — có dữ liệu sạch, không phụ thuộc thứ tự chạy.
Nhờ đó có thể chạy song song (`pytest -n`) mà không lỗi chéo.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

# Cho phép `import app...` khi chạy pytest từ thư mục gốc dự án.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.application import DocumentService  # noqa: E402
from app.config import Settings  # noqa: E402
from app.container import Container, reset_container, set_container  # noqa: E402
from app.main import create_app  # noqa: E402

from .fakes import FakeDocumentRepository  # noqa: E402


# ===================================================================== #
# TẦNG NGHIỆP VỤ — chỉ cần repository giả, KHÔNG cần database
# ===================================================================== #
@pytest.fixture
def fake_repository() -> FakeDocumentRepository:
    return FakeDocumentRepository()


@pytest.fixture
def service_with_fake(fake_repository: FakeDocumentRepository) -> DocumentService:
    """Service chạy trên kho dữ liệu giả -> unit test thuần, tức thì."""
    return DocumentService(fake_repository)


# ===================================================================== #
# TẦNG HẠ TẦNG — SQLite trong RAM (dùng cho integration test)
# ===================================================================== #
@pytest.fixture
def sqlite_container() -> Container:
    container = Container("memory")     # SQLite :memory: -> mỗi test một DB sạch
    yield container
    container.dispose()


@pytest.fixture
def service_with_sqlite(sqlite_container: Container):
    """Service thật, chạy trên SQLite thật -> integration test."""
    with sqlite_container.document_service_scope() as service:
        yield service


# ===================================================================== #
# TẦNG TRÌNH BÀY — TestClient gọi HTTP thật (end-to-end)
# ===================================================================== #
def _build_client(settings: Settings) -> TestClient:
    """Tạo ứng dụng FastAPI với cấu hình lưu trữ được chỉ định."""
    return TestClient(create_app(settings))


@pytest.fixture
def client_in_memory():
    """
    TestClient chạy hoàn toàn trong RAM (không cần cài SQLite file).
    Dùng để test API không phụ thuộc hạ tầng.
    """
    with _build_client(Settings(storage_backend="in_memory")) as client:
        yield client


@pytest.fixture
def client_sqlite():
    """
    TestClient chạy trên SQLite trong RAM — kiểm chứng từ endpoint HTTP
    xuống tận câu SQL thật.
    """
    settings = Settings(storage_backend="memory")
    with _build_client(settings) as client:
        yield client


@pytest.fixture
def make_service():
    """
    Factory: tạo service từ một Container bất kỳ.
    Có thể dùng để chứng minh cùng một bộ test chạy được trên NHIỀU backend.
    """
    def _factory(backend: str) -> DocumentService:
        container = Container(backend)  # type: ignore[arg-type]
        set_container(container)
        return container.create_document_service()

    yield _factory
    reset_container()


# ===================================================================== #
# DỮ LIỆU MẪU
# ===================================================================== #
SAMPLE_DOCUMENTS = [
    {
        "title": "Giải tích 1 - Chương 3: Đạo hàm",
        "subject": "Toán học",
        "doc_type": "bai_giang",
        "author": "Nguyễn Văn A",
        "year": 2024,
        "file_url": "https://example.com/dao-ham.pdf",
    },
    {
        "title": "Bài tập Giải tích 1 - Học kỳ 1",
        "subject": "Toán học",
        "doc_type": "bai_tap",
        "author": "Nguyễn Văn A",
        "year": 2023,
    },
    {
        "title": "Giáo trình Lập trình Python",
        "subject": "Lập trình",
        "doc_type": "tai_lieu_tham_khao",
        "author": "Trần Thị B",
        "year": 2022,
    },
    {
        "title": "Đề thi cuối kỳ Lập trình Python 2023",
        "subject": "Lập trình",
        "doc_type": "de_thi",
        "author": "Trần Thị B",
        "year": 2023,
    },
    {
        "title": "Slide Cấu trúc dữ liệu và Giải thuật",
        "subject": "Cấu trúc dữ liệu",
        "doc_type": "bai_giang",
        "author": "Lê Văn C",
        "year": 2025,
    },
]


@pytest.fixture
def sample_payload() -> dict:
    return dict(SAMPLE_DOCUMENTS[0])


@pytest.fixture
def seeded_client(client_in_memory, sample_payload):
    """TestClient đã có sẵn 5 tài liệu mẫu."""
    for payload in SAMPLE_DOCUMENTS:
        response = client_in_memory.post("/api/documents", json=payload)
        assert response.status_code == 201, response.text
    return client_in_memory
