#!/usr/bin/env bash
# queue_branch.sh
# Ensures the queue-coordination worktree exists and is up to date, then
# echoes its path to stdout so callers can capture it:
#
#   export ARSENAL_QUEUE_DIR="$(claude-arsenal/bin/queue_branch.sh)"
#
# The coordination branch (default: arsenal-queue) lives in a SIDE git
# worktree — the main working tree NEVER changes branch. This means web
# servers, editors, and other consumers of the repo always see the host
# default-branch content regardless of what the queue is doing.
#
# claim.sh and release.sh honour ARSENAL_QUEUE_DIR: when set, they cd into
# the worktree so the push-CAS lock works without touching the main HEAD.
#
# Idempotent: safe to run at every session start and between loop iterations.
#
# Transition: if the main tree is currently on ARSENAL_QUEUE_BRANCH (leftover
# from a legacy session that used the old branch-switch behaviour), this script
# automatically switches it back to ARSENAL_DEFAULT_BRANCH.
#
# Falls back to the legacy branch-switch behaviour when git worktrees are
# unavailable (very old git or bare repo). In that mode nothing is echoed and
# claim/release run from the main tree as before.
#
# Branch name:  ARSENAL_QUEUE_BRANCH   (default: arsenal-queue)
# Remote:       ARSENAL_QUEUE_REMOTE   (default: origin)
# Default br:   ARSENAL_DEFAULT_BRANCH (default: main)
# Worktree dir: ARSENAL_QUEUE_WORKTREE (default: <repo-root>/../arsenal-queue-wt)
#
# Exit: 0 on success, 1 on hard failure.

set -uo pipefail

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
DEFAULT_BRANCH="${ARSENAL_DEFAULT_BRANCH:-main}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
QUEUE_WORKTREE="${ARSENAL_QUEUE_WORKTREE:-${REPO_ROOT}/../arsenal-queue-wt}"

has_remote=0
git remote get-url "${REMOTE}" >/dev/null 2>&1 && has_remote=1

# ---------------------------------------------------------------------------
# sync_worktree: fast-forward the coordination worktree to the latest
# origin/<queue-branch> so claim/release commits pushed by OTHER sessions are
# pulled in. The queue branch is an append-only ledger that is never merged
# into mainline — so we do NOT merge the default branch into it (that would
# fork the ledger and, on hosts that empty the main-tree tasks.jsonl seed,
# conflicts on every session). A non-FF result means this worktree carries
# un-pushed claim/release commits — the legitimate optimistic-lock path; leave
# that to release.sh's existing rebase rather than forcing it here.
# ---------------------------------------------------------------------------
sync_worktree() {
    local wt="$1"
    [[ ${has_remote} -eq 0 ]] && return 0
    git -C "${wt}" fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || return 0
    git -C "${wt}" merge --ff-only "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# legacy_sync: fast-forward the current (queue) branch to origin/<queue-branch>
# so it picks up claim/release commits from other sessions (only used when
# worktrees are unavailable). FF-only — never merges the default branch into
# the append-only ledger; a non-FF result is the optimistic-lock path left to
# release.sh.
# ---------------------------------------------------------------------------
legacy_sync() {
    [[ ${has_remote} -eq 0 ]] && return 0
    git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || return 0
    git rev-parse --verify --quiet "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || return 0
    git merge --ff-only "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# LEGACY FALLBACK — only when `git worktree` is unavailable.
# Preserves the original branch-switch behaviour exactly.
# ---------------------------------------------------------------------------
if ! git worktree list >/dev/null 2>&1; then
    echo "queue_branch.sh: git worktrees unavailable; falling back to legacy branch-switch mode" >&2
    current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ "${current}" == "${QUEUE_BRANCH}" ]]; then
        if [[ ${has_remote} -eq 1 ]] \
            && ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
            git branch --set-upstream-to="${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
        fi
        legacy_sync
        echo "on coordination branch '${QUEUE_BRANCH}' (legacy mode)" >&2
        exit 0
    fi
    if [[ -n "$(git status --porcelain -uno 2>/dev/null)" ]]; then
        echo "queue_branch.sh: tracked files have uncommitted changes; commit or stash before switching to '${QUEUE_BRANCH}'" >&2
        exit 1
    fi
    if [[ ${has_remote} -eq 1 ]] \
        && git ls-remote --exit-code --heads "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
        if git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
            git checkout "${QUEUE_BRANCH}" >/dev/null 2>&1
            git branch --set-upstream-to="${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
        else
            git checkout -b "${QUEUE_BRANCH}" --track "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1
        fi
        legacy_sync
        echo "tracking existing '${REMOTE}/${QUEUE_BRANCH}' (legacy mode)" >&2
        exit 0
    fi
    if git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        git checkout "${QUEUE_BRANCH}" >/dev/null 2>&1
    else
        git checkout -b "${QUEUE_BRANCH}" >/dev/null 2>&1
    fi
    if [[ ${has_remote} -eq 1 ]]; then
        if git push -u "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1; then
            legacy_sync
            echo "created and published '${QUEUE_BRANCH}' (legacy mode)" >&2
            exit 0
        fi
        echo "queue_branch.sh: WARNING — could not push '${QUEUE_BRANCH}' to '${REMOTE}'; cross-session locking will not work until it is published" >&2
        legacy_sync
        exit 0
    fi
    echo "queue_branch.sh: WARNING — no '${REMOTE}' remote; '${QUEUE_BRANCH}' is local-only and cannot coordinate across sessions" >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# WORKTREE MODE — main tree stays on its current branch.
