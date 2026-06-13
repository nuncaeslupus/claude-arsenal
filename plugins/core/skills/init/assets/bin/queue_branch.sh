#!/usr/bin/env bash
# queue_branch.sh
# Ensures the dedicated queue-coordination branch exists and is checked out
# with an upstream, so claim.sh / release.sh can use its remote ref as the
# cross-session lock. Idempotent: safe to run at every session start.
#
# Branch name: ARSENAL_QUEUE_BRANCH (default: arsenal-queue).
# Remote:      ARSENAL_QUEUE_REMOTE (default: origin).
#
# Why a dedicated branch: the queue's correctness depends on every orchestrator
# session pushing claims to ONE shared, pushable ref. A protected branch (main)
# would reject every claim → silent deadlock; divergent feature branches would
# let two sessions both "win" the same task. This branch is unprotected and
# shared, off to the side of mainline history (it is never merged into main).
#
# Exit: 0 on success (on the branch, upstream set where a remote exists),
#       1 if the working tree is dirty (refuses to switch and clobber state).

set -uo pipefail

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"

current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

has_remote=0
git remote get-url "${REMOTE}" >/dev/null 2>&1 && has_remote=1

# Already on the branch → just make sure the upstream is wired, then exit.
if [[ "${current}" == "${QUEUE_BRANCH}" ]]; then
    if [[ ${has_remote} -eq 1 ]] \
        && ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
        git branch --set-upstream-to="${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    fi
    echo "on coordination branch '${QUEUE_BRANCH}'"
    exit 0
fi

# Refuse to switch branches with a dirty tree — we'd risk clobbering work.
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "queue_branch.sh: working tree is dirty; commit or stash before switching to '${QUEUE_BRANCH}'" >&2
    exit 1
fi

# Remote already publishes the branch → track it.
if [[ ${has_remote} -eq 1 ]] \
    && git ls-remote --exit-code --heads "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1; then
    git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    if git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        git checkout "${QUEUE_BRANCH}" >/dev/null 2>&1
    else
        git checkout -b "${QUEUE_BRANCH}" --track "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1
    fi
    echo "tracking existing '${REMOTE}/${QUEUE_BRANCH}'"
    exit 0
fi

# Local branch already exists → switch to it; otherwise create it from HEAD
# (typically the default branch the session started on).
if git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
    git checkout "${QUEUE_BRANCH}" >/dev/null 2>&1
else
    git checkout -b "${QUEUE_BRANCH}" >/dev/null 2>&1
fi

# Publish + set upstream so claim.sh / release.sh can push by ref.
if [[ ${has_remote} -eq 1 ]]; then
    if git push -u "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        echo "created and published '${QUEUE_BRANCH}'"
        exit 0
    fi
    echo "queue_branch.sh: WARNING — could not push '${QUEUE_BRANCH}' to '${REMOTE}'; cross-session locking will not work until it is published" >&2
    exit 0
fi

echo "queue_branch.sh: WARNING — no '${REMOTE}' remote; '${QUEUE_BRANCH}' is local-only and cannot coordinate across sessions" >&2
exit 0
