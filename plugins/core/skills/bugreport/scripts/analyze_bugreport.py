#!/usr/bin/env python3
"""Run the detector checkup over an Android bugreport and rank what it finds.

Not implemented until P2 of design 0005: this script only declares its flags
so `--help` shows the interface. Running it exits 2.
"""

from __future__ import annotations

import argparse
import sys

import _console as console


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--input", required=True, help="bugreport .txt or .zip")
    p.add_argument("--family", help="comma-separated families: slugs or F-numbers (default all)")
    p.add_argument("--severity", help="minimum severity to report")
    p.add_argument("--advice", action="store_true", help="print the advice entry per finding")
    p.add_argument("--limit", type=int, help="max findings (0 = no caps)")
    p.add_argument("--output", help="write the full document here; print a one-line summary")
    p.add_argument("--output-dir", help="cache root for the index (default: the user cache dir)")
    p.add_argument("--force", action="store_true", help="rebuild the index")
    p.add_argument("--no-redact", action="store_true", help="print identifiers unmasked")
    p.add_argument("--json", action="store_true", help="JSON only: no progress on stderr")
    p.parse_args(argv)
    console.fail("analyze_bugreport.py is not implemented until P2")
    return 2


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
