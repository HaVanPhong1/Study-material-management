"""
CẤU HÌNH ứng dụng (Configuration).

Tách riêng khỏi code nghiệp vụ để tuân thủ nguyên tắc "12-factor":
cấu hình đến từ biến môi trường, không hard-code trong logic.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    """
    Cấu hình ứng dụng, đọc từ biến môi trường với giá trị mặc định an toàn.
    frozen=True: cấu hình là bất biến trong suốt vòng đời ứng dụng.
    """

    app_name: str = "Document Management API"
    version: str = "1.0.0"

    # "sqlite" : lưu xuống file thật -> dùng khi chạy ứng dụng
    # "memory" : SQLite trong RAM        -> dùng khi chạy test/integration test
    # "in_memory": dict trong RAM, KHÔNG cần database -> demo nhanh
    storage_backend: str = "sqlite"

    database_url: str | None = None
    db_echo: bool = False

    # Firebase configuration
    firebase_project_id: str | None = None
    firebase_api_key: str | None = None
    firebase_storage_bucket: str | None = None
    firebase_credentials_path: str | None = None  # Path to service-account-key.json
    enable_firebase: bool = False

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            app_name=os.getenv("APP_NAME", cls.app_name),
            version=os.getenv("APP_VERSION", cls.version),
            storage_backend=os.getenv("STORAGE_BACKEND", cls.storage_backend),
            database_url=os.getenv("DATABASE_URL"),
            db_echo=os.getenv("DB_ECHO", "false").lower() == "true",
            firebase_project_id=os.getenv("FIREBASE_PROJECT_ID"),
            firebase_api_key=os.getenv("FIREBASE_API_KEY"),
            firebase_storage_bucket=os.getenv("FIREBASE_STORAGE_BUCKET"),
            firebase_credentials_path=os.getenv("FIREBASE_CREDENTIALS_PATH"),
            enable_firebase=os.getenv("ENABLE_FIREBASE", "false").lower() == "true",
        )
