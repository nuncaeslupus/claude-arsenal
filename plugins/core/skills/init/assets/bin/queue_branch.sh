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
DEFAULT_BRANCH="${ARSENAL_DEFAULT_BRANCH:-main}"

current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

has_remote=0
git remote get-url "${REMOTE}" >/dev/null 2>&1 && has_remote=1

# Merge the host default branch into the queue branch so the working tree
# always reflects PRs that landed since the last sync. No-ops when already
# up-to-date. Called at every exit so session-start and inter-iteration
# calls both stay current.
sync_from_default() {
    [[ ${has_remote} -eq 0 ]] && return 0
    git fetch "${REMOTE}" "${DEFAULT_BRANCH}" >/dev/null 2>&1 || return 0
    git rev-parse --verify --quiet "${REMOTE}/${DEFAULT_BRANCH}" >/dev/null 2>&1 || return 0
    git merge --no-edit "${REMOTE}/${DEFAULT_BRANCH}" >/dev/null 2>&1 || {
        git merge --abort >/dev/null 2>&1 || true
        echo "queue_branch.sh: WARNING — could not merge ${REMOTE}/${DEFAULT_BRANCH} into ${QUEUE_BRANCH}" >&2
    }
}

# Already on the branch → wire upstream if missing, sync from default, exit.
if [[ "${current}" == "${QUEUE_BRANCH}" ]]; then
    if [[ ${has_remote} -eq 1 ]] \
        && ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
        git branch --set-upstream-to="${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    fi
    sync_from_default
    echo "on coordination branch '${QUEUE_BRANCH}'"
    exit 0
fi

# Refuse to switch only when tracked files are modified — those risk being
# clobbered. Untracked files (-uno excludes them) don't block a checkout and
# shouldn't block session start-up.
if [[ -n "$(git status --porcelain -uno 2>/dev/null)" ]]; then
    echo "queue_branch.sh: tracked files have uncommitted changes; commit or stash before switching to '${QUEUE_BRANCH}'" >&2
    exit 1
fi

# Remote already publishes the branch → track it.
if [[ ${has_remote} -eq 1 ]] \
    && git ls-remote --exit-code --heads "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1; then
    git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    if git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        git checkout "${QUEUE_BRANCH}" >/dev/null 2>&1
        # checkout of an existing local branch does not (re)set upstream — wire
        # it now so status/ahead-behind is correct without a second run.
        git branch --set-upstream-to="${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    else
        git checkout -b "${QUEUE_BRANCH}" --track "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1
    fi
    sync_from_default
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
        sync_from_default
        echo "created and published '${QUEUE_BRANCH}'"
        exit 0
    fi
    echo "queue_branch.sh: WARNING — could not push '${QUEUE_BRANCH}' to '${REMOTE}'; cross-session locking will not work until it is published" >&2
    sync_from_default
    exit 0
fi

echo "queue_branch.sh: WARNING — no '${REMOTE}' remote; '${QUEUE_BRANCH}' is local-only and cannot coordinate across sessions" >&2
exit 0
