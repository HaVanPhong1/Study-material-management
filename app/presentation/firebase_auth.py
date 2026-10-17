"""
TẦNG PRESENTATION — Firebase Authentication Middleware.

Middleware xác thực người dùng qua Firebase ID Token.
Nếu không có Firebase, endpoint vẫn hoạt động (bỏ qua auth).
"""

from __future__ import annotations

from typing import Optional, Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from ..container import get_container

# Security scheme cho Swagger UI
bearer_scheme = HTTPBearer(auto_error=False)


class FirebaseUser:
    """User info extracted from Firebase token."""

    def __init__(self, uid: str, email: Optional[str], name: Optional[str]):
        self.uid = uid
        self.email = email
        self.name = name


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> Optional[FirebaseUser]:
    """
    Dependency để xác thực người dùng.
    
    Usage:
        @router.get("/protected", dependencies=[Depends(get_current_user)])
    hoặc
        @router.get("/me")
        async def get_me(user: FirebaseUser = Depends(get_current_user)):
            return {"uid": user.uid, "email": user.email}
    """
    container = get_container()
    if not container.firebase_enabled:
        return None

    if credentials is None:
        # Không có token -> bỏ qua (có thể là endpoint công khai)
        return None

    try:
        manager = container.get_firebase_manager()
        if manager is None:
            return None
        user_info = manager.verify_id_token(credentials.credentials)
        return FirebaseUser(
            uid=user_info["uid"],
            email=user_info.get("email"),
            name=user_info.get("name"),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}",
        )


async def require_user(
    user: Optional[FirebaseUser] = Depends(get_current_user),
) -> FirebaseUser:
    """Dependency yêu cầu người dùng phải đăng nhập."""
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    return user