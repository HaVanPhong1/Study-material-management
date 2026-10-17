"""TẦNG INFRASTRUCTURE — chi tiết kỹ thuật: database, ORM, repository cụ thể."""

from .db import Database, build_memory_database, build_sqlite_database
from .in_memory_document_repository import InMemoryDocumentRepository
from .sql_alchemy_document_repository import SqlAlchemyDocumentRepository

# Firebase (tùy chọn)
try:
    from .firebase_manager import FirebaseManager, FirebaseStorageRepository
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    FirebaseManager = None
    FirebaseStorageRepository = None

__all__ = [
    "Database",
    "build_sqlite_database",
    "build_memory_database",
    "InMemoryDocumentRepository",
    "SqlAlchemyDocumentRepository",
    "FirebaseManager",
    "FirebaseStorageRepository",
    "FIREBASE_AVAILABLE",
]
