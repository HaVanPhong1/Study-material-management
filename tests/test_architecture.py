"""
MỨC 4.6 — KIỂM THỬ TỰ ĐỘNG KIỂM TRA LUẬT KIẾN TRÚC  ★ ĐIỂM SẴN NHẤT ★

"Luật kiến trúc chỉ có giá trị nếu nó được KIỂM CHỨNG TỰ ĐỘNG."
File này đọc mã nguồn bằng AST (cây cú pháp) và kiểm tra rằng:

    ✅ Mũi tên phụ thuộc chỉ đi từ ngoài vào trong.
    ✅ Tầng Domain      không biết FastAPI / SQLAlchemy.
    ✅ Tầng Application không biết FastAPI / SQLAlchemy / tầng hạ tầng.
    ✅ Tầng Presentation không biết SQLAlchemy.
    ✅ Chỉ `container.py` được phép biết cả hai phía (đó là vai trò Composition Root).

Nếu trong quá trình viết code, ai đó "tiện tay" thêm
`from sqlalchemy import ...` vào tầng nghiệp vụ, bộ test này sẽ ĐỎ NGAY.
=> Kiến trúc được bảo vệ bởi chính bộ kiểm thử.
"""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

APP_DIR = Path(__file__).resolve().parents[1] / "app"


# --------------------------------------------------------------------- #
# BỘ LUẬT
# --------------------------------------------------------------------- #
#: Mỗi tầng -> danh sách module/prefix BỊ CẤM import vào.
FORBIDDEN_IMPORTS: dict[str, tuple[tuple[str, ...], ...]] = {
    # Tầng lõi: tuyệt đối trắng trơn
    "app.domain": (
        ("fastapi", "pydantic", "sqlalchemy", "sqlite3", "requests", "httpx"),
        ("app.infrastructure", "app.presentation", "app.container", "app.main"),
    ),
    # Tầng nghiệp vụ: biết nghiệp vụ, không biết framework và không biết hạ tầng
    "app.application": (
        ("fastapi", "pydantic", "sqlalchemy", "sqlite3", "httpx", "starlette"),
        ("app.infrastructure", "app.presentation", "app.container", "app.main"),
    ),
    # Tầng trình bày: biết HTTP, không biết SQL
    "app.presentation": (
        ("sqlalchemy", "sqlite3"),
        ("app.infrastructure",),
    ),
    # Tầng hạ tầng: biết kỹ thuật, không biết HTTP
    "app.infrastructure": (
        ("fastapi", "starlette"),
        ("app.presentation", "app.main"),
    ),
}

#: Chỉ được phép nằm ở ngoài domain/application, vì nó là "mắt xích" hợp pháp.
ALLOWED_TO_IMPORT_INFRA_AND_APP = {"app.container", "app.main"}


def _module_name_for(path: Path) -> str:
    """app/domain/entities.py -> app.domain.entities"""
    relative = path.relative_to(APP_DIR.parent)
    return ".".join(relative.with_suffix("").parts)


def _resolve_relative(module: str, level: int, current_package: str) -> str:
    """
    Chuyển import tương đối (`from ..domain import x`) thành tên module tuyệt đối.
    level=1 -> chính package hiện tại; level=2 -> package cha; ...
    """
    parts = current_package.split(".")
    base = parts[: len(parts) - (level - 1)] if level > 1 else parts
    if module:
        return ".".join(base + module.split("."))
    return ".".join(base)


def _collect_imports(path: Path) -> list[str]:
    """Trả về danh sách TÊN MODULE được import trong file (dạng tuyệt đối)."""
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    module_name = _module_name_for(path)
    current_package = module_name.rsplit(".", 1)[0] if path.name != "__init__.py" \
        else module_name

    imported: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            if node.level and node.level > 0:
                base = _resolve_relative(node.module or "", node.level, current_package)
                imported.append(base)
            elif node.module:
                imported.append(node.module)
    return imported


def _is_forbidden(imported: str, forbidden_groups: tuple[tuple[str, ...], ...]) -> str | None:
    for group in forbidden_groups:
        for prefix in group:
            if imported == prefix or imported.startswith(prefix + "."):
                return prefix
    return None


# --------------------------------------------------------------------- #
# TEST
# --------------------------------------------------------------------- #
def _all_source_files() -> list[Path]:
    return sorted(p for p in APP_DIR.rglob("*.py"))


def test_source_tree_contains_all_four_layers():
    """Bảo đảm cây thư mục không bị thay đổi/bỏ sót tầng."""
    names = {p.parent.name for p in _all_source_files()}
    assert {"domain", "application", "infrastructure", "presentation"} <= names


