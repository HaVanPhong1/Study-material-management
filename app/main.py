"""
ĐIỂM KHỞI ĐỘNG ỨNG DỤNG (Application Entry Point).

Kiến trúc Cashew — sơ đồ phụ thuộc một chiều:

        ┌──────────────────────────────────────────────┐
        │  PRESENTATION  (FastAPI: router, schema)      │  biết HTTP
        └───────────────┬──────────────────────────────┘
                        │ gọi qua Interface
        ┌───────────────▼──────────────────────────────┐
        │  APPLICATION  (DocumentService, DTO)          │  biết NGHIỆP VỤ
        └───────────────┬──────────────────────────────┘
                        │ phụ thuộc vào Interface
        ┌───────────────▼──────────────────────────────┐
        │  DOMAIN       (Entity, Rule, Repository ABC)  │  biết GÌ (domain)
        └───────────────▲──────────────────────────────┘
                        │ hiện thực (đảo ngược phụ thuộc)
        ┌───────────────┴──────────────────────────────┐
        │  INFRASTRUCTURE (SQLAlchemy, SQLite, RAM)     │  biết CÁCH (kỹ thuật)
        └──────────────────────────────────────────────┘

CHẠY ỨNG DỤNG:
    uvicorn app.main:app --reload
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

from .config import Settings
from .container import build_container, get_container
from .presentation import register_exception_handlers
from .presentation.api import router as documents_router

#: Thư mục tài nguyên tĩnh của giao diện web (vẫn thuộc tầng Presentation).
WEB_DIR = Path(__file__).resolve().parent / "presentation" / "web"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Vòng đời ứng dụng (startup/shutdown).
    - Khởi tạo Container (và tạo bảng DB) LÚC KHỞI ĐỘNG, không phải mỗi request.
    - Giải phóng kết nối DB khi TẮT ứng dụng (tránh rò rỉ tài nguyên).

    Cấu hình được đọc từ `app.state.settings` do `create_app` ghi vào, nhờ đó
    ứng dụng luôn chạy đúng với cấu hình mà nó được khởi tạo (quan trọng khi test).
    """
    build_container(app.state.settings)
    yield
    get_container().dispose()


def create_app(settings: Settings | None = None) -> FastAPI:
    """
    Application Factory.

    Dùng factory thay vì khai báo `app = FastAPI()` ở module-level giúp:
      - Test có thể tạo nhiều ứng dụng độc lập với cấu hình khác nhau.
      - Cấu hình nằm trong hàm, dễ mở rộng thêm biến thể (v1, admin...).
    """
    cfg = settings or Settings.from_env()
    app = FastAPI(
        title=cfg.app_name,
        version=cfg.version,
        description=(
            "Ứng dụng Quản lý Tài liệu Học tập xây dựng theo **Kiến trúc Cashew**: "
            "tách biệt Presentation / Application / Domain / Infrastructure, "
            "phụ thuộc một chiều hướng vào trong (Dependency Inversion)."
        ),
        lifespan=lifespan,
    )
    # Cấu hình của riêng ứng dụng này, dùng lại trong lifespan.
    app.state.settings = cfg

    # Gắn handler chuyển lỗi nghiệp vụ -> mã HTTP
    register_exception_handlers(app)

    # Gắn router: Presentation -> Application
    app.include_router(documents_router, prefix="/api")

    @app.get("/api/health", tags=["Hệ thống"], summary="Kiểm tra sức khoẻ dịch vụ")
    def health_check() -> dict[str, str]:
        return {"status": "ok", "version": cfg.version}

    # ---- Giao diện web (tài nguyên tĩnh) ----
    # Nhờ kiến trúc phân tầng, giao diện là tài nguyên tĩnh thuần túy: nó chỉ gọi
    # REST API ở trên, không chứa logic nghiệp vụ, nên không vi phạm ranh giới tầng.
    if WEB_DIR.is_dir():
        app.mount("/ui", StaticFiles(directory=str(WEB_DIR), html=True), name="web-ui")

        @app.get("/", include_in_schema=False)
        def home() -> RedirectResponse:
            """Mở đường dẫn gốc thì chuyển thẳng tới giao diện."""
            return RedirectResponse(url="/ui/")

    return app


app = create_app()
