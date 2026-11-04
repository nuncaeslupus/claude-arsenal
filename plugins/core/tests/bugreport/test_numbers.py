"""Tolerant number parsing: thousands separators, decimal commas, units."""

from __future__ import annotations

import _brlib as br
import pytest


def test_locale_decimal_comma_parses_as_number():
    assert br.parse_size("1,9GB") == pytest.approx(1.9 * (1 << 30))


@pytest.mark.parametrize(
    ("text", "value"),
    [("0,00", 0.0), ("2,612,345", 2612345), ("2.612.345", 2612345), ("1.5", 1.5), ("-3", -3)],
)
def test_parse_number_variants(text, value):
    assert br.parse_number(text) == pytest.approx(value)


@pytest.mark.parametrize(("text", "value"), [("512K", 512 << 10), ("48MB", 48 << 20), ("7", 7)])
def test_parse_size_units(text, value):
    assert br.parse_size(text) == value
