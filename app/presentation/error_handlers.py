"""
TẦNG PRESENTATION — Bộ chuyển đổi lỗi nghiệp vụ -> lỗi HTTP.

Đây là RANH GIỚI (boundary) giữa "thế giới nghiệp vụ" và "thế giới giao thức".
Nếu không có file này, FastAPI sẽ trả 500 Internal Server Error cho mọi lỗi
nghiệp vụ — người dùng không hiểu chuyện gì xảy ra.

Nguyên tắc giữ cho Domain: Domain KHÔNG BAO GIỜ được nhìn thấy HTTP status code.
"""

from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from ..domain import (
    DocumentNotFoundError,
    DomainError,
    DuplicateDocumentError,
    InvalidDocumentError,
)

# Bảng ánh xạ: loại lỗi nghiệp vụ -> mã HTTP tương ứng.
# Thêm loại lỗi mới ở Domain chỉ cần thêm 1 dòng ở đây, không sửa Domain.
_ERROR_TO_STATUS: dict[type[DomainError], int] = {
    DocumentNotFoundError: status.HTTP_404_NOT_FOUND,
    DuplicateDocumentError: status.HTTP_409_CONFLICT,
    InvalidDocumentError: 422,   # HTTP_422_UNPROCESSABLE_ENTITY đã bị đổi tên ở bản Starlette mới
}


def register_exception_handlers(app: FastAPI) -> None:
    """Gắn handler lỗi nghiệp vụ vào ứng dụng FastAPI."""

    @app.exception_handler(DomainError)
    async def handle_domain_error(_: Request, exc: DomainError) -> JSONResponse:
        http_status = _ERROR_TO_STATUS.get(type(exc), status.HTTP_400_BAD_REQUEST)
        return JSONResponse(
            status_code=http_status,
            content={"code": exc.code, "message": exc.message},
        )
