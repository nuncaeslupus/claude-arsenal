#!/usr/bin/env python3
"""apply_decisions.py — act on the decisions a human made from the review digest.

Input is the file the digest page exports (its `<!-- ARSENAL-DECISIONS {...} -->`
block), or the same thing typed in chat, one decision per line:

    approve 42
    deny 43: too big, split it
    question 44: why a new dependency?

A typed decision is bound to the head the last digest showed
(`arsenal/session/digest.json`), so "approve 42" means "approve what I saw".

What each decision does:
    approve   PR head still the one decided on → a decision marker on the PR
              (counted as a human approval under [review] digest-decisions), then
              a merge through merge_ready.sh once its deps are merged or approved.
              A merged human-after PR is ratified instead. A head that moved since
              the digest is `stale`: nothing happens, and the next digest shows it.
    deny      an open PR is closed with the note; a merged one gets a revert PR.
    question  posted on the PR and kept in its record; the next worker answers.
Merges run in dependency order (`deps` in each PR's digest record); a PR whose dep
was denied, or is neither merged nor approved, is reported and left open.

Usage:
    apply_decisions.py FILE | --text "approve 42; deny 43: why" [--dry-run]
                       [--prs-json FILE] [--method squash|merge|rebase]
Exit: 0 done, 1 something was stale or blocked (the plan says what), 2 bad input,
      5 no scriptable GitHub channel (the plan and the calls to make are printed).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

import digest

BIN = Path(__file__).resolve().parent.parent / "bin"
DECISIONS_RX = re.compile(r"<!--\s*ARSENAL-DECISIONS\s*(\{.*?\})\s*-->", re.DOTALL)
LINE_RX = re.compile(r"^\s*(approve|deny|question)\s+#?(\d+)\s*(?::\s*(.*))?$", re.IGNORECASE)
KINDS = ("approve", "deny", "question")


class ApplyError(Exception):
    pass


def parse(text: str, heads: dict[str, str]) -> dict[int, dict[str, str]]:
    """{pr: {decision, head, note}} from an export block or typed lines."""
    m = DECISIONS_RX.search(text)
    out: dict[int, dict[str, str]] = {}
    if m:
        try:
            raw = json.loads(m.group(1))
        except ValueError as exc:
            raise ApplyError(f"the ARSENAL-DECISIONS block is not valid JSON — {exc}") from exc
        for pr, d in raw.items():
            if not isinstance(d, dict) or d.get("decision") not in KINDS:
                raise ApplyError(f"#{pr}: decision must be one of {', '.join(KINDS)}")
            out[int(pr)] = {
                "decision": d["decision"],
                "head": str(d.get("head", "")),
                "note": str(d.get("note", "")),
            }
        return out
    for line in re.split(r"[;\n]", text):
        if not line.strip():
            continue
        lm = LINE_RX.match(line)
        if not lm:
            raise ApplyError(f"cannot read {line.strip()!r} — use 'approve 42', 'deny 43: why'")
        pr = int(lm.group(2))
        out[pr] = {
            "decision": lm.group(1).lower(),
            "head": heads.get(str(pr), ""),
            "note": (lm.group(3) or "").strip(),
        }
    return out


def _deps_order(prs: list[int], deps: dict[int, list[int]]) -> list[int]:
    """`prs` with every dep before its dependent (deps outside `prs` ignored)."""
    done: list[int] = []
    seen: set[int] = set()

    def visit(n: int, path: tuple[int, ...]) -> None:
        if n in seen or n in path:
            return
        for d in deps.get(n, []):
            if d in prs:
                visit(d, (*path, n))
        seen.add(n)
        done.append(n)

    for n in sorted(prs):
        visit(n, ())
    return done


def plan(decisions: dict[int, dict[str, str]], prs: dict[int, dict[str, Any]]) -> list[tuple]:
    """The actions to take, in order. Pure: everything it needs is passed in."""
    acts: list[tuple] = []
    approved: list[int] = []
    deps: dict[int, list[int]] = {}
    for n, d in sorted(decisions.items()):
        pr = prs.get(n)
        if pr is None:
            acts.append(("missing", n, "no such PR"))
            continue
        rec = digest.read_block(pr.get("body")) or {}
        deps[n] = [int(x) for x in rec.get("deps", [])]
        head = str((pr.get("head") or {}).get("sha") or "")
        merged = bool(pr.get("merged") or pr.get("merged_at"))
        if d["decision"] == "approve":
            if not d["head"] or not head.startswith(d["head"][:7]):
                acts.append(("stale", n, f"decided on {d['head'][:7] or '?'}, head is {head[:7]}"))
            elif merged:
                acts.append(("ratify", n, ""))
            elif pr.get("state") == "open":
                acts.append(("mark", n, head))
                approved.append(n)
        elif d["decision"] == "deny":
            acts.append(("revert" if merged else "close", n, d["note"]))
        else:
            acts.append(("ask", n, d["note"]))
    denied = {n for n, d in decisions.items() if d["decision"] == "deny"}
    for n in _deps_order(approved, deps):
        blocker = next(
            (
                d
                for d in deps.get(n, [])
                if d in denied
                or not (
                    (prs.get(d) or {}).get("merged")
                    or (prs.get(d) or {}).get("merged_at")
                    or d in approved
                )
            ),
            None,
        )
        if blocker is None:
            acts.append(("merge", n, ""))
        else:
            acts.append(("blocked", n, f"waits on #{blocker}"))
    return acts


# --- execution -------------------------------------------------------------------
def _api(method: str, path: str, body: dict[str, Any] | None = None) -> Any:
    return digest._api(method, path, body)


def _merge(slug: str, n: int, head: str, method: str) -> str:
    res = subprocess.run(
        ["bash", str(BIN / "merge_ready.sh"), str(n), "--body"],
        capture_output=True,
        text=True,
        check=False,
    )
    if res.returncode != 0:
        return f"not merged — merge_ready.sh exit {res.returncode}"
    body = res.stdout.split("--- merge commit body ---", 1)[-1].strip()
    _api(
        "PUT",
        f"/repos/{slug}/pulls/{n}/merge",
        {"merge_method": method, "sha": head, "commit_message": body},
    )
    return "merged"


def _revert(slug: str, n: int, pr: dict[str, Any], note: str) -> str:
    """Open a revert PR in a throwaway worktree, so the user's checkout is untouched."""
    sha = pr.get("merge_commit_sha")
    base = (pr.get("base") or {}).get("ref") or "main"
    if not sha:
        return "no merge commit to revert"
    branch = f"revert-pr-{n}"
    with tempfile.TemporaryDirectory() as wt:
        steps = [
            ["git", "fetch", "-q", "origin", base],
            ["git", "worktree", "add", "-q", "-b", branch, wt, f"origin/{base}"],
            ["git", "-C", wt, "revert", "--no-edit", sha],
            ["git", "-C", wt, "push", "-q", "-u", "origin", branch],
        ]
        for cmd in steps:
            if subprocess.run(cmd, capture_output=True, check=False).returncode != 0:
                subprocess.run(["git", "worktree", "remove", "--force", wt], capture_output=True)
                return (
                    f"revert PR not opened — `{' '.join(cmd[:4])}` failed; revert {sha[:7]} by hand"
                )
        subprocess.run(["git", "worktree", "remove", "--force", wt], capture_output=True)
    made = _api(
        "POST",
        f"/repos/{slug}/pulls",
        {
            "title": f"Revert #{n}: {pr.get('title', '')}",
            "head": branch,
            "base": base,
            "body": f"Denied in the review digest: {note or '(no note)'}\n\nReverts #{n}.",
        },
    )
    return f"revert PR #{(made or {}).get('number', '?')} opened"


