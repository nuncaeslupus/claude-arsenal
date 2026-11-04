#!/usr/bin/env python3
"""Write a redacted copy of an Android bugreport that is safe to share.

Not implemented until P4 of design 0005: this script only declares its flags
so `--help` shows the interface. Running it exits 2.
"""

from __future__ import annotations

import argparse
import sys

import _console as console


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--redact", action="store_true", required=True, help="scrub identifiers")
    p.add_argument("--input", required=True, help="bugreport .txt or .zip")
    p.add_argument("--output", required=True, help="where to write the scrubbed copy")
    p.add_argument("--output-dir", help="cache root for the index (default: the user cache dir)")
    p.add_argument("--force", action="store_true", help="overwrite --output / rebuild the index")
    p.parse_args(argv)
    console.fail("create_bugreport.py is not implemented until P4")
    return 2


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