# ---------------------------------------------------------------------------

# Transition: if the main tree is on the coordination branch (left by a
# legacy session), switch it back to the default branch so host consumers
# (web servers, editors) see the correct content again.
current_main="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${current_main}" == "${QUEUE_BRANCH}" ]]; then
    if [[ -n "$(git status --porcelain -uno 2>/dev/null)" ]]; then
        echo "queue_branch.sh: ERROR — main tree is on '${QUEUE_BRANCH}' with uncommitted changes; cannot auto-switch to '${DEFAULT_BRANCH}'. Please commit, stash, or discard your changes, then switch the main tree to '${DEFAULT_BRANCH}' manually." >&2
        exit 1
    else
        git checkout "${DEFAULT_BRANCH}" >/dev/null 2>&1 \
            || { git fetch "${REMOTE}" "${DEFAULT_BRANCH}" >/dev/null 2>&1 || true; \
                 git checkout -b "${DEFAULT_BRANCH}" "${REMOTE}/${DEFAULT_BRANCH}" >/dev/null 2>&1; } \
            || { echo "queue_branch.sh: ERROR — could not switch main tree from '${QUEUE_BRANCH}' to '${DEFAULT_BRANCH}'" >&2; exit 1; }
    fi
fi

# Ensure the coordination branch exists on the remote; create + push if not.
if [[ ${has_remote} -eq 1 ]]; then
    git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    if ! git ls-remote --exit-code --heads "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        # Not on remote — create a local branch off the default branch and push.
        if ! git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
            git branch "${QUEUE_BRANCH}" "${REMOTE}/${DEFAULT_BRANCH}" >/dev/null 2>&1 \
                || git branch "${QUEUE_BRANCH}" "${DEFAULT_BRANCH}" >/dev/null 2>&1 \
                || git branch "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
        fi
        git push -u "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 \
            || echo "queue_branch.sh: WARNING — could not push '${QUEUE_BRANCH}' to '${REMOTE}'; cross-session locking will not work until published" >&2
    fi
fi

# Create or reuse the worktree.
# Check by canonical path match in the porcelain listing.
wt_registered=0
if git worktree list --porcelain 2>/dev/null | grep -qxF "worktree ${QUEUE_WORKTREE}"; then
    wt_registered=1
fi

if [[ ${wt_registered} -eq 0 ]]; then
    # Clean up any stale worktree record pointing at this path before adding.
    git worktree prune >/dev/null 2>&1 || true

    mkdir -p "$(dirname "${QUEUE_WORKTREE}")" 2>/dev/null || true

    if [[ ${has_remote} -eq 1 ]] \
        && git rev-parse --verify --quiet "${REMOTE}/${QUEUE_BRANCH}" >/dev/null 2>&1; then
        if git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
            # Local branch exists; add worktree pointing at it, then wire upstream.
            git worktree add "${QUEUE_WORKTREE}" "${QUEUE_BRANCH}" >/dev/null || true
            git -C "${QUEUE_WORKTREE}" branch --set-upstream-to="${REMOTE}/${QUEUE_BRANCH}" \
                >/dev/null 2>&1 || true
        else
            # Create local branch tracking the remote and add worktree.
            git worktree add -b "${QUEUE_BRANCH}" "${QUEUE_WORKTREE}" \
                "${REMOTE}/${QUEUE_BRANCH}" >/dev/null || true
        fi
    elif git rev-parse --verify --quiet "${QUEUE_BRANCH}" >/dev/null 2>&1; then
        # Remote unavailable but local branch exists.
        git worktree add "${QUEUE_WORKTREE}" "${QUEUE_BRANCH}" >/dev/null || true
    else
        # Neither remote nor local branch — create from current HEAD.
        git worktree add -b "${QUEUE_BRANCH}" "${QUEUE_WORKTREE}" >/dev/null || true
        if [[ ${has_remote} -eq 1 ]]; then
            git -C "${QUEUE_WORKTREE}" push -u "${REMOTE}" "${QUEUE_BRANCH}" \
                >/dev/null 2>&1 || true
        fi
    fi
fi

# Verify the worktree is on the right branch; try to recover via checkout
# before giving up (handles the case of manual branch switches in the worktree).
wt_branch="$(git -C "${QUEUE_WORKTREE}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${wt_branch}" != "${QUEUE_BRANCH}" ]]; then
    git -C "${QUEUE_WORKTREE}" checkout "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    wt_branch="$(git -C "${QUEUE_WORKTREE}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi
if [[ "${wt_branch}" != "${QUEUE_BRANCH}" ]]; then
    echo "queue_branch.sh: ERROR — worktree '${QUEUE_WORKTREE}' is on '${wt_branch:-unknown}', expected '${QUEUE_BRANCH}'" >&2
    exit 1
fi

# Fast-forward the worktree to origin/<queue-branch> so it carries claim/release
# commits pushed by other sessions (FF-only — never forks the append-only ledger).
sync_worktree "${QUEUE_WORKTREE}"

# Echo the worktree path — callers capture this as ARSENAL_QUEUE_DIR.
echo "${QUEUE_WORKTREE}"
