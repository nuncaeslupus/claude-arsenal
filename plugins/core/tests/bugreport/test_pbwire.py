"""The protobuf wire decoder behind `.pb` tombstones: known fields read, unknown ones skipped."""

from __future__ import annotations

import _pbwire as pb
import pytest


def test_pb_tombstone_yields_signal_and_abort_message(fx):
    t = pb.tombstone(fx.tombstone_pb())
    assert t == {
        "process": "com.example.app",
        "pid": 4321,
        "uid": 10234,
        "signal": "SIGABRT",
        "signal_no": 6,
        "abort_message": "example abort: invariant broken",
    }


def test_unknown_pb_fields_are_skipped(fx):
    fixed64 = bytes([15 << 3 | 1]) + bytes(8)
    fixed32 = bytes([13 << 3 | 5]) + bytes(4)
    msg = pb.decode(fixed64 + fx._pb([(5, 300)]) + fixed32 + fx._pb([(9, b"x"), (99999, 1)]))
    assert msg == {5: [300], 9: [b"x"], 99999: [1]}


def test_truncated_pb_raises():
    with pytest.raises(ValueError):
        pb.decode(bytes([9 << 3 | 2, 10]) + b"short")
