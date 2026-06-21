#!/usr/bin/env bash
# rebase_stack.sh <branch> <old-base>
# Rebase a stacked branch onto the current origin/main after its parent PR
# has been squash-merged. Replays only the commits between <old-base>
# (exclusive) and <branch> (inclusive) — skipping the already-merged parent
# commits — then force-pushes with lease.
#
# Usage (after fix/iss-A merges into main):
#   bin/rebase_stack.sh fix/iss-B fix/iss-A
#
# <branch>   — the stacked branch to rebase (defaults to current branch)
# <old-base> — the tip of the parent branch at the time <branch> was cut
#              (a branch name, tag, or commit SHA)

set -euo pipefail

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
OLD_BASE="${2:?rebase_stack.sh requires <old-base> (tip of the parent branch)}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"

git fetch "${REMOTE}" main >/dev/null 2>&1

fork="$(git merge-base "${BRANCH}" "${OLD_BASE}")"
echo "rebase_stack: replaying ${BRANCH} commits after ${fork:0:12} onto ${REMOTE}/main"
git rebase --onto "${REMOTE}/main" "${fork}" "${BRANCH}"
git push --force-with-lease "${REMOTE}" "${BRANCH}"
echo "rebase_stack: ${BRANCH} rebased and pushed"
