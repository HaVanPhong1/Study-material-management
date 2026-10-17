"""
TẦNG PRESENTATION — ĐỊNH NGHĨA API (Router).

Đây là lớp MỎNG nhất của hệ thống. Quy tắc bất di bất dịch:
  ❌ KHÔNG có `if` nghiệp vụ        ❌ KHÔNG gọi trực tiếp repository
  ❌ KHÔNG biết SQL                  ❌ KHÔNG chứa câu lệnh SQL
Mỗi endpoint chỉ làm đúng 3 việc:
      nhận schema  ->  đổi thành DTO  ->  gọi đúng 1 hàm của Service.
Đây gọi là "Thin Controller" — dấu hiệu sức khoẻ của một kiến trúc tốt.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status

from ...domain import DocumentType
from ..dependencies import DocumentServiceDep
from ..schemas import (
    DocumentCreateRequest,
    DocumentListResponse,
    DocumentResponse,
    DocumentUpdateRequest,
    ErrorResponse,
)

router = APIRouter(prefix="/documents", tags=["Tài liệu học tập"])

# Lỗi nghiệp vụ có thể xảy ra ở từng endpoint -> khai báo để sinh tài liệu OpenAPI chuẩn.
HTTP_422 = 422   # Unprocessable Content (giữ hằng số số để tương thích mọi phiên bản)
_NOT_FOUND = {status.HTTP_404_NOT_FOUND: {"model": ErrorResponse}}
_CONFLICT = {status.HTTP_409_CONFLICT: {"model": ErrorResponse}}
_INVALID = {HTTP_422: {"model": ErrorResponse}}


# --------------------------------------------------------------------- #
# 1. TẠO TÀI LIỆU
# --------------------------------------------------------------------- #
@router.post(
    "",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Thêm tài liệu mới",
    responses=_CONFLICT | _INVALID,
)
def create_document(payload: DocumentCreateRequest,
                    service: DocumentServiceDep) -> DocumentResponse:
    view = service.create_document(payload.to_command())
    return DocumentResponse.from_view(view)


# --------------------------------------------------------------------- #
# 2. TÌM KIẾM & LỌC  (đặt trước /{document_id} để không bị nuốt sai route)
# --------------------------------------------------------------------- #
@router.get(
    "",
    response_model=DocumentListResponse,
    summary="Tìm kiếm tài liệu theo từ khoá / môn học / loại / năm",
)
def search_documents(
    service: DocumentServiceDep,
    keyword: Annotated[str | None, Query(description="Từ khoá trong tên, môn, tác giả")] = None,
    subject: Annotated[str | None, Query(description="Lọc theo môn học")] = None,
    doc_type: Annotated[DocumentType | None, Query(description="Lọc theo loại tài liệu")] = None,
    year_from: Annotated[int | None, Query(ge=1900, le=2100, description="Năm từ")] = None,
    year_to: Annotated[int | None, Query(ge=1900, le=2100, description="Năm đến")] = None,
    limit: Annotated[int, Query(ge=1, le=100, description="Số bản ghi/trang")] = 20,
    offset: Annotated[int, Query(ge=0, description="Vị trí bắt đầu")] = 0,
) -> DocumentListResponse:
    from ...application import DocumentSearchData  # import cục bộ: giữ giao diện file gọn

    command = DocumentSearchData(
        keyword=keyword, subject=subject, doc_type=doc_type,
        year_from=year_from, year_to=year_to, limit=limit, offset=offset,
    )
    items = service.search_documents(command)
    total = service.count_documents(command)
    return DocumentListResponse(
        total=total, limit=limit, offset=offset,
        items=[DocumentResponse.from_view(item) for item in items],
    )


# --------------------------------------------------------------------- #
# 3. XEM CHI TIẾT
# --------------------------------------------------------------------- #
@router.get(
    "/{document_id}",
    response_model=DocumentResponse,
    summary="Xem chi tiết một tài liệu",
    responses=_NOT_FOUND,
)
def get_document(document_id: UUID, service: DocumentServiceDep) -> DocumentResponse:
    return DocumentResponse.from_view(service.get_document(document_id))


# --------------------------------------------------------------------- #
# 4. CẬP NHẬT
# --------------------------------------------------------------------- #
@router.put(
    "/{document_id}",
    response_model=DocumentResponse,
    summary="Cập nhật thông tin tài liệu",
    responses=_NOT_FOUND | _CONFLICT | _INVALID,
)
def update_document(
    document_id: UUID, payload: DocumentUpdateRequest, service: DocumentServiceDep
) -> DocumentResponse:
    view = service.update_document(document_id, payload.to_command())
    return DocumentResponse.from_view(view)


# --------------------------------------------------------------------- #
# 5. XÓA
# --------------------------------------------------------------------- #
@router.delete(
    "/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Xóa tài liệu",
    responses=_NOT_FOUND,
)
def delete_document(document_id: UUID, service: DocumentServiceDep) -> None:
    service.delete_document(document_id)
