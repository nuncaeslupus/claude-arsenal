#!/usr/bin/env python3
"""Say whether a file is an Android bugreport and what kind, before reading it.

    validate_bugreport.py --input R [--json]

Prints one JSON document: is_bugreport, input kind and main entry, format
version, Android release/SDK/OEM/model, encoding facts (UTF-16 transcoded, bare
CR and NUL bytes), clock source, section and timed-out counts, and the status
of each detector input (parsed, fallback with its route, or absent). Exit 0 a bugreport,
1 not one (with the reason), 2 bad usage or internal error.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

import _brlib as br
import _detectors as det

SCHEMA = "bugreport.validate/1"


def report(rpt: br.Report) -> dict[str, Any]:
    inp = rpt.index["input"]
    return {
        "schema": SCHEMA,
        "is_bugreport": True,
        "input": {
            k: inp.get(k)
            for k in (
                "kind",
                "main_entry",
                "encoding",
                "transcoded",
                "cr_bytes",
                "nul_bytes",
                "proto_members",
            )
        },
        "header": rpt.header,
        "clock": rpt.clock["source"],
        "sections": len(rpt.sections),
        "timed_out": sum(1 for s in rpt.sections if s["timed_out"]),
        "detector_inputs": det.run(rpt)["inputs"],
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    br.add_report_args(p)
    args = p.parse_args(argv)

    def go() -> int:
        try:
            rpt = br.open_report(args.input, output_dir=args.output_dir, force=args.force)
        except br.NotABugreport as exc:
            print(json.dumps({"schema": SCHEMA, "is_bugreport": False, "reason": str(exc)}))
            return 1
        print(json.dumps(rpt.redactor(True)(report(rpt)), ensure_ascii=False))
        return 0

    return br.run(go)


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
