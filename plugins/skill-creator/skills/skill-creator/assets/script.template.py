#!/usr/bin/env python3
"""<verb_noun>.py — one-line summary.

Optional: longer paragraph with the script's purpose.

DUPLICATED ACROSS SKILLS (uncomment if this script is duplicated):
- plugins/<plugin>/skills/<owner-skill>/scripts/<verb_noun>.py (canonical)
- plugins/<plugin>/skills/<consumer-skill>/scripts/<verb_noun>.py
Keep all copies in sync. Update via skill-creator's sync_duplicates.py.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="<one-line description>")
    parser.add_argument("--id", required=False, help="entity identifier")
    parser.add_argument("--output", required=False, help="output file")
    parser.add_argument("--json", action="store_true", help="emit JSON to stdout")
    args = parser.parse_args()

    payload = {"id": args.id}
    if args.output:
        Path(args.output).write_text(json.dumps(payload, indent=2), encoding="utf-8")
    else:
        print(json.dumps(payload))
    return 0


if __name__ == "__main__":
    sys.exit(main())