@pytest.mark.parametrize("layer", sorted(FORBIDDEN_IMPORTS))
def test_layer_respects_one_way_dependency_rule(layer):
    """Mỗi tầng chỉ được import những gì luật cho phép."""
    violations: list[str] = []
    for path in _all_source_files():
        module_name = _module_name_for(path)
        if module_name != layer and not module_name.startswith(layer + "."):
            continue
        for imported in _collect_imports(path):
            offending = _is_forbidden(imported, FORBIDDEN_IMPORTS[layer])
            if offending:
                violations.append(
                    f"{path.relative_to(APP_DIR.parent)} import '{imported}' "
                    f"(bị cấm trong tầng {layer})"
                )
    assert not violations, "Vi phạm phụ thuộc một chiều:\n  - " + "\n  - ".join(violations)


def test_domain_layer_is_technology_agnostic():
    """Kiểm tra cụ thể cho tầng Domain — tầng quan trọng nhất."""
    banned = {"fastapi", "pydantic", "sqlalchemy", "sqlite3", "httpx", "pydantic_settings"}
    for path in _all_source_files():
        if not _module_name_for(path).startswith("app.domain"):
            continue
        for imported in _collect_imports(path):
            root = imported.split(".")[0]
            assert root not in banned, (
                f"{path.name} không được phụ thuộc vào '{imported}' — "
                f"tầng Domain phải độc lập với công nghệ."
            )


def test_only_composition_root_wires_the_layers():
    """
    Chỉ `app/container.py` được 'biết' cả Infrastructure lẫn Application.
    Đây là bằng chứng cho Dependency Injection thay vì phụ thuộc ẩn.
    """
    allowed = ALLOWED_TO_IMPORT_INFRA_AND_APP
    for path in _all_source_files():
        module_name = _module_name_for(path)
        if module_name in allowed:
            continue
        imports = _collect_imports(path)
        uses_infra = any(i.startswith("app.infrastructure") for i in imports)
        uses_app = any(i.startswith("app.application") for i in imports)
        assert not (uses_infra and uses_app), (
            f"{module_name} vừa import infrastructure vừa import application. "
            f"Chỉ {sorted(allowed)} được phép đóng vai trò Composition Root."
        )


def test_repository_interface_lives_in_domain():
    """Interface phải nằm trong Domain, không nằm ở tầng hạ tầng."""
    repository_path = APP_DIR / "domain" / "repository.py"
    assert repository_path.exists()
    text = repository_path.read_text(encoding="utf-8")
    assert "class DocumentRepository(ABC)" in text
    assert "@abstractmethod" in text


def _code_without_comments_and_strings(path: Path) -> str:
    """
    Bỏ comment và chuỗi (bao gồm docstring) khỏi mã nguồn.
    Mục đích: tìm từ khoá cấm trong CODE thực sự, không phải trong phần giải thích.
    Dùng module `tokenize` của thư viện chuẩn — không cần thư viện ngoài.
    """
    import io
    import tokenize

    kept: list[str] = []
    with path.open("rb") as handle:
        for token in tokenize.tokenize(handle.readline):
            if token.type in (tokenize.COMMENT, tokenize.STRING):
                continue
            kept.append(token.string)
    return " ".join(kept)


def test_service_never_mentions_sql_in_its_source():
    """
    Rà soát thô (nhanh, bổ sung cho kiểm tra AST) trên mã nguồn tầng nghiệp vụ:
    không được có từ khoá của framework / câu lệnh SQL.
    """
    service_path = APP_DIR / "application" / "document_service.py"
    code = _code_without_comments_and_strings(service_path)
    for forbidden in ("sqlalchemy", "sqlite3", "SELECT", "INSERT", "fastapi", "pydantic"):
        assert forbidden not in code, (
            f"Tầng nghiệp vụ chứa tham chiếu tới '{forbidden}' — vi phạm ranh giới tầng."
        )


def test_router_contains_no_business_conditions():
    """
    Router phải mỏng: không được chứa `if` nghiệp vụ.
    Ta chấp nhận `if` chỉ khi nằm trong docstring hoặc hàm lồng nhau phức tạp —
    cách kiểm tra thực tế: đếm số lệnh `if` cấp hàm.
    """
    router_path = APP_DIR / "presentation" / "api" / "documents_router.py"
    tree = ast.parse(router_path.read_text(encoding="utf-8"))
    function_level_ifs = 0
    for function in [n for n in ast.walk(tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]:
        for node in ast.walk(function):
            if isinstance(node, ast.If):
                function_level_ifs += 1
    assert function_level_ifs == 0, (
        "Router chứa câu lệnh rẽ nhánh — logic nghiệp vụ phải nằm ở tầng Application."
    )
