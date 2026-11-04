#!/usr/bin/env python3
"""Diff two analyze_bugreport.py JSON documents: new, gone and changed findings.

Not implemented until P4 of design 0005: this script only declares its flags
so `--help` shows the interface. Running it exits 2.
"""

from __future__ import annotations

import argparse
import sys

import _console as console


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--input", required=True, help="the newer analyze JSON")
    p.add_argument("--against", required=True, help="the older analyze JSON")
    p.add_argument("--limit", type=int, help="max rows (0 = no caps)")
    p.add_argument("--output", help="write the full document here; print a one-line summary")
    p.parse_args(argv)
    console.fail("compare_bugreport.py is not implemented until P4")
    return 2


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
