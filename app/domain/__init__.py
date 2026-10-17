"""TẦNG DOMAIN — lõi nghiệp vụ, không phụ thuộc bất kỳ framework nào."""

from .entities import Document, DocumentFilter, DocumentType
from .exceptions import (
    DomainError,
    DocumentNotFoundError,
    DuplicateDocumentError,
    InvalidDocumentError,
)
from .repository import DocumentRepository

__all__ = [
    "Document",
    "DocumentType",
    "DocumentFilter",
    "DocumentRepository",
    "DomainError",
    "DocumentNotFoundError",
    "DuplicateDocumentError",
    "InvalidDocumentError",
]
