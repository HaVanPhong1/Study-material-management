"""
TẦNG PRESENTATION — Cơ chế tiêm dependency của FastAPI (Dependency Injection).

Tách thành file riêng để Router chỉ còn đúng MỘT trách nhiệm: định nghĩa endpoint.
Không có import SQLAlchemy ở bất kỳ đâu trong tầng Presentation.
"""

from __future__ import annotations

from typing import Annotated, Iterator

from fastapi import Depends

from ..application import DocumentService
from ..container import get_container


def get_document_service() -> Iterator[DocumentService]:
    """
    Cấp một DocumentService cho mỗi request.

    Cơ chế: `with` -> mở phiên làm việc (mở kết nối DB / lấy repository),
    khi request kết thúc thì tự commit + giải phóng tài nguyên.
    """
    with get_container().document_service_scope() as service:
        yield service


# Cú pháp rút gọn chuẩn của FastAPI (dùng Annotated thay cho cụm Depends(...) lặp lại).
DocumentServiceDep = Annotated[DocumentService, Depends(get_document_service)]
