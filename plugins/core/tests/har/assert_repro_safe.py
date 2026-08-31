#!/usr/bin/env python3
"""Assert a generated reproduction carries the capture's values and nothing else.

Reads the generated command on stdin and parses it the way a shell would.

This lives in a file rather than inline in `har_test.sh` for the reason the
command under test exists: writing the assertion inline meant interpolating
`'; rm -rf / #` — the fixture's own adversarial header — into a shell script,
where it did exactly what it says. GNU `rm` refused and nothing was lost, but
the lesson is the one being tested: adversarial text belongs in data, never in
a command that gets assembled by string substitution.

Exit: 0 when the reproduction is faithful, 1 with a message when it is not.
"""

from __future__ import annotations

import shlex
import sys

EXPECTED_HEADER = "x-note: '; rm -rf / #"
EXPECTED_BODY = "@/etc/passwd"


def main() -> int:
    text = sys.stdin.read()
    command = "\n".join(
        line for line in text.splitlines() if line and not line.lstrip().startswith("#")
    ).replace("\\\n", " ")
    try:
        argv = shlex.split(command)
    except ValueError as exc:
        print(f"the generated command does not parse as a shell command: {exc}", file=sys.stderr)
        return 1

    if not argv or argv[0] != "curl":
        print(f"expected a curl command, got {argv[:1]}", file=sys.stderr)
        return 1

    notes = [token for token in argv if token.startswith("x-note")]
    if notes != [EXPECTED_HEADER]:
        print(
            f"the adversarial header did not survive quoting intact: {notes!r}",
            file=sys.stderr,
        )
        return 1

    if "--data-raw" not in argv:
        print("no --data-raw in the generated command", file=sys.stderr)
        return 1
    body = argv[argv.index("--data-raw") + 1]
    if body != EXPECTED_BODY:
        print(f"the body was altered: {body!r}", file=sys.stderr)
        return 1

    # Nothing outside the header value may look like a shell operator: if one
    # escaped, `shlex` would have split the command there and the tokens after
    # it would be a second command rather than curl's arguments.
    for token in argv:
        if token in {";", "&&", "||", "|", "&"}:
            print(f"a shell operator escaped into the command: {token!r}", file=sys.stderr)
            return 1
    print("reproduction is faithful: adversarial header and body stayed data")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
