#!/usr/bin/env python3
"""Diff two analyze_bugreport.py JSON documents: new, gone and changed findings.

    analyze_bugreport.py --input old.zip --output old.json
    analyze_bugreport.py --input new.zip --output new.json
    compare_bugreport.py --input new.json --against old.json

A finding pairs with its counterpart on finding id plus its first subject's
package. Rows are `new` (only in --input), `gone` (only in --against) and
`changed` (severity moved, or score moved by 0.1 or more). `rankings` lists the
packages whose place in the memory holders or battery wakelocks moved; those
need `--family memory,battery` on both analyze runs. Redaction tokens compare
equal across reports, since each report has its own salt.
Exit 0 compared, 1 not an analyze document or schema majors differ, 2 bad usage.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import _brlib as br
import _detectors as det

SCHEMA = "bugreport.compare/1"
SCORE_MOVE = 0.1  # ponytail: starting value — smaller score moves are noise between captures
RANKED = {"memory": "holders", "battery": "wakelocks"}
_TOKEN = re.compile(r"<(\w+):[0-9a-f]{8}>")


def load(path: str) -> dict[str, Any]:
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        raise br.ReportError(f"cannot read {path}: {exc.strerror}") from exc
    try:
        doc: dict[str, Any] = json.loads(_TOKEN.sub(r"<\1>", text))  # salts differ per report
    except ValueError as exc:
        raise br.ReportError(f"{path} is not JSON") from exc
    if not str(doc.get("schema", "")).startswith("bugreport.analyze/") or "findings" not in doc:
        raise br.ReportError(f"{path} is not an analyze_bugreport.py document")
    if doc.get("truncated"):
        raise br.ReportError(f"{path} is truncated; rerun analyze with --output to keep every row")
    return doc


def _keyed(findings: list[dict[str, Any]]) -> dict[tuple[str, str | None, int], dict[str, Any]]:
    """(id, first subject's package, nth repeat) -> finding."""
    out: dict[tuple[str, str | None, int], dict[str, Any]] = {}
    for f in findings:
        pkg = (f.get("subjects") or [{}])[0].get("package")
        n = sum(k[:2] == (f["id"], pkg) for k in out)
        out[(f["id"], pkg, n)] = f
    return out


def _row(change: str, f: dict[str, Any], was: dict[str, Any] | None = None) -> dict[str, Any]:
    pkg = (f.get("subjects") or [{}])[0].get("package")
    row = {"change": change, "id": f["id"], "package": pkg}
    row.update({k: f[k] for k in ("severity", "score", "claim")})
    if was is not None:
        row["was"] = {"severity": was["severity"], "score": was["score"]}
    return row


def rankings(new: dict[str, Any], old: dict[str, Any]) -> list[dict[str, Any]]:
    out = []
    for slug, key in RANKED.items():
        a = new.get("views", {}).get(slug, {}).get(key)
        b = old.get("views", {}).get(slug, {}).get(key)
        if a is None or b is None:
            continue
        ra = {r["package"]: i for i, r in enumerate(a, 1)}
        rb = {r["package"]: i for i, r in enumerate(b, 1)}
        for pkg in sorted(ra.keys() | rb.keys()):
            if ra.get(pkg) != rb.get(pkg):
                out.append(
                    {
                        "view": f"{slug}.{key}",
                        "package": pkg,
                        "rank": ra.get(pkg),
                        "was": rb.get(pkg),
                    }
                )
    return out


def compare(new: dict[str, Any], old: dict[str, Any]) -> dict[str, Any]:
    major = [d["schema"].rsplit("/", 1)[1].split(".")[0] for d in (new, old)]
    if major[0] != major[1]:
        raise br.ReportError(
            f"schema majors differ ({new['schema']} vs {old['schema']}); rerun analyze on both"
        )
    a, b = _keyed(new["findings"]), _keyed(old["findings"])
    rows = [_row("new", a[k]) for k in a if k not in b]
    for k in a.keys() & b.keys():
        f, g = a[k], b[k]
        if f["severity"] != g["severity"] or abs(f["score"] - g["score"]) >= SCORE_MOVE:
            rows.append(_row("changed", f, g))
    rows += [_row("gone", b[k]) for k in b if k not in a]
    order = {"new": 0, "changed": 1, "gone": 2}
    rows.sort(
        key=lambda r: (
            order[r["change"]],
            det.SEVERITIES.index(r["severity"]),
            -r["score"],
            r["id"],
        )
    )
    return {"rows": rows, "rankings": rankings(new, old)}


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--input", required=True, help="the newer analyze JSON")
    p.add_argument("--against", required=True, help="the older analyze JSON")
    p.add_argument("--limit", type=int, help="max rows (0 = no caps)")
    p.add_argument("--output", help="write the full document here; print a one-line summary")
    args = p.parse_args(argv)

    def go() -> int:
        res = compare(load(args.input), load(args.against))
        rows = res["rows"]
        summary = {c: sum(r["change"] == c for r in rows) for c in ("new", "changed", "gone")}
        extra = {"summary": summary, "rankings": res["rankings"]}
        limit = 0 if args.output else args.limit
        doc = br.budget(SCHEMA, rows, limit=limit, cap=br.OUTPUT_BUDGET, extra=extra)
        doc["changes"] = doc.pop("rows")
        br.write_doc(doc, args.output)
        return 0

    return br.run(go)


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
