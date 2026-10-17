"""
KIỂM THỬ GIAO DIỆN WEB (tầng Presentation).

Giao diện là tài nguyên tĩnh nên không cần test từng thao tác chuột trong trình
duyệt. Cái cần bảo đảm là:
  1. Ứng dụng phục vụ được giao diện.
  2. Giao diện chỉ dùng API công khai và không nhúng logic nghiệp vụ
     (kiểm tra bằng cách rà soát nội dung file).
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import WEB_DIR, create_app

INDEX_HTML = WEB_DIR / "index.html"


def _client() -> TestClient:
    return TestClient(create_app(Settings(storage_backend="in_memory")))


def test_web_asset_exists():
    assert INDEX_HTML.exists(), "Thiếu file giao diện app/presentation/web/index.html"


def test_root_redirects_to_ui(client_in_memory):
    response = client_in_memory.get("/", follow_redirects=False)
    assert response.status_code in (302, 307)
    assert response.headers["location"] == "/ui/"


def test_ui_page_is_served(client_in_memory):
    response = client_in_memory.get("/ui/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]


def test_ui_contains_required_features():
    """Giao diện phải có đủ 4 nhóm chức năng của đề bài."""
    html = INDEX_HTML.read_text(encoding="utf-8")
    assert 'id="doc-form"' in html          # Thêm / Sửa
    assert 'id="search-form"' in html       # Tìm kiếm & Lọc
    assert 'data-act="delete"' in html      # Xoá
    assert "/api/documents" in html         # gọi đúng API của tầng trình bày


def test_ui_does_not_duplicate_business_logic():
    """
    Ranh giới tầng: giao diện KHÔNG được tự kiểm tra nghiệp vụ.
    Nếu file giao diện chứa các quy tắc như "năm phải trong khoảng" hay
    "kiểm tra trùng", thì logic sẽ bị lặp ở hai nơi và dễ lệch nhau.
    """
    html = INDEX_HTML.read_text(encoding="utf-8")
    forbidden = ["sqlalchemy", "sqlite3", "SELECT * FROM", "INSERT INTO"]
    for token in forbidden:
        assert token not in html, f"Giao diện không được chứa '{token}'."
    # Năm chỉ được ràng buộc bằng thuộc tính HTML, không có đoạn so sánh thủ công.
    assert "if (year <" not in html and "if (year >" not in html