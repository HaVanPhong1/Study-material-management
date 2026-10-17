"""
TẦNG INFRASTRUCTURE — Firebase Integration.

Firebase cung cấp:
  1. Authentication (Google Sign-In via Firebase Auth)
  2. File Storage (Firebase Storage, S3-compatible)
  3. Real-time Database (tuỳ chọn)

Theo tinh thần Cashew, tầng này được tách biệt hoàn toàn: nếu không cần Firebase,
ứng dụng vẫn chạy được với SQLite + in-memory storage.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

try:
    import firebase_admin
    from firebase_admin import credentials, auth, storage
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False


class FirebaseInitializationError(Exception):
    """Lỗi khi khởi tạo Firebase."""
    pass


class FirebaseManager:
    """
    Quản lý kết nối Firebase (Auth + Storage).
    Chỉ khởi tạo nếu credentials có sẵn.
    """

    def __init__(
        self,
        project_id: str,
        credentials_path: str,
        storage_bucket: str,
    ):
        if not FIREBASE_AVAILABLE:
            raise FirebaseInitializationError(
                "firebase-admin chưa được cài đặt. "
                "Chạy: pip install firebase-admin"
            )

        self._project_id = project_id
        self._storage_bucket = storage_bucket

        # Khởi tạo Firebase Admin SDK
        try:
            cred = credentials.Certificate(credentials_path)
            firebase_admin.initialize_app(
                cred,
                {
                    "projectId": project_id,
                    "storageBucket": storage_bucket,
                },
            )
        except FileNotFoundError:
            raise FirebaseInitializationError(
                f"Không tìm thấy file credentials: {credentials_path}"
            )
        except Exception as e:
            raise FirebaseInitializationError(f"Firebase initialization failed: {e}") from e

    # ---- Authentication (Google Sign-In) ----
    def verify_id_token(self, token: str) -> dict:
        """
        Kiểm tra ID token từ frontend (sau khi user sign-in bằng Google).
        Trả về thông tin user: uid, email, name.
        """
        try:
            decoded = auth.verify_id_token(token)
            return {
                "uid": decoded["uid"],
                "email": decoded.get("email"),
                "name": decoded.get("name"),
                "picture": decoded.get("picture"),
            }
        except auth.InvalidIdTokenError as e:
            raise ValueError(f"Invalid ID token: {e}") from e

    def get_user(self, uid: str) -> dict:
        """Lấy thông tin user từ Firebase Auth."""
        try:
            user = auth.get_user(uid)
            return {
                "uid": user.uid,
                "email": user.email,
                "display_name": user.display_name,
                "photo_url": user.photo_url,
            }
        except auth.UserNotFoundError:
            return None

    # ---- File Storage (Firebase Storage) ----
    def upload_file(self, local_path: str, remote_path: str) -> str:
        """
        Upload file từ máy local lên Firebase Storage.
        Trả về public URL.
        """
        bucket = storage.bucket(self._storage_bucket)
        blob = bucket.blob(remote_path)
        blob.upload_from_filename(local_path)

        # Tạo public URL
        blob.make_public()
        return blob.public_url

    def upload_bytes(self, data: bytes, remote_path: str, content_type: str) -> str:
        """Upload bytes trực tiếp."""
        bucket = storage.bucket(self._storage_bucket)
        blob = bucket.blob(remote_path)
        blob.upload_from_string(data, content_type=content_type)
        blob.make_public()
        return blob.public_url

    def download_file(self, remote_path: str, local_path: str) -> None:
        """Download file từ Firebase Storage."""
        bucket = storage.bucket(self._storage_bucket)
        blob = bucket.blob(remote_path)
        blob.download_to_filename(local_path)

    def delete_file(self, remote_path: str) -> bool:
        """Xóa file khỏi Firebase Storage."""
        try:
            bucket = storage.bucket(self._storage_bucket)
            bucket.delete_blob(remote_path)
            return True
        except Exception as e:
            print(f"Error deleting file: {e}")
            return False

    def get_download_url(self, remote_path: str, expires_in: int = 3600) -> str:
        """
        Lấy signed download URL (hết hạn sau `expires_in` giây).
        Dùng khi muốn giới hạn thời gian truy cập.
        """
        bucket = storage.bucket(self._storage_bucket)
        blob = bucket.blob(remote_path)
        url = blob.generate_signed_url(
            version="v4",
            expiration=__import__("datetime").timedelta(seconds=expires_in),
            method="GET",
        )
        return url


class FirebaseStorageRepository:
    """
    Repository cho Firebase Storage — có thể thay thế S3.
    Cùng interface với S3Storage.
    """

    def __init__(self, firebase_manager: FirebaseManager):
        self._firebase = firebase_manager

    def upload_document(self, file_bytes: bytes, doc_id: str, filename: str) -> str:
        """Upload tài liệu lên Firebase Storage."""
        remote_path = f"documents/{doc_id}/{filename}"
        return self._firebase.upload_bytes(file_bytes, remote_path, "application/octet-stream")

    def download_document(self, doc_id: str, filename: str, local_path: str) -> bool:
        """Download tài liệu từ Firebase Storage."""
        try:
            remote_path = f"documents/{doc_id}/{filename}"
            self._firebase.download_file(remote_path, local_path)
            return True
        except Exception as e:
            print(f"Error downloading document: {e}")
            return False

    def delete_document(self, doc_id: str, filename: str) -> bool:
        """Xóa tài liệu khỏi Firebase Storage."""
        remote_path = f"documents/{doc_id}/{filename}"
        return self._firebase.delete_file(remote_path)

    def get_download_url(self, doc_id: str, filename: str, expires_in: int = 3600) -> str:
        """Lấy URL download (với thời hạn)."""
        remote_path = f"documents/{doc_id}/{filename}"
        return self._firebase.get_download_url(remote_path, expires_in)
