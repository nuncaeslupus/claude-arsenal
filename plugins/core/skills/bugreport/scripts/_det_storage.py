"""F9 storage: low free space on /data, with the largest app caches from diskstats."""

from __future__ import annotations

import json
import re
from collections.abc import Iterator
from typing import Any

from _detectors import Context, Finding, NotParsed, detector, view

LOW_FREE_PCT = 5  # ponytail: starting value — AOSP's default low-storage threshold
MB = 1 << 20

_FREE = re.compile(r"^Data-Free: (\d+)K / (\d+)K total = (\d+)% free", re.M)
_LIST = re.compile(r"^(Package Names|Cache Sizes): (\[.*\])$", re.M)


def storage(ctx: Context) -> dict[str, Any] | None:
    sl = ctx.section("diskstats")
    if sl is None:
        return None
    m = _FREE.search(sl.text)
    if not m:
        raise NotParsed(sl.id, "no `Data-Free:` line")
    lists = {k: json.loads(v) for k, v in _LIST.findall(sl.text)}
    caches = sorted(
        zip(lists.get("Package Names", []), lists.get("Cache Sizes", []), strict=False),
        key=lambda pc: -pc[1],
    )
    return {
        "free_mb": int(m.group(1)) // 1024,
        "total_mb": int(m.group(2)) // 1024,
        "free_pct": int(m.group(3)),
        "top_caches": [{"package": p, "cache_mb": c // MB} for p, c in caches],
        "evidence": [sl.at(m)],
    }


@detector(
    id="storage.data_free",
    family="F9",
    inputs=("diskstats",),
    findings={"storage.low_free_space": "storage.clear-caches"},
)
def detect_low_storage(ctx: Context) -> Iterator[Finding]:
    s = storage(ctx)
    if s is None or s["free_pct"] >= LOW_FREE_PCT:
        return
    top = s["top_caches"][:3]
    yield Finding(
        "storage.low_free_space",
        "high" if s["free_pct"] <= 1 else "medium",
        1 - s["free_pct"] / LOW_FREE_PCT,
        f"/data is {s['free_pct']}% free ({s['free_mb']} MB)"
        + (f"; largest cache: {top[0]['package']} {top[0]['cache_mb']} MB" if top else ""),
        {k: s[k] for k in ("free_mb", "total_mb", "free_pct")},
        [{**c, "role": "holder"} for c in top],
        s["evidence"],
    )


@view("storage")
def storage_view(ctx: Context) -> dict[str, Any]:
    s = storage(ctx) or {"top_caches": []}
    return {k: v for k, v in s.items() if k != "evidence"}
