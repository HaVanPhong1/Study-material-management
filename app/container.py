"""
COMPOSITION ROOT — Điểm lắp ráp duy nhất của toàn hệ thống.

Đây là câu trả lời cho câu hỏi kinh điển trong kiến trúc phần mềm:
"Ở đâu chứa lệnh khởi tạo mọi thứ và biết ai phụ thuộc vào ai?"

Nguyên tắc của Cashew:
  - Mọi tầng khác chỉ nhận dependency qua CONSTRUCTOR/PARAMETER (Dependency Injection).
  - CHỈ file này được phép `new` ra các class cụ thể.
  - Nhờ đó, đổi "SQLite -> In-Memory -> PostgreSQL" chỉ là đổi 1 dòng cấu hình,
    và trong test ta cài một Container khác mà không sửa code nghiệp vụ.

Firebase Integration:
  - Container có thể khởi tạo FirebaseManager nếu được cấu hình.
  - Firebase chỉ được dùng khi ENABLE_FIREBASE=true.
"""

from __future__ import annotations

from contextlib import AbstractContextManager, contextmanager
from typing import Iterator, Literal, TYPE_CHECKING

from .application import DocumentService
from .config import Settings
from .domain import DocumentRepository
from .infrastructure import (
    Database,
    InMemoryDocumentRepository,
    SqlAlchemyDocumentRepository,
)
from .infrastructure.orm_models import Base

if TYPE_CHECKING:
    from .infrastructure import FirebaseManager, FirebaseStorageRepository

Backend = Literal["sqlite", "memory", "in_memory"]


class Container:
    """
    Hộp chứa dependency (IoC Container) — giữ tham chiếu tới các thành phần
    dài hạn của ứng dụng.
    """

    def __init__(self, backend: Backend = "sqlite", database_url: str | None = None,
                 *, echo: bool = False) -> None:
        self._backend: Backend = backend
        self._database: Database | None = None
        # Repository in-memory phải sống LÂU (dữ liệu giữa các request),
        # nên được tạo 1 lần và dùng lại.
        self._shared_in_memory_repo = InMemoryDocumentRepository()

        if backend in ("sqlite", "memory"):
            if backend == "memory":
                self._database = Database("sqlite://", echo=echo)
            else:
                self._database = Database(
                    database_url or "sqlite:///documents.db", echo=echo
                )
            self._database.create_all()

        # Firebase (optional)
        self._firebase_manager: "FirebaseManager | None" = None
        self._firebase_storage: "FirebaseStorageRepository | None" = None

    # ------------------------------------------------------------------ #
    @property
    def backend(self) -> Backend:
        return self._backend

    @contextmanager
    def repository_scope(self) -> Iterator[DocumentRepository]:
        """
        Cấp một Repository cho đúng một "phiên làm việc" (use-case/request)
        và tự động dọn dẹp tài nguyên khi kết thúc.

        Đây là abstraction quan trọng: tầng Presentation chỉ biết "xin một
        DocumentRepository", không biết nó đến từ SQL hay RAM.
        """
        if self._database is not None:
            with self._database.session_scope() as session:
                yield SqlAlchemyDocumentRepository(session)
        else:
            yield self._shared_in_memory_repo

    def document_service_scope(self) -> AbstractContextManager[DocumentService]:
        """Cấp sẵn cả Service, gom 2 bước xin dependency lại thành một."""
        return self._document_service_scope()

    @contextmanager
    def _document_service_scope(self) -> Iterator[DocumentService]:
        with self.repository_scope() as repository:
            yield DocumentService(repository)

    def create_document_service(self) -> DocumentService:
        """
        Tạo service gắn với repository dài hạn (chỉ dùng cho script/CLI/seed data).
        Lưu ý: với backend SQL, hãy dùng `document_service_scope()` cho request.
        """
        if self._database is not None:
            return DocumentService(SqlAlchemyDocumentRepository(self._database.new_session()))
        return DocumentService(self._shared_in_memory_repo)

    def create_all_tables(self) -> None:
        if self._database is not None:
            self._database.create_all()

    def drop_all_tables(self) -> None:
        if self._database is not None:
            self._database.drop_all()

    def dispose(self) -> None:
        """Giải phóng tài nguyên khi ứng dụng tắt."""
        if self._database is not None:
            self._database.dispose()
        # Firebase cleanup if needed

    # ------------------------------------------------------------------ #
    # Firebase (optional)
    # ------------------------------------------------------------------ #
    @property
    def firebase_enabled(self) -> bool:
        """Check if Firebase is configured and available."""
        return self._firebase_manager is not None

    def get_firebase_manager(self) -> "FirebaseManager | None":
        """Lấy FirebaseManager, lazy initialization."""
        return self._firebase_manager

    def get_firebase_storage(self) -> "FirebaseStorageRepository | None":
        """Lấy FirebaseStorageRepository."""
        return self._firebase_storage

    def _init_firebase(self, settings: Settings) -> None:
        """Khởi tạo Firebase nếu được cấu hình."""
        if not settings.enable_firebase:
            return

        try:
            from .infrastructure import FirebaseManager, FirebaseStorageRepository

            if not settings.firebase_credentials_path:
                return
            if not settings.firebase_project_id:
                return

            self._firebase_manager = FirebaseManager(
                project_id=settings.firebase_project_id,
                credentials_path=settings.firebase_credentials_path,
                storage_bucket=settings.firebase_storage_bucket or f"{settings.firebase_project_id}.appspot.com",
            )
            self._firebase_storage = FirebaseStorageRepository(self._firebase_manager)
        except Exception as e:
            # Firebase init failed - continue without it
            print(f"[WARN] Firebase initialization failed: {e}")
            self._firebase_manager = None
            self._firebase_storage = None

    def __repr__(self) -> str:
        return f"<Container backend={self._backend!r} firebase={self.firebase_enabled}>"


# --------------------------------------------------------------------- #
# Vòng đời toàn cục của Container
# --------------------------------------------------------------------- #
_container: Container | None = None


def build_container(settings: Settings | None = None) -> Container:
    """
    Khởi tạo Container từ cấu hình. Đây là hàm duy nhất được phép khởi tạo
    toàn bộ đồ thị dependency của ứng dụng.
    """
    global _container
    cfg = settings or Settings.from_env()
    _container = Container(
        backend=cfg.storage_backend,  # type: ignore[arg-type]
        database_url=cfg.database_url,
        echo=cfg.db_echo,
    )
    return _container


def get_container() -> Container:
    """Truy xuất Container đã khởi tạo (dùng trong FastAPI dependencies)."""
    global _container
    if _container is None:
        _container = build_container()
    return _container


def set_container(container: Container) -> None:
    """
    Cài đặt Container thủ công — CHỈ dùng trong test
    (đây chính là "điểm cắt" để thay DB mà không đụng tới code nghiệp vụ).
    """
    global _container
    _container = container


def reset_container() -> None:
    """Thu dọn Container (dùng trong test teardown)."""
    global _container
    if _container is not None:
        _container.dispose()
    _container = None


__all__ = ["Container", "build_container", "get_container", "set_container",
           "reset_container", "Base"]
