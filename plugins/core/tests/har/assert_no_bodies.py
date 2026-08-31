#!/usr/bin/env python3
"""Assert a derived HAR carries no request or response body text.

SC5 counts secrets in the bounded fields, so it passes on a file whose headers
are all redacted and whose response body still holds a session token. Body
removal is therefore its own check rather than a corollary of that one.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    doc = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    for i, entry in enumerate(doc["log"]["entries"]):
        if "text" in (entry.get("response", {}).get("content") or {}):
            print(f"entry {i}: a response body survived the default", file=sys.stderr)
            return 1
        if "text" in (entry.get("request", {}).get("postData") or {}):
            print(f"entry {i}: a request body survived the default", file=sys.stderr)
            return 1
    print(f"no bodies in {len(doc['log']['entries'])} derived entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
