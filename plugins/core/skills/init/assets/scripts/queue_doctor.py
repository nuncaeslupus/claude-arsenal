#!/usr/bin/env python3
"""queue_doctor.py — consistency checker for the claude-arsenal task queue.

Read-only audit of a queue's ``tasks.jsonl`` and its payload files. Reports
structural, dependency, invariant, PR-field, and secret inconsistencies. With
``--online`` (requires ``gh``) it cross-checks ``done``/``merged`` rows against
real PR merge state — the false-"done" detector. With ``--cross-branch`` it
compares the coordination branch against the default branch for orphaned
payloads (a payload tracked on the default branch with no queue row).

The queue ledger and the payload files live in the same directory:
``claude-arsenal/queue/tasks.jsonl`` and ``claude-arsenal/queue/<id>.md``.

Exit: 0 clean (or only findings below the gate), 1 findings at/above the gate
severity (``--fail-on``, default ``warn``), 2 setup error.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ALL_STATUSES = {"open", "in_progress", "done", "blocked", "escalated", "merged"}
TERMINAL = {"done", "merged"}

# Severity ordering for the --fail-on gate.
SEVERITY_RANK = {"info": 0, "warn": 1, "error": 2}

# Secret patterns scanned in payload files. Each is (label, compiled regex).
# The matched value is redacted in output — the doctor must never re-print a
# secret in full (that would leak it again into logs / CI output).
_SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("AWS access key id", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    (
        "private key block",
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"),
    ),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b")),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b")),
    (
        "credential assignment",
        re.compile(
            r"(?i)\b(?:api[_-]?key|secret|token|password|passwd|access[_-]?key"
            r"|client[_-]?secret|private[_-]?key|bearer)\b\s*[:=]\s*"
            r"['\"]?([A-Za-z0-9/_+.\-]{16,})",
        ),
    ),
]


@dataclass(frozen=True)
class Finding:
    severity: str  # error | warn | info
    code: str
    where: str
    message: str


def _redact(secret: str) -> str:
    """Show only enough to locate the secret, never the whole value."""
    secret = secret.strip()
    if len(secret) <= 8:
        return secret[:2] + "…"
    return f"{secret[:4]}…{secret[-2:]} ({len(secret)} chars)"


def load_rows(queue_path: Path) -> tuple[list[dict], list[Finding]]:
    """Parse tasks.jsonl into row dicts, collecting parse-level findings."""
    rows: list[dict] = []
    findings: list[Finding] = []
    for lineno, raw in enumerate(queue_path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError as exc:
            findings.append(Finding("error", "bad-json", f"line {lineno}", f"invalid JSON: {exc}"))
            continue
        if not isinstance(data, dict):
            findings.append(
                Finding("error", "bad-row", f"line {lineno}", "queue line is not a JSON object")
            )
            continue
        rows.append(data)
    return rows, findings


def check_structure(rows: list[dict]) -> list[Finding]:
    findings: list[Finding] = []
    seen: dict[str, int] = {}
    for row in rows:
        tid = row.get("id")
        if not isinstance(tid, str) or not tid:
            findings.append(
                Finding("error", "missing-id", row.get("id", "?"), "row has no string 'id'")
            )
            continue
        seen[tid] = seen.get(tid, 0) + 1
        status = row.get("status")
        if status not in ALL_STATUSES:
            findings.append(
                Finding(
                    "error", "bad-status", tid, f"status {status!r} not in {sorted(ALL_STATUSES)}"
                )
            )
    for tid, count in seen.items():
        if count > 1:
            findings.append(Finding("error", "duplicate-id", tid, f"id appears {count} times"))
    return findings


def check_deps(rows: list[dict]) -> list[Finding]:
    findings: list[Finding] = []
    ids = {r["id"] for r in rows if isinstance(r.get("id"), str)}
    by_id = {r["id"]: r for r in rows if isinstance(r.get("id"), str)}

    # Build the blocks-edge graph; flag dangling edges along the way.
    graph: dict[str, list[str]] = {}
    for row in rows:
        tid = row.get("id")
        if not isinstance(tid, str):
            continue
        edges: list[str] = []
        for dep in row.get("deps", []) or []:
            if not isinstance(dep, dict) or "id" not in dep:
                findings.append(Finding("error", "bad-dep", tid, f"malformed dep entry: {dep!r}"))
                continue
            dep_id = dep["id"]
            if dep_id not in ids:
                findings.append(
                    Finding("error", "dangling-dep", tid, f"depends on unknown task {dep_id!r}")
                )
                continue
            if dep.get("type", "blocks") == "blocks":
                edges.append(dep_id)
        graph[tid] = edges

    # Permanently-blocked: an open task waiting on a dep that can never satisfy.
    for tid, edges in graph.items():
        if by_id[tid].get("status") != "open":
            continue
        for dep_id in edges:
            if by_id[dep_id].get("status") == "escalated":
                findings.append(
                    Finding(
                        "warn",
                        "blocked-on-escalated",
                        tid,
                        f"open but dep {dep_id} is escalated — will not auto-unblock",
                    )
                )

    # Cycle detection over blocks-edges (DFS with a recursion stack).
    WHITE, GREY, BLACK = 0, 1, 2
    color = dict.fromkeys(graph, WHITE)

    def visit(node: str, trail: list[str]) -> None:
        color[node] = GREY
        for nxt in graph.get(node, []):
            if color.get(nxt) == GREY:
                cycle = (
                    " → ".join([*trail[trail.index(nxt) :], nxt])
                    if nxt in trail
                    else f"{node} → {nxt}"
                )
                findings.append(Finding("error", "dep-cycle", node, f"dependency cycle: {cycle}"))
            elif color.get(nxt) == WHITE:
                visit(nxt, [*trail, nxt])
        color[node] = BLACK

    for node in graph:
        if color[node] == WHITE:
            visit(node, [node])
    return findings


def check_invariants(rows: list[dict]) -> list[Finding]:
    """assignee ↔ in_progress, and attempts/escalation sanity."""
    findings: list[Finding] = []
    for row in rows:
        tid = row.get("id", "?")
        status = row.get("status")
        assignee = row.get("assignee")
        if status == "in_progress" and not assignee:
            findings.append(
                Finding(
                    "warn",
                    "stranded-in-progress",
                    tid,
                    "in_progress with no assignee — crashed/abandoned claim; reset to open",
                )
            )
        if status != "in_progress" and assignee:
            findings.append(
                Finding(
                    "warn",
                    "stale-assignee",
                    tid,
                    f"status {status} but assignee={assignee!r} still set",
                )
            )
    return findings


def check_pr_fields(rows: list[dict]) -> list[Finding]:
    findings: list[Finding] = []
    for row in rows:
        tid = row.get("id", "?")
        status = row.get("status")
        pr = row.get("pr")
        if status in TERMINAL:
            if not pr:
                findings.append(
                    Finding(
                        "warn",
                        "terminal-without-pr",
                        tid,
                        f"{status} but no 'pr' field — completion cannot be verified",
                    )
                )
            elif isinstance(pr, str) and pr.startswith("branch:"):
                findings.append(
                    Finding(
                        "error",
                        "done-from-branch",
                        tid,
                        f"{status} recorded from a branch ref ({pr}) that was never PR'd/merged",
                    )
                )
        elif pr and status not in ("in_progress",):
            findings.append(
                Finding("warn", "stale-pr", tid, f"status {status} but carries a 'pr' field ({pr})")
            )
    return findings


def check_payloads(rows: list[dict], queue_dir: Path) -> list[Finding]:
    """Each row.payload must exist; each <id>.md must map to a row (CA-14)."""
    findings: list[Finding] = []
    referenced: set[str] = set()
    for row in rows:
        tid = row.get("id", "?")
        payload = row.get("payload")
        if not payload:
            continue
        referenced.add(payload)
        if not (queue_dir / payload).is_file():
            findings.append(
                Finding("error", "missing-payload", tid, f"payload {payload} referenced but absent")
            )
    row_ids = {r["id"] for r in rows if isinstance(r.get("id"), str)}
    for md in sorted(queue_dir.glob("*.md")):
        if md.name in referenced or md.stem in row_ids:
            continue
        findings.append(
            Finding(
                "warn", "orphan-payload", md.name, "payload file has no matching queue row (orphan)"
            )
        )
    return findings


def scan_secrets(rows: list[dict], queue_dir: Path) -> list[Finding]:
    findings: list[Finding] = []
    files = sorted(queue_dir.glob("*.md"))
    for md in files:
        text = md.read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(text.splitlines(), 1):
            for label, pattern in _SECRET_PATTERNS:
                m = pattern.search(line)
                if not m:
                    continue
                value = m.group(m.lastindex or 0)
                findings.append(
                    Finding(
                        "error",
                        "secret-in-payload",
                        f"{md.name}:{lineno}",
                        f"possible {label}: {_redact(value)}",
                    )
                )
                break  # one finding per line is enough to flag it
    return findings


def _git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True, check=False
    )


def check_cross_branch(
    rows: list[dict], queue_dir: Path, remote: str, default_branch: str
) -> list[Finding]:
    """Flag payloads tracked on the default branch with no coordination-branch row (CA-14)."""
    findings: list[Finding] = []
    top = _git(queue_dir, "rev-parse", "--show-toplevel")
    if top.returncode != 0:
        return findings  # not a git repo — nothing to compare
    ref = f"{remote}/{default_branch}"
    listing = _git(queue_dir, "ls-tree", "-r", "--name-only", ref, "claude-arsenal/queue/")
    if listing.returncode != 0:
        return findings  # default branch not fetched / no such ref — skip silently
    row_ids = {r["id"] for r in rows if isinstance(r.get("id"), str)}
    for path in listing.stdout.splitlines():
        name = Path(path).name
        if not name.endswith(".md"):
            continue
        if Path(name).stem not in row_ids:
            findings.append(
                Finding(
                    "warn",
                    "orphan-on-default",
                    name,
                    f"payload tracked on {ref} has no row on the coordination branch",
                )
            )
    return findings


def check_online(rows: list[dict]) -> list[Finding]:
    """Cross-check done/merged rows against real PR state via gh (false-'done')."""
    findings: list[Finding] = []
    for row in rows:
        tid = row.get("id", "?")
        status = row.get("status")
        pr = row.get("pr")
        if status not in TERMINAL or not isinstance(pr, str) or not pr.startswith("http"):
            continue
        proc = subprocess.run(
            ["gh", "pr", "view", pr, "--json", "state,mergedAt"],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            findings.append(
                Finding("warn", "pr-unresolvable", tid, f"cannot resolve PR {pr} via gh")
            )
            continue
        try:
            info = json.loads(proc.stdout)
        except json.JSONDecodeError:
            continue
        state = info.get("state")
        merged = bool(info.get("mergedAt"))
        if status == "merged" and not merged:
            findings.append(
                Finding(
                    "error",
                    "merged-not-merged",
                    tid,
                    f"status=merged but PR {pr} is {state} (mergedAt is null)",
                )
            )
        elif status == "done" and state == "CLOSED" and not merged:
            findings.append(
                Finding(
                    "error",
                    "done-pr-closed",
                    tid,
                    f"status=done but PR {pr} is CLOSED and was never merged",
                )
            )
    return findings


def _print_human(findings: list[Finding], queue_path: Path, total: int, fail_on: str) -> None:
    counts = {"error": 0, "warn": 0, "info": 0}
    order = {"error": 0, "warn": 1, "info": 2}
    print(f"queue-doctor: {queue_path} — {total} task(s), {len(findings)} finding(s)")
    for f in sorted(findings, key=lambda x: (order[x.severity], x.code)):
        counts[f.severity] += 1
        print(f"  {f.severity.upper():5s} [{f.code}] {f.where}: {f.message}")
    gate = (
        "FAIL"
        if any(SEVERITY_RANK[f.severity] >= SEVERITY_RANK[fail_on] for f in findings)
        else "OK"
    )
    print(
        f"queue-doctor: {counts['error']} error, {counts['warn']} warn, "
        f"{counts['info']} info — {gate} (fail-on={fail_on})"
    )


def main() -> None:
    p = argparse.ArgumentParser(description="Audit the task queue for inconsistencies.")
    p.add_argument(
        "--queue", default="claude-arsenal/queue/tasks.jsonl", help="Path to tasks.jsonl"
    )
    p.add_argument("--online", action="store_true", help="Cross-check PR state via gh (false-done)")
    p.add_argument(
        "--cross-branch", action="store_true", help="Compare payloads vs the default branch"
    )
    p.add_argument("--no-secret-scan", action="store_true", help="Skip the payload secret scan")
    p.add_argument("--remote", default="origin", help="Remote for --cross-branch (default origin)")
    p.add_argument("--default-branch", default="main", help="Default branch for --cross-branch")
    p.add_argument(
        "--fail-on",
        choices=["info", "warn", "error"],
        default="warn",
        help="Minimum severity that makes the exit code non-zero (default warn)",
    )
    p.add_argument("--json", action="store_true", help="Emit findings as JSON")
    args = p.parse_args()

    queue_path = Path(args.queue)
    if not queue_path.is_file():
        sys.exit(f"queue-doctor: queue file not found: {queue_path}")
    queue_dir = queue_path.parent

    rows, findings = load_rows(queue_path)
    findings += check_structure(rows)
    findings += check_deps(rows)
    findings += check_invariants(rows)
    findings += check_pr_fields(rows)
    findings += check_payloads(rows, queue_dir)
    if not args.no_secret_scan:
        findings += scan_secrets(rows, queue_dir)
    if args.cross_branch:
        findings += check_cross_branch(rows, queue_dir, args.remote, args.default_branch)
    if args.online:
        findings += check_online(rows)

    if args.json:
        print(
            json.dumps(
                {
                    "queue": str(queue_path),
                    "total": len(rows),
                    "findings": [f.__dict__ for f in findings],
                },
                indent=2,
            )
        )
    else:
        _print_human(findings, queue_path, len(rows), args.fail_on)

    gate = SEVERITY_RANK[args.fail_on]
    sys.exit(1 if any(SEVERITY_RANK[f.severity] >= gate for f in findings) else 0)


if __name__ == "__main__":
    main()
