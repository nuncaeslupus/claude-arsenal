#!/usr/bin/env python3
"""Run the detector checkup over an Android bugreport and rank what it finds.

    analyze_bugreport.py --input R                    # the checkup: every family
    analyze_bugreport.py --input R --family memory    # one family, plus its view tables

Findings are ranked by severity, then score. Each names its subjects (with a
role: cause, victim, holder), the evidence offsets to open with
`query_bugreport.py show`, and an `advice_id`. A section a detector could not
read is a `not_parsed` row with the `query` command that reaches it instead.
Families: memory (F6, with the `churn` view), anr (F4), thermal (F2).
Exit 0 ran (findings or not), 1 not a bugreport, 2 bad usage or internal error.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

import _brlib as br
import _console as console
import _detectors as det

SCHEMA = "bugreport.analyze/1"
VIEW_ROWS = 5
ADVICE = Path(__file__).resolve().parent.parent / "references" / "advice.md"


def advice() -> dict[str, str]:
    """`### id` headings of references/advice.md -> the first line under each."""
    if not ADVICE.is_file():
        console.warn("references/advice.md is not written yet; --advice prints nothing")
        return {}
    text = ADVICE.read_text(encoding="utf-8")
    return dict(re.findall(r"^### (\S+)\n+(.+)$", text, re.M))


def _cap(view: dict[str, Any], limit: int | None) -> dict[str, Any]:
    if limit == 0:
        return view
    return {k: v[:VIEW_ROWS] if isinstance(v, list) else v for k, v in view.items()}


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    br.add_report_args(p)
    p.add_argument("--family", help="comma-separated families: slugs or F-numbers (default all)")
    p.add_argument("--severity", choices=det.SEVERITIES, help="minimum severity to report")
    p.add_argument("--advice", action="store_true", help="add the advice line to each finding")
    br.add_output_args(p, limit_help="max findings (0 = no caps)")
    args = p.parse_args(argv)

    def go() -> int:
        families, slugs = det.parse_families(args.family)
        rpt = br.open_report(args.input, output_dir=args.output_dir, force=args.force)
        res = det.run(rpt, families)
        findings = res["findings"]
        if args.severity:
            floor = det.SEVERITIES.index(args.severity)
            findings = [f for f in findings if det.SEVERITIES.index(f["severity"]) <= floor]
        if args.advice:
            lines = advice()
            for f in findings:
                f["advice"] = lines.get(f["advice_id"])
        not_parsed = res["not_parsed"]
        extra: dict[str, Any] = {}
        if slugs:
            views, failed = det.views(res["ctx"], slugs)
            not_parsed += failed
            extra["views"] = {k: _cap(v, args.limit) for k, v in views.items()}
        h = rpt.header
        by_sev = {s: n for s in det.SEVERITIES if (n := sum(f["severity"] == s for f in findings))}
        head = {
            "report": {
                **{k: h.get(k) for k in ("android_release", "sdk", "oem", "model", "build_id")},
                "captured_local": h.get("captured_local"),
                "uptime_s": h.get("uptime_s"),
                "clock_source": rpt.clock["source"],
            },
            "summary": {
                "findings": len(findings),
                "by_severity": by_sev,
                "detectors_run": res["detectors_run"],
                "not_parsed": len(not_parsed),
            },
            "not_parsed": not_parsed,
            **extra,
        }
        limit = 0 if args.output else args.limit
        doc = br.budget(SCHEMA, findings, limit=limit, cap=br.OUTPUT_BUDGET, extra=head)
        doc["findings"] = doc.pop("rows")
        br.write_doc(rpt.redactor(not args.no_redact)(doc), args.output)  # type: ignore[arg-type]
        return 0

    return br.run(go)


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
