"""Protobuf wire-format decoding, enough for `tombstone.proto` without a protobuf dependency.

A field is kept as a varint (`int`) or a length-delimited payload (`bytes`);
fixed64/fixed32 fields are skipped, since no field read here uses them. A
payload that is itself a message is decoded again by the caller.
"""

from __future__ import annotations

from typing import Any


def decode(buf: bytes) -> dict[int, list[int | bytes]]:
    """Field number -> its values in wire order; ValueError on a truncated or grouped buffer."""
    out: dict[int, list[int | bytes]] = {}
    i = 0

    def varint() -> int:
        nonlocal i
        n = shift = 0
        while True:
            if i >= len(buf):
                raise ValueError("truncated varint")
            b = buf[i]
            i += 1
            n |= (b & 0x7F) << shift
            if b < 0x80:
                return n
            shift += 7

    while i < len(buf):
        key = varint()
        num, wire = key >> 3, key & 7
        val: int | bytes
        if wire == 0:
            val = varint()
        elif wire == 2:
            n = varint()
            if i + n > len(buf):
                raise ValueError("truncated length-delimited field")
            val = buf[i : i + n]
            i += n
        elif wire in (1, 5):
            i += 8 if wire == 1 else 4
            continue
        else:
            raise ValueError(f"unsupported wire type {wire}")
        out.setdefault(num, []).append(val)
    return out


def _str(msg: dict[int, list[int | bytes]], num: int) -> str | None:
    v = msg.get(num, [None])[0]
    return v.decode("utf-8", "replace") if isinstance(v, bytes) else None


def _int(msg: dict[int, list[int | bytes]], num: int) -> int | None:
    v = msg.get(num, [None])[0]
    return v if isinstance(v, int) else None


def tombstone(buf: bytes) -> dict[str, Any]:
    """The crash facts of one `.pb` tombstone (AOSP `tombstone.proto` field numbers)."""
    t = decode(buf)
    raw = t.get(10, [b""])[0]
    sig = decode(raw) if isinstance(raw, bytes) else {}
    return {
        "process": _str(t, 9),  # command_line[0]
        "pid": _int(t, 5),
        "uid": _int(t, 7),
        "signal": _str(sig, 2),
        "signal_no": _int(sig, 1),
        "abort_message": _str(t, 14),
    }
