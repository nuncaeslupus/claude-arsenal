#!/usr/bin/env bash
# tag_guard.sh — decide whether a commit may be tagged, from its CI runs.
#
# `tag-release.yml` fired on any push to main and created v<.bundle-version>
# with no `needs:`, no `workflow_run:` trigger and no check of ci.yml's
# conclusion. A merge whose fresh main-branch CI went red was still tagged, and
# every consumer's `check_update.sh` gates on exactly the newest remote tag — so
# that red release became the version they were offered and subtree-merged.
#
# The decision is here rather than inline in the YAML because a release gate
# nobody can run locally is a release gate nobody tests. Takes a file holding
# a GitHub workflow-runs payload (`{"workflow_runs": [...]}` or a bare array,
# already filtered to one commit) and prints one word:
#
#   tag      the newest CONCLUDED run succeeded — safe to publish
#   refuse   the newest concluded run did not succeed
#   pending  runs exist, none has concluded yet
#   absent   no run at all for this commit
#
# `absent` is not `refuse`: it is what an Actions outage at merge time looks
# like, and refusing it forever would reintroduce the untagged-release failure
# (v0.20.4, v0.21.0) that the daily schedule exists to heal.
#
# Usage: tag_guard.sh <runs.json>
# Exit: 0 when the input parses; 2 on unreadable input or a usage error.

set -uo pipefail

[[ $# -eq 1 ]] || { echo "usage: tag_guard.sh <runs.json>" >&2; exit 2; }

python3 - "$1" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        payload = json.load(fh)
except (json.JSONDecodeError, OSError) as exc:
    print(f"tag_guard: cannot read the workflow-runs payload — {exc}", file=sys.stderr)
    sys.exit(2)

runs = payload.get("workflow_runs") if isinstance(payload, dict) else payload
if not isinstance(runs, list):
    print("tag_guard: payload is not a workflow-runs list", file=sys.stderr)
    sys.exit(2)

runs = [r for r in runs if isinstance(r, dict)]
if not runs:
    print("absent")
    sys.exit(0)

# Newest first by created_at, so a re-run supersedes the run it replaced. The
# API already returns them that way; sorting makes the rule independent of that.
runs.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
concluded = [r for r in runs if str(r.get("status", "")).lower() == "completed"]
if not concluded:
    print("pending")
    sys.exit(0)

print("tag" if str(concluded[0].get("conclusion", "")).lower() == "success" else "refuse")
PY