def _patch_record(slug: str, n: int, pr: dict[str, Any], change: dict[str, Any]) -> None:
    rec = digest.read_block(pr.get("body"))
    if rec is not None:
        _api(
            "PATCH",
            f"/repos/{slug}/pulls/{n}",
            {"body": digest.write_block(pr.get("body"), rec | change)},
        )


def execute(acts: list[tuple], prs: dict[int, dict[str, Any]], slug: str, method: str) -> list[str]:
    out = []
    for kind, n, info in acts:
        pr = prs.get(n, {})
        if kind == "mark":
            _api(
                "POST",
                f"/repos/{slug}/issues/{n}/comments",
                {
                    "body": f"<!-- arsenal-decision: approve head={info} via=digest -->\n"
                    "Approved in the review digest."
                },
            )
            out.append(f"#{n} approved on {info[:7]}")
        elif kind == "ratify":
            _patch_record(slug, n, pr, {"ratified": True, "state": "merged"})
            out.append(f"#{n} ratified")
        elif kind == "close":
            _api(
                "POST",
                f"/repos/{slug}/issues/{n}/comments",
                {"body": f"Denied in the review digest: {info or '(no note)'}"},
            )
            _api("PATCH", f"/repos/{slug}/pulls/{n}", {"state": "closed"})
            out.append(f"#{n} closed")
        elif kind == "revert":
            out.append(f"#{n} {_revert(slug, n, pr, info)}")
        elif kind == "ask":
            _api(
                "POST",
                f"/repos/{slug}/issues/{n}/comments",
                {"body": f"Question from the review digest: {info}"},
            )
            rec = digest.read_block(pr.get("body")) or {}
            _patch_record(slug, n, pr, {"questions": [*rec.get("questions", []), info]})
            out.append(f"#{n} question posted")
        elif kind == "merge":
            head = str((pr.get("head") or {}).get("sha") or "")
            out.append(f"#{n} {_merge(slug, n, head, method)}")
        else:
            out.append(f"#{n} {kind}: {info}")
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n", 1)[0])
    ap.add_argument("file", nargs="?", help="the digest's exported decisions file")
    ap.add_argument("--text", help='typed decisions, e.g. "approve 42; deny 43: why"')
    ap.add_argument("--dry-run", action="store_true", help="print the plan, change nothing")
    ap.add_argument("--prs-json", help="list of PR objects, instead of fetching them")
    ap.add_argument("--method", default="squash", choices=("squash", "merge", "rebase"))
    args = ap.parse_args(argv)
    try:
        if bool(args.file) == bool(args.text):
            raise ApplyError("give a decisions file or --text, not both")
        text = args.text or Path(args.file).read_text(encoding="utf-8")
        try:
            heads = json.loads(digest.STATE_FILE.read_text(encoding="utf-8")).get("heads", {})
        except (OSError, ValueError):
            heads = {}
        decisions = parse(text, heads)
        if args.prs_json:
            prs = {int(p["number"]): p for p in digest._load_json(args.prs_json)}
            slug = ""
        else:
            slug = digest._slug()
            prs = {n: _api("GET", f"/repos/{slug}/pulls/{n}") for n in decisions}
        acts = plan(decisions, prs)
        for kind, n, info in acts:
            print(f"plan: #{n} {kind}" + (f" — {info}" if info and kind != "mark" else ""))
        if args.dry_run or not slug:
            if not slug and not args.dry_run:
                print("apply_decisions: no channel — make these changes with your GitHub tools")
                return 5
        else:
            for line in execute(acts, prs, slug, args.method):
                print(line)
        return 1 if any(k in ("stale", "blocked", "missing") for k, _, _ in acts) else 0
    except digest.NoChannel as exc:
        print(
            f"apply_decisions: no scriptable GitHub channel — {exc}; rerun with --prs-json",
            file=sys.stderr,
        )
        return 5
    except (ApplyError, digest.DigestError, OSError) as exc:
        print(f"apply_decisions: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
