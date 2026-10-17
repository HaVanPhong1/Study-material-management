"""
MỨC 4.5 — KIỂM THỬ TÍCH HỢP (INTEGRATION / END-TOEND).

Đi từ HTTP request -> Router -> Service -> Repository -> DB thật -> trả JSON.
Các test này dùng chung cho cả hai backend thông qua `@pytest.mark.parametrize`
fixture, chứng minh API hoạt động giống hệt nhau dù lưu trữ bằng RAM hay SQLite.
"""

from __future__ import annotations

from uuid import uuid4

import pytest


@pytest.fixture(params=["in_memory", "sqlite"])
def client(request):
    """TestClient trên cả 2 backend -> mỗi test chạy 2 lần."""
    if request.param == "in_memory":
        with _client_for("in_memory") as c:
            yield c
    else:
        with _client_for("memory") as c:
            yield c


def _client_for(backend: str):
    from fastapi.testclient import TestClient

    from app.config import Settings
    from app.main import create_app

    return TestClient(create_app(Settings(storage_backend=backend)))


# --------------------------------------------------------------------- #
# HỆ THỐNG
# --------------------------------------------------------------------- #
def test_health_check(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_openapi_documents_the_api(client):
    response = client.get("/openapi.json")
    assert response.status_code == 200
    paths = response.json()["paths"]
    assert "/api/documents" in paths
    assert "/api/documents/{document_id}" in paths


# --------------------------------------------------------------------- #
# 1. TẠO TÀI LIỆU
# --------------------------------------------------------------------- #
def test_create_document_returns_201_and_persists(client, sample_payload):
    response = client.post("/api/documents", json=sample_payload)
    assert response.status_code == 201

    body = response.json()
    assert body["title"] == sample_payload["title"]
    assert body["doc_type"] == "bai_giang"
    assert body["doc_type_label"] == "Bài giảng"       # nhãn tiếng Việt do Domain cấp
    assert body["id"]

    # Xác nhận dữ liệu THỰC SỰ được lưu lại (không chỉ trả về)
    assert client.get(f"/api/documents/{body['id']}").status_code == 200


def test_create_document_requires_mandatory_fields(client):
    response = client.post("/api/documents", json={"title": "Thiếu dữ liệu"})
    assert response.status_code == 422        # bị chặn ngay ở tầng trình bày


def test_create_document_rejects_invalid_year(client, sample_payload):
    response = client.post("/api/documents", json={**sample_payload, "year": 1000})
    assert response.status_code == 422


def test_create_document_rejects_unknown_doc_type(client, sample_payload):
    response = client.post("/api/documents", json={**sample_payload, "doc_type": "abc"})
    assert response.status_code == 422


def test_create_duplicate_returns_409(client, sample_payload):
    client.post("/api/documents", json=sample_payload)
    response = client.post("/api/documents", json=sample_payload)
    assert response.status_code == 409
    assert response.json()["code"] == "DUPLICATE_DOCUMENT"


# --------------------------------------------------------------------- #
# 2. XEM CHI TIẾT
# --------------------------------------------------------------------- #
def test_get_document_detail(seeded_client):
    response = seeded_client.get("/api/documents?keyword=Giáo trình")
    doc_id = response.json()["items"][0]["id"]

    detail = seeded_client.get(f"/api/documents/{doc_id}")
    assert detail.status_code == 200
    assert detail.json()["title"] == "Giáo trình Lập trình Python"


def test_get_missing_document_returns_404_with_business_code(client):
    response = client.get(f"/api/documents/{uuid4()}")
    assert response.status_code == 404
    assert response.json() == {
        "code": "DOCUMENT_NOT_FOUND",
        "message": response.json()["message"],
    }
    assert "Không tìm thấy" in response.json()["message"]


def test_get_document_with_invalid_uuid_returns_422(client):
    assert client.get("/api/documents/khong-phai-uuid").status_code == 422


# --------------------------------------------------------------------- #
# 3. TÌM KIẾM & LỌC
# --------------------------------------------------------------------- #
def test_search_all_returns_everything(seeded_client):
    response = seeded_client.get("/api/documents")
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 5
    assert len(body["items"]) == 5


def test_search_by_keyword(seeded_client):
    body = seeded_client.get("/api/documents?keyword=giải tích").json()
    assert body["total"] == 2


def test_search_by_subject(seeded_client):
    body = seeded_client.get("/api/documents?subject=Lập trình").json()
    assert body["total"] == 2


def test_search_by_document_type(seeded_client):
    body = seeded_client.get("/api/documents?doc_type=bai_giang").json()
    assert body["total"] == 2
    assert {item["doc_type"] for item in body["items"]} == {"bai_giang"}


def test_search_by_year_range(seeded_client):
    body = seeded_client.get("/api/documents?year_from=2023&year_to=2024").json()
    assert {item["year"] for item in body["items"]} == {2023, 2024}


def test_search_combined_criteria(seeded_client):
    body = seeded_client.get("/api/documents?subject=Lập trình&doc_type=de_thi").json()
    assert body["total"] == 1
    assert body["items"][0]["title"].startswith("Đề thi")


def test_search_pagination_metadata(seeded_client):
    body = seeded_client.get("/api/documents?limit=2&offset=0").json()
    assert body["limit"] == 2 and body["offset"] == 0
    assert body["total"] == 5 and len(body["items"]) == 2

    page2 = seeded_client.get("/api/documents?limit=2&offset=2").json()
    assert len(page2["items"]) == 2
    assert {i["id"] for i in body["items"]}.isdisjoint({i["id"] for i in page2["items"]})


def test_search_with_no_result(seeded_client):
    body = seeded_client.get("/api/documents?keyword=khong-ton-tai-abc").json()
    assert body["total"] == 0 and body["items"] == []


def test_search_limit_is_capped_at_100(seeded_client):
    assert seeded_client.get("/api/documents?limit=500").status_code == 422
    assert seeded_client.get("/api/documents?limit=100").status_code == 200


# --------------------------------------------------------------------- #
# 4. CẬP NHẬT
# --------------------------------------------------------------------- #
def test_update_document_partial(seeded_client, sample_payload):
    doc_id = seeded_client.get("/api/documents?keyword=Giáo trình").json()["items"][0]["id"]

    response = seeded_client.put(f"/api/documents/{doc_id}", json={"year": 2026})
    assert response.status_code == 200
    body = response.json()
    assert body["year"] == 2026
    assert body["title"] == "Giáo trình Lập trình Python"     # không bị mất


def test_update_document_changes_type_label(seeded_client):
    doc_id = seeded_client.get("/api/documents?subject=Lập trình").json()["items"][0]["id"]
    body = seeded_client.put(f"/api/documents/{doc_id}", json={"doc_type": "de_thi"}).json()
    assert body["doc_type"] == "de_thi"
    assert body["doc_type_label"] == "Đề thi"


def test_update_missing_document_returns_404(client):
    response = client.put(f"/api/documents/{uuid4()}", json={"year": 2025})
    assert response.status_code == 404


def test_update_to_duplicate_returns_409(seeded_client):
    items = seeded_client.get("/api/documents?subject=Lập trình").json()["items"]
    target, other = items[0], items[1]
    response = seeded_client.put(f"/api/documents/{target['id']}",
                                 json={"title": other["title"]})
    assert response.status_code == 409
    assert response.json()["code"] == "DUPLICATE_DOCUMENT"


def test_update_with_empty_body_returns_422_business_error(seeded_client):
    doc_id = seeded_client.get("/api/documents").json()["items"][0]["id"]
    response = seeded_client.put(f"/api/documents/{doc_id}", json={})
    assert response.status_code == 422
    assert response.json()["code"] == "INVALID_DOCUMENT"


# --------------------------------------------------------------------- #
# 5. XÓA
# --------------------------------------------------------------------- #
def test_delete_document(seeded_client):
    doc_id = seeded_client.get("/api/documents").json()["items"][0]["id"]

    assert seeded_client.delete(f"/api/documents/{doc_id}").status_code == 204
    assert seeded_client.get(f"/api/documents/{doc_id}").status_code == 404
    assert seeded_client.get("/api/documents").json()["total"] == 4


def test_delete_missing_document_returns_404(client):
    response = client.delete(f"/api/documents/{uuid4()}")
    assert response.status_code == 404
    assert response.json()["code"] == "DOCUMENT_NOT_FOUND"


# --------------------------------------------------------------------- #
# KỊCH BẢN TÍCH HỢP: chuỗi hành động đầy đủ (Create -> Read -> Update -> Delete)
# --------------------------------------------------------------------- #
def test_full_crud_journey(client, sample_payload):
    # CREATE
    created = client.post("/api/documents", json=sample_payload).json()
    assert created["id"]

    # READ
    assert client.get(f"/api/documents/{created['id']}").json() == created

    # UPDATE
    updated = client.put(
        f"/api/documents/{created['id']}",
        json={"title": "Giải tích 1 (bản 2026)", "year": 2026},
    ).json()
    assert updated["title"] == "Giải tích 1 (bản 2026)"
    assert updated["year"] == 2026
    assert updated["subject"] == sample_payload["subject"]     # giữ nguyên

    # SEARCH thấy tên mới
    assert client.get("/api/documents?keyword=bản 2026").json()["total"] == 1

    # DELETE
    assert client.delete(f"/api/documents/{created['id']}").status_code == 204
    assert client.get("/api/documents").json()["total"] == 0
