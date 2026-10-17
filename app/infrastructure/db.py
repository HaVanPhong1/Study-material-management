"""
TẦNG INFRASTRUCTURE — Lớp kết nối cơ sở dữ liệu.

Đây là nơi DUY NHẤT trong toàn hệ thống được phép biết "SQLite" / "PostgreSQL"
là gì. Nếu muốn đổi hệ quản trị, chỉ sửa file này.

Vì sao bọc lại thành class `Database`?
  - `Session` của SQLAlchemy không thread-safe và không nên dùng chung.
  - Ta bọc lại để (a) quản lý vòng đời engine, (b) cấp Session theo request,
    (c) có một "context manager" giải phóng tài nguyên gọn một dòng.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from .orm_models import Base


class Database:
    """
    Đóng gói engine + session factory.
    Tầng Application không biết đối tượng này tồn tại.
    """

    def __init__(self, url: str, *, echo: bool = False) -> None:
        connect_args: dict[str, Any] = {}
        poolclass = None

        if url in ("sqlite://", "sqlite:///:memory:"):
            # SQLite trong RAM: mỗi CONNECTION là một database riêng.
            # FastAPI chạy endpoint ở threadpool, nên nếu mỗi thread một connection
            # thì request sau sẽ không thấy bảng đã tạo ở request trước.
            # StaticPool ép TẤT CẢ các thread dùng chung MỘT connection -> an toàn.
            poolclass = StaticPool
            connect_args["check_same_thread"] = False
        elif url.startswith("sqlite"):
            connect_args["check_same_thread"] = False

        self._engine: Engine = create_engine(
            url,
            echo=echo,
            future=True,
            connect_args=connect_args,
            poolclass=poolclass,
        )
        self._session_factory = sessionmaker(
            bind=self._engine, autoflush=False, expire_on_commit=False, future=True
        )

    @property
    def engine(self) -> Engine:
        return self._engine

    def create_all(self) -> None:
        """Tạo toàn bộ bảng theo model. Gọi 1 lần lúc khởi động ứng dụng."""
        Base.metadata.create_all(self._engine)

    def drop_all(self) -> None:
        """Xóa toàn bộ bảng — CHỈ dùng trong test/teardown."""
        Base.metadata.drop_all(self._engine)

    def new_session(self) -> Session:
        """Tạo một Session mới (mỗi request/use-case một session)."""
        return self._session_factory()

    @contextmanager
    def session_scope(self) -> Iterator[Session]:
        """
        Quản lý vòng đời Session: tự commit khi thoát thân, tự rollback khi lỗi.
        Giữ toàn bộ logic giao dịch ở TẦNG INFRASTRUCTURE, không rò ra tầng trên.
        """
        session = self._session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def dispose(self) -> None:
        """Giải phóng toàn bộ connection pool (dùng khi tắt ứng dụng)."""
        self._engine.dispose()

    def __repr__(self) -> str:  # giúp debug/log
        return f"<Database url={self._engine.url!s}>"


def build_sqlite_database(path: str = "documents.db", **kwargs: Any) -> Database:
    """Khởi tạo DB SQLite trên đĩa (dùng khi chạy ứng dụng thật)."""
    return Database(f"sqlite:///{path}", **kwargs)


def build_memory_database(**kwargs: Any) -> Database:
    """
    Khởi tạo SQLite trong RAM (dùng cho test/integration test).
    Nhờ dùng chung dialect SQLite với bản thật, nên test vẫn kiểm chứng được
    tính đúng đắn của câu truy vấn SQL.
    """
    return Database("sqlite://", **kwargs)
