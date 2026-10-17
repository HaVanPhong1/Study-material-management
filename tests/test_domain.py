"""
MỤC 4.1 — UNIT TEST TẦNG DOMAIN.

Đối tượng kiểm thử: app/domain/*
Cách chạy: pytest tests/test_domain.py
Kết luận mong đợi: tầng Domain kiểm thử được, không cần database, không cần HTTP.
"""

from __future__ import annotations

from uuid import uuid4

import pytest

from app.domain import Document, DocumentFilter, DocumentType
from app.domain import rules


# --------------------------------------------------------------------- #
# ENTITY
# --------------------------------------------------------------------- #
def test_document_gets_id_and_timestamps_automatically():
    doc = Document(title="ABC", subject="Toán", doc_type=DocumentType.BAI_GIANG,
                   author="A", year=2024)
    assert doc.id is not None
    assert doc.created_at is not None and doc.updated_at is not None
    assert doc.file_url is None


def test_apply_change_updates_only_given_fields():
    doc = Document(title="ABC", subject="Toán", doc_type=DocumentType.BAI_GIANG,
                   author="A", year=2024)
    original_created = doc.created_at
    original_updated = doc.updated_at

    doc.apply_change(title="ABC phiên bản 2")

    assert doc.title == "ABC phiên bản 2"
    assert doc.subject == "Toán"          # không đổi
    assert doc.year == 2024              # không đổi
    assert doc.created_at == original_created       # created_at bất biến
    assert doc.updated_at >= original_updated       # updated_at được chạm


def test_two_documents_get_different_ids():
    a = Document(title="A", subject="S", doc_type=DocumentType.BAI_TAP, author="x", year=2020)
    b = Document(title="B", subject="S", doc_type=DocumentType.BAI_TAP, author="x", year=2020)
    assert a.id != b.id


# --------------------------------------------------------------------- #
# ENUM
# --------------------------------------------------------------------- #
def test_document_type_display_name_is_vietnamese():
    assert DocumentType.BAI_GIANG.display_name == "Bài giảng"
    assert DocumentType.BAI_TAP.display_name == "Bài tập"
    assert DocumentType.TAI_LIEU_THAM_KHAO.display_name == "Tài liệu tham khảo"
    assert DocumentType.DE_THI.display_name == "Đề thi"


# --------------------------------------------------------------------- #
# QUY TẮC NGHIỆP VỤ
# --------------------------------------------------------------------- #
@pytest.mark.parametrize(
    "field, label",
    [
        (lambda: rules.validate_title("   "), "Tiêu đề"),
        (lambda: rules.validate_required_text("", "Môn học"), "Môn học"),
        (lambda: rules.validate_required_text("   ", "Tác giả"), "Tác giả"),
    ],
)
def test_required_fields_reject_blank_values(field, label):
    with pytest.raises(ValueError):
        field()


def test_title_is_trimmed_and_length_limited():
    assert rules.validate_title("  Toán học  ") == "Toán học"
    with pytest.raises(ValueError):
        rules.validate_title("a" * (rules.MAX_TITLE_LENGTH + 1))


@pytest.mark.parametrize("year", [0, 1989, 2101, 9999])
def test_year_out_of_allowed_range_is_rejected(year):
    with pytest.raises(ValueError):
        rules.validate_year(year)


def test_year_must_be_integer():
    with pytest.raises(ValueError):
        rules.validate_year("2024")  # type: ignore[arg-type]


@pytest.mark.parametrize("url", ["ftp://x.com", "javascript:alert(1)", "file.pdf"])
def test_invalid_file_url_is_rejected(url):
    with pytest.raises(ValueError):
        rules.validate_url(url)


@pytest.mark.parametrize("url", [None, "  ", "https://a.vn/b.pdf", "http://a.vn/b.pdf", "/uploads/b.pdf"])
def test_valid_file_url_is_accepted(url):
    rules.validate_url(url)


def test_assert_document_is_valid_passes_for_good_document():
    doc = Document(title="T", subject="S", doc_type=DocumentType.BAI_GIANG,
                   author="A", year=2024)
    rules.assert_document_is_valid(doc)      # không ném lỗi


def test_assert_document_is_valid_catches_bad_document():
    doc = Document(title="T", subject="S", doc_type=DocumentType.BAI_GIANG,
                   author="A", year=1200)
    with pytest.raises(ValueError):
        rules.assert_document_is_valid(doc)


# --------------------------------------------------------------------- #
# QUERY OBJECT
# --------------------------------------------------------------------- #
def test_empty_filter_is_recognized():
    assert DocumentFilter().is_empty() is True
    assert DocumentFilter(keyword="abc").is_empty() is False
    assert DocumentFilter(year_from=2020).is_empty() is False
