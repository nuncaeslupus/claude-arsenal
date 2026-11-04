"""The redaction filter every bugreport script applies to what it prints.

Each identifier becomes `<kind:xxxxxxxx>`: eight hex characters of an
HMAC-SHA256 of the value under a per-run salt that is never stored. Equal values
share a token inside one output; nothing links two runs.

`filter` is pure — no I/O. The caller harvests the device's own identifiers
from a short list of sections with `harvest` and passes them in, which catches
an unkeyed IMSI or national phone number the patterns alone would miss. The
harvested set lives in memory only.

Over-redaction is the accepted direction: a bare Luhn-valid 15-digit run is
masked as an IMEI even when it is something else, because an over-redacted
excerpt costs a `--no-redact` rerun and an under-redacted one leaks.
"""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
from collections.abc import Callable, Iterable

# Sections the harvest reads, by section name (see _brlib.section names).
HARVEST_SECTIONS = ("iphonesubinfo", "telephony.registry", "account", "SYSTEM PROPERTIES")

_MAC_EXEMPT = {"00:00:00:00:00:00", "ff:ff:ff:ff:ff:ff", "02:00:00:00:00:00"}
_MIN_HARVEST_LEN = 6  # shorter values ("0", "1", "true") would mask half the report


def new_salt() -> bytes:
    return secrets.token_bytes(32)


def luhn_ok(digits: str) -> bool:
    total = 0
    for i, ch in enumerate(reversed(digits)):
        d = int(ch)
        if i % 2:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return total % 10 == 0


def token(kind: str, value: str, salt: bytes) -> str:
    digest = hmac.new(salt, value.encode("utf-8", "replace"), hashlib.sha256).hexdigest()
    return f"<{kind}:{digest[:8]}>"


# (kind, pattern, group holding the value, extra check). Group 0 replaces the
# whole match; a keyed pattern replaces only its value group, so the key stays
# readable ("mImei=<imei:…>").
_Check = Callable[[str], bool]
_RULES: list[tuple[str, re.Pattern[str], int, _Check | None]] = [
    ("email", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), 0, None),
    (
        "mac",
        re.compile(r"(?<![0-9A-Fa-f:-])(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f:-])"),
        0,
        lambda v: v.lower().replace("-", ":") not in _MAC_EXEMPT,
    ),
    (
        "account",
        re.compile(r"Account \{name=([^,}]+)"),
        1,
        None,
    ),
    (
        "ssid",
        re.compile(r"(?i)\bSSID\s*[=:]\s*(\"[^\"\n]*\"|[^\s,\"]+)"),
        1,
        lambda v: v.strip('"') not in ("", "<unknown ssid>", "<none>", "null"),
    ),
    (
        "coord",
        re.compile(
            r"(?:Location\[\w+ |\blat(?:itude)?=)"
            r"(-?\d{1,3}\.\d{3,},\s*(?:lon(?:gitude)?=)?-?\d{1,3}\.\d{3,})"
        ),
        1,
        None,
    ),
    (
        "serial",
        re.compile(r"(?:\[ro\.(?:boot\.)?serialno\]: \[|ro\.(?:boot\.)?serialno=)([^\]\s]+)"),
        1,
        None,
    ),
    (
        "iccid",
        re.compile(r"(?i)(?:\b(?:iccid|mIccId)\s*[=:]\s*)?(?<!\d)(89\d{17,18})(?!\d)"),
        1,
        luhn_ok,
    ),
    (
        "imsi",
        re.compile(r"(?i)\b(?:imsi|subscriberId)\s*[=:]\s*([2-7]\d{13,14})(?!\d)"),
        1,
        None,
    ),
    (
        "imei",
        re.compile(r"(?i)\b(?:meid)\s*[=:]\s*([0-9A-Fa-f]{14})(?![0-9A-Fa-f])"),
        1,
        None,
    ),
    (
        "imei",
        re.compile(r"(?i)(?:\b(?:imei|mImei|deviceId)\s*[=:]\s*)?(?<!\d)(\d{15})(?!\d)"),
        1,
        luhn_ok,
    ),
    (
        "phone",
        re.compile(r"(?i)\b(?:mLine1Number|phoneNumber|number)\s*[=:]\s*(\+?\d[\d -]{5,}\d)"),
        1,
        None,
    ),
    ("phone", re.compile(r"(?<![\w+])\+[1-9]\d{7,14}(?!\d)"), 0, None),
]

# The keyed patterns harvest() collects values from — the same rules, read for
# what they found instead of what they replace.
_HARVEST_KINDS = {"account", "serial", "iccid", "imsi", "imei", "phone", "email"}


def harvest(texts: Iterable[str]) -> dict[str, str]:
    """value -> kind for every identifier found in the harvest sections."""
    found: dict[str, str] = {}
    for text in texts:
        for kind, pattern, group, check in _RULES:
            if kind not in _HARVEST_KINDS:
                continue
            for m in pattern.finditer(text):
                value = m.group(group).strip()
                if len(value) >= _MIN_HARVEST_LEN and (check is None or check(value)):
                    found.setdefault(value, kind)
                    if kind == "phone":
                        # the national form a log line prints without the +CC
                        digits = re.sub(r"\D", "", value)
                        if len(digits) > 10:
                            found.setdefault(digits[-10:], kind)
    return found


def filter(text: str, salt: bytes, harvested: dict[str, str] | None = None) -> str:
    """Return `text` with every identifier replaced by its salted token."""
    for kind, pattern, group, check in _RULES:

        def _sub(
            m: re.Match[str], kind: str = kind, group: int = group, check: _Check | None = check
        ) -> str:
            value = m.group(group)
            if check is not None and not check(value):
                return m.group(0)
            if group == 0:
                return token(kind, value, salt)
            s, e = m.start(group) - m.start(0), m.end(group) - m.start(0)
            whole = m.group(0)
            return whole[:s] + token(kind, value, salt) + whole[e:]

        text = pattern.sub(_sub, text)
    for value in sorted(harvested or {}, key=len, reverse=True):
        if value in text:
            text = text.replace(value, token((harvested or {})[value], value, salt))
    return text


def walk(obj: object, salt: bytes, harvested: dict[str, str] | None) -> object:
    """Redact every string inside a JSON-shaped value; numbers pass unchanged."""
    if isinstance(obj, str):
        return filter(obj, salt, harvested)
    if isinstance(obj, list):
        return [walk(v, salt, harvested) for v in obj]
    if isinstance(obj, dict):
        return {k: walk(v, salt, harvested) for k, v in obj.items()}
    return obj
