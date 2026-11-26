#!/usr/bin/env python3
"""audit_public_repo.py — a public GitHub repo, safe for strangers and ready to share.

A repo that nobody visits needs none of this; a repo somebody links to does.
Strangers can only open issues and pull requests, and a pull request is a
proposal, but three things still go wrong in practice: a workflow that runs a
fork's code with a write token or your secrets, a release tag that can be moved
or deleted, and a leaked secret or vulnerable dependency nobody is told about.

Three subcommands:

  audit     read-only. One line per check: PASS, GAP (with the fix) or NOTE.
  fix       applies the settings `audit` reports as gaps. Never touches files.
            Skips a public-only setting on a private repo, and skips the
            read-only token default when a workflow relies on write access
            without declaring `permissions:` (switching it would break that
            workflow).
  scaffold  writes the community files that are missing — SECURITY.md,
            CONTRIBUTING.md, issue templates — into a local clone. Never
            overwrites. `--contributions issues` (default) says pull requests
            are not accepted for now; `pull-requests` invites them.

Description, topics, homepage, licence and the release for the newest tag are
`repo_health.py`'s job (the bundle ships it); this does not repeat them.

Exit: 0 ok (audit: also with gaps unless --fail-on-gaps), 1 gaps with
--fail-on-gaps or a failed fix, 2 usage error or no `gh`.

Usage:
    audit_public_repo.py audit --repo OWNER/REPO [--repo ...] [--json] [--fail-on-gaps]
    audit_public_repo.py fix --repo OWNER/REPO [--repo ...] [--dry-run]
    audit_public_repo.py scaffold --repo OWNER/REPO --repo-root PATH
        [--contributions issues|pull-requests]
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

ASSETS = Path(__file__).resolve().parent.parent / "assets"

BRANCH_RULESET = "public-ready: default branch"
TAG_RULESET = "public-ready: release tags"
TAG_PATTERN = "refs/tags/v*"

# The checkout of a pull request's own code, as opposed to the base branch.
_PR_HEAD_REF = re.compile(r"ref:\s*\$\{\{\s*github\.event\.(pull_request\.head|workflow_run\.head)")
_COMMENT_TRIGGER = re.compile(
    r"^\s*(issue_comment|pull_request_review_comment|discussion_comment):", re.M
)
# A job condition that only lets the repo's own branches through, not a fork's.
_SAME_REPO_GUARD = re.compile(r"head(_repository|\.repo)\.full_name\s*==\s*github\.repository")
_SECRET_USE = re.compile(r"secrets\.(?!GITHUB_TOKEN\b)[A-Za-z_]+")
_UNPINNED = re.compile(r"uses:\s*[\w.-]+/[\w./-]+@(?![0-9a-f]{40}\b)\S+")
_PERMISSIONS = re.compile(r"^\s*permissions:", re.M)


class GhError(Exception):
    def __init__(self, message: str, status: int | None) -> None:
        super().__init__(message)
        self.status = status


def gh(
    path: str, method: str = "GET", body: dict[str, Any] | None = None, extra: tuple[str, ...] = ()
) -> Any:
    """`gh api`; parsed JSON, None for an empty (204) reply. Raises GhError."""
    cmd = ["gh", "api"]
    if method != "GET":
        cmd += ["-X", method]
    cmd += [path, *extra]
    if body is not None:
        cmd += ["--input", "-"]
    try:
        # No body: stdin is closed, so a call never waits on the caller's terminal.
        stdin = {"input": json.dumps(body)} if body is not None else {"stdin": subprocess.DEVNULL}
        proc = subprocess.run(
            cmd,
            **stdin,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise GhError(str(exc), None) from exc
    if proc.returncode != 0:
        text = f"{proc.stderr} {proc.stdout}"
        match = re.search(r"HTTP (\d{3})", text)
        first = (proc.stderr or proc.stdout or "gh api failed").strip().splitlines()
        raise GhError(
            first[0] if first else "gh api failed", int(match.group(1)) if match else None
        )
    out = proc.stdout.strip()
    return json.loads(out) if out else None


def _try(path: str) -> Any:
    """GET that maps 404 to None; other errors propagate."""
    try:
        return gh(path)
    except GhError as exc:
        if exc.status == 404:
            return None
        raise


# --- the checks -------------------------------------------------------------


def _workflows(slug: str) -> dict[str, str]:
    """Workflow file name -> text, {} when the repo has none."""
    listing = _try(f"repos/{slug}/contents/.github/workflows") or []
    files: dict[str, str] = {}
    for entry in listing:
        name = entry.get("name", "")
        if not name.endswith((".yml", ".yaml")):
            continue
        blob = _try(f"repos/{slug}/contents/.github/workflows/{name}") or {}
        files[name] = base64.b64decode(blob.get("content", "")).decode("utf-8", "replace")
    return files


def _undeclared_permissions(workflows: dict[str, str]) -> list[str]:
    """Workflows with no `permissions:` key, which inherit the repo default."""
    return sorted(name for name, text in workflows.items() if not _PERMISSIONS.search(text))


def _rulesets(slug: str) -> list[dict[str, Any]]:
    out = []
    for summary in _try(f"repos/{slug}/rulesets") or []:
        full = _try(f"repos/{slug}/rulesets/{summary['id']}")
        if full and full.get("enforcement") == "active":
            out.append(full)
    return out


def _has_rules(rulesets: list[dict[str, Any]], target: str, needed: set[str]) -> bool:
    for rs in rulesets:
        if rs.get("target") != target:
            continue
        if needed <= {rule.get("type") for rule in rs.get("rules", [])}:
            return True
    return False


def _classic_ok(slug: str, branch: str) -> bool:
    """Classic branch protection that already forbids force-push and deletion."""
    protection = _try(f"repos/{slug}/branches/{branch}/protection") or {}
    return (
        bool(protection)
        and not (protection.get("allow_force_pushes") or {}).get("enabled")
        and not (protection.get("allow_deletions") or {}).get("enabled")
    )


def audit(slug: str) -> list[tuple[str, str, str]]:
    """(level, check, detail) for every check. Raises GhError if the repo is unreadable."""
    repo = gh(f"repos/{slug}")
    findings: list[tuple[str, str, str]] = []

    def add(ok: bool, check: str, gap: str, level: str = "GAP") -> None:
        findings.append(("PASS", check, "") if ok else (level, check, gap))

    if repo.get("private"):
        return [("NOTE", "visibility", "private: nothing here applies until it is public")]

    branch = repo.get("default_branch", "main")
    sa = repo.get("security_and_analysis") or {}

    def sa_on(key: str) -> bool:
        return (sa.get(key) or {}).get("status") == "enabled"

    add(sa_on("secret_scanning"), "secret scanning", "off — leaked keys go unreported → `fix`")
    add(
        sa_on("secret_scanning_push_protection"),
        "push protection",
        "off — a push containing a key is accepted → `fix`",
    )
    try:
        gh(f"repos/{slug}/vulnerability-alerts")
        alerts = True
    except GhError as exc:
        if exc.status != 404:
            raise
        alerts = False
    add(alerts, "dependabot alerts", "off — vulnerable dependencies go unreported → `fix`")
    add(sa_on("dependabot_security_updates"), "dependabot security updates", "off → `fix`")
    pvr = _try(f"repos/{slug}/private-vulnerability-reporting") or {}
    add(
        bool(pvr.get("enabled")),
        "private vulnerability reporting",
        "off — a reporter's only channel is a public issue → `fix`",
    )

    workflows = _workflows(slug)
    perms = _try(f"repos/{slug}/actions/permissions/workflow") or {}
    add(
        perms.get("default_workflow_permissions") == "read",
        "actions token default",
        "write — every workflow gets a write token unless it says otherwise → `fix`",
    )
    add(
        not perms.get("can_approve_pull_request_reviews"),
        "actions can approve PRs",
        "on — a workflow can approve a pull request → `fix`",
    )
    approval = _try(f"repos/{slug}/actions/permissions/fork-pr-contributor-approval")
    if approval is None:
        findings.append(
            (
                "NOTE",
                "fork PR approval",
                "not readable here; set Settings → Actions → "
                "'Require approval for all external contributors'",
            )
        )
    else:
        add(
            approval.get("approval_policy") == "all_external_contributors",
            "fork PR approval",
            f"{approval.get('approval_policy')} — a stranger's workflow runs unapproved → `fix`",
        )

    rulesets = _rulesets(slug)
    add(
        _classic_ok(slug, branch)
        or _has_rules(rulesets, "branch", {"deletion", "non_fast_forward"}),
        f"`{branch}` force-push/delete",
        "allowed — history can be rewritten → `fix`",
    )
    add(
        _has_rules(rulesets, "tag", {"deletion", "update"}),
        "release tags protected",
        f"no ruleset on {TAG_PATTERN} — a published tag can be moved or deleted → `fix`",
    )

    for name, text in sorted(workflows.items()):
        if re.search(
            r"^\s*(pull_request_target|workflow_run):", text, re.M
        ) and _PR_HEAD_REF.search(text):
            if _SAME_REPO_GUARD.search(text):
                findings.append(
                    (
                        "NOTE",
                        f"workflow {name}",
                        "checks out a head ref with a write token, guarded to this repo's "
                        "own branches; confirm the guard covers every job that checks out",
                    )
                )
            else:
                findings.append(
                    (
                        "GAP",
                        f"workflow {name}",
                        "checks out a pull request's code on a trigger that holds a write "
                        "token and secrets; check out the base ref instead",
                    )
                )
        if (
            _COMMENT_TRIGGER.search(text)
            and _SECRET_USE.search(text)
            and "author_association" not in text
        ):
            findings.append(
                (
                    "NOTE",
                    f"workflow {name}",
                    "comment-triggered and uses secrets; confirm a stranger's comment cannot "
                    "start it (gate on author_association)",
                )
            )
        unpinned = len(_UNPINNED.findall(text))
        if unpinned:
            findings.append(
                (
                    "NOTE",
                    f"workflow {name}",
                    f"{unpinned} action(s) pinned to a tag, not a commit SHA",
                )
            )
    undeclared = _undeclared_permissions(workflows)
    if undeclared:
        findings.append(
            (
                "NOTE",
                "workflow permissions",
                f"no `permissions:` in {', '.join(undeclared)}; `fix` leaves the token "
                "default alone until they declare it",
            )
        )

    community = _try(f"repos/{slug}/community/profile") or {}
    files = community.get("files") or {}
    security = any(
        _try(f"repos/{slug}/contents/{p}") for p in ("SECURITY.md", ".github/SECURITY.md")
    )
    add(security, "SECURITY.md", "missing — say how to report privately → `scaffold`")
    add(
        bool(files.get("contributing")),
        "CONTRIBUTING.md",
        "missing — say whether pull requests are welcome → `scaffold`",
    )
    add(
        bool(files.get("issue_template") or _try(f"repos/{slug}/contents/.github/ISSUE_TEMPLATE")),
        "issue templates",
        "missing → `scaffold`",
    )

    try:
        owner, name = slug.split("/", 1)
        query = f'query{{repository(owner:"{owner}",name:"{name}"){{usesCustomOpenGraphImage}}}}'
        data = gh("graphql", extra=("-f", f"query={query}"))
        custom = bool(
            ((data or {}).get("data") or {}).get("repository", {}).get("usesCustomOpenGraphImage")
        )
    except GhError:
        custom = None
    if custom is not None:
        add(
            custom,
            "social preview",
            "GitHub's generic card — a shared link shows no picture. "
            "fix: Settings → General → Social preview (no API)",
        )
    if repo.get("has_wiki"):
        findings.append(
            ("NOTE", "wiki", "enabled; turn it off if unused (anyone with access can edit it)")
        )
    return findings


# --- fix --------------------------------------------------------------------


def fix(slug: str, dry_run: bool) -> list[tuple[str, str]]:
    """(outcome, what) per setting: applied | would apply | skipped | failed."""
    repo = gh(f"repos/{slug}")
    if repo.get("private"):
        return [("skipped", "private repository")]
    workflows = _workflows(slug)
    undeclared = _undeclared_permissions(workflows)
    rulesets = _rulesets(slug)
    plan: list[tuple[str, str, str, dict[str, Any] | None]] = [
        (
            "secret scanning + push protection",
            "PATCH",
            f"repos/{slug}",
            {
                "security_and_analysis": {
                    "secret_scanning": {"status": "enabled"},
                    "secret_scanning_push_protection": {"status": "enabled"},
                }
            },
        ),
        ("dependabot alerts", "PUT", f"repos/{slug}/vulnerability-alerts", None),
        ("dependabot security updates", "PUT", f"repos/{slug}/automated-security-fixes", None),
        (
            "private vulnerability reporting",
            "PUT",
            f"repos/{slug}/private-vulnerability-reporting",
            None,
        ),
        (
            "fork PR approval: all external contributors",
            "PUT",
            f"repos/{slug}/actions/permissions/fork-pr-contributor-approval",
            {"approval_policy": "all_external_contributors"},
        ),
    ]
    results: list[tuple[str, str]] = []
    if undeclared:
        results.append(
            (
                "skipped",
                f"actions token default → read: {', '.join(undeclared)} declare no permissions",
            )
        )
    else:
        plan.append(
            (
                "actions token default → read, no PR approvals",
                "PUT",
                f"repos/{slug}/actions/permissions/workflow",
                {"default_workflow_permissions": "read", "can_approve_pull_request_reviews": False},
            )
        )
    branch = repo.get("default_branch", "main")
    if not (
        _classic_ok(slug, branch)
        or _has_rules(rulesets, "branch", {"deletion", "non_fast_forward"})
    ):
        plan.append(
            (
                f"ruleset '{BRANCH_RULESET}'",
                "POST",
                f"repos/{slug}/rulesets",
                {
                    "name": BRANCH_RULESET,
                    "target": "branch",
                    "enforcement": "active",
                    "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
                    "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}],
                },
            )
        )
    if not _has_rules(rulesets, "tag", {"deletion", "update"}):
        plan.append(
            (
                f"ruleset '{TAG_RULESET}'",
                "POST",
                f"repos/{slug}/rulesets",
                {
                    "name": TAG_RULESET,
                    "target": "tag",
                    "enforcement": "active",
                    "conditions": {"ref_name": {"include": [TAG_PATTERN], "exclude": []}},
                    "rules": [{"type": "deletion"}, {"type": "update"}],
                },
            )
        )
    for what, method, path, body in plan:
        if dry_run:
            results.append(("would apply", f"{what}  ({method} {path})"))
            continue
        try:
            gh(path, method, body)
            results.append(("applied", what))
        except GhError as exc:
            results.append(("failed", f"{what}: {exc}"))
    return results


# --- scaffold ---------------------------------------------------------------


def scaffold(slug: str, root: Path, contributions: str) -> list[tuple[str, str]]:
    """Write each missing community file from assets/; never overwrite."""
    targets = {
        "SECURITY.md": "SECURITY.md",
        f"CONTRIBUTING-{contributions}.md": "CONTRIBUTING.md",
        "ISSUE_TEMPLATE/bug_report.yml": ".github/ISSUE_TEMPLATE/bug_report.yml",
        "ISSUE_TEMPLATE/feature_request.yml": ".github/ISSUE_TEMPLATE/feature_request.yml",
        "ISSUE_TEMPLATE/config.yml": ".github/ISSUE_TEMPLATE/config.yml",
    }
    results = []
    for src, dest in targets.items():
        path = root / dest
        # GitHub reads SECURITY.md and CONTRIBUTING.md from the root, docs/ or .github/.
        found = [root / d / dest for d in ("", "docs", ".github")] if "/" not in dest else [path]
        if any(f.exists() for f in found):
            results.append(("kept", dest))
            continue
        text = (ASSETS / src).read_text(encoding="utf-8").replace("{{repo}}", slug)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        results.append(("wrote", dest))
    return results


# --- cli --------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_audit = sub.add_parser("audit", help="read-only report")
    p_audit.add_argument("--repo", action="append", required=True, help="OWNER/REPO (repeatable)")
    p_audit.add_argument("--json", action="store_true", help="JSON on stdout")
    p_audit.add_argument("--fail-on-gaps", action="store_true", help="exit 1 when any GAP is found")
    p_fix = sub.add_parser("fix", help="apply the safe settings")
    p_fix.add_argument("--repo", action="append", required=True, help="OWNER/REPO (repeatable)")
    p_fix.add_argument("--dry-run", action="store_true", help="print what would change")
    p_sc = sub.add_parser("scaffold", help="write missing community files into a clone")
    p_sc.add_argument("--repo", required=True, help="OWNER/REPO, used in the file text")
    p_sc.add_argument(
        "--repo-root", type=Path, default=Path.cwd(), help="the local clone (default: cwd)"
    )
    p_sc.add_argument("--contributions", choices=("issues", "pull-requests"), default="issues")
    args = parser.parse_args(argv)

    if args.cmd == "scaffold":
        for outcome, dest in scaffold(args.repo, args.repo_root, args.contributions):
            print(f"{outcome}: {dest}")
        return 0
    if not shutil.which("gh"):
        print("audit_public_repo: `gh` is not installed or not on PATH", file=sys.stderr)
        return 2

    status = 0
    report: dict[str, Any] = {}
    for slug in args.repo:
        try:
            if args.cmd == "audit":
                rows = audit(slug)
                report[slug] = [{"level": lv, "check": c, "detail": d} for lv, c, d in rows]
                if any(lv == "GAP" for lv, _, _ in rows) and args.fail_on_gaps:
                    status = 1
                if not args.json:
                    gaps = sum(lv == "GAP" for lv, _, _ in rows)
                    print(f"== {slug}: {gaps} gap(s)")
                    for lv, c, d in rows:
                        print(f"  {lv:<4} {c}" + (f": {d}" if d else ""))
            else:
                done = fix(slug, args.dry_run)
                print(f"== {slug}")
                for outcome, what in done:
                    print(f"  {outcome}: {what}")
                    if outcome == "failed":
                        status = 1
        except GhError as exc:
            print(f"audit_public_repo: {slug}: {exc}", file=sys.stderr)
            status = 1
    if args.cmd == "audit" and args.json:
        print(json.dumps(report, indent=2))
    return status


if __name__ == "__main__":
    # Findings carry "→" and "—"; a cp1252 console must degrade them, not crash.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
