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
# Worktree dir: ARSENAL_QUEUE_WORKTREE (default: <repo-root>/../<repo-name>-arsenal-queue-wt)
#
# Exit: 0 on success, 1 on hard failure.

set -uo pipefail

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
DEFAULT_BRANCH="${ARSENAL_DEFAULT_BRANCH:-main}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_NAME="$(basename "${REPO_ROOT}")"
QUEUE_WORKTREE="${ARSENAL_QUEUE_WORKTREE:-${REPO_ROOT}/../${REPO_NAME}-arsenal-queue-wt}"

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
# find_branch_worktree: path of the worktree (if any) that already has
# QUEUE_BRANCH checked out, per `git worktree list`. Git refuses a second
# worktree for the same branch ("'<branch>' is already used by worktree at
# '<path>'"), so callers must discover and reuse that path rather than
# hard-failing when it doesn't match the computed default — e.g. a worktree
# left at a legacy, non-namespaced path from before repo-name scoping was
# added (see queue_branch.sh history). Every path `git worktree list` reports
# belongs to THIS repo by construction, so no separate ownership check is
# needed for a path found this way.
# ---------------------------------------------------------------------------
find_branch_worktree() {
    local branch="$1"
    git worktree list --porcelain 2>/dev/null | awk -v want="refs/heads/${branch}" '
        /^worktree / { path = substr($0, 10) }
        $0 == "branch " want { print path; exit }
    '
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

# Verify an existing directory at QUEUE_WORKTREE belongs to this clone before
# reusing it. Comparing the common git directory (the physical .git dir) is
# robust against SSH/HTTPS URL mismatches and multiple local clones of the same
# remote — both would pass a remote-URL check yet cannot share a worktree.
if [[ -d "${QUEUE_WORKTREE}" && -e "${QUEUE_WORKTREE}/.git" ]]; then
    this_common_dir="$(cd "${REPO_ROOT}" && cd "$(git rev-parse --git-common-dir)" && pwd)"
    existing_common_dir="$(cd "${QUEUE_WORKTREE}" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd || true)"
    if [[ -n "${existing_common_dir}" && "${existing_common_dir}" != "${this_common_dir}" ]]; then
        echo "queue_branch.sh: ERROR — '${QUEUE_WORKTREE}' belongs to a different repository clone; set ARSENAL_QUEUE_WORKTREE to a different path" >&2
        exit 1
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

    # The branch may already be checked out at a DIFFERENT path than the one
    # just computed — most commonly a worktree created before repo-name
    # scoping (#122) landed, sitting at the old shared default
    # `../arsenal-queue-wt`. `git worktree add` would fail outright in that
    # case ("already used by worktree at ..."); detect it first and reuse
    # that worktree instead of hard-failing.
    existing_path="$(find_branch_worktree "${QUEUE_BRANCH}")"
    if [[ -n "${existing_path}" && "${existing_path}" != "${QUEUE_WORKTREE}" ]]; then
        if [[ -e "${existing_path}/.git" ]]; then
            echo "queue_branch.sh: '${QUEUE_BRANCH}' is already checked out at '${existing_path}' (expected '${QUEUE_WORKTREE}'); reusing it instead of creating a second worktree" >&2
            QUEUE_WORKTREE="${existing_path}"
            wt_registered=1
        else
            # Registration is stale (directory removed by hand) — prune and
            # fall through to creating at the computed default path.
            git worktree prune >/dev/null 2>&1 || true
        fi
    fi
fi

if [[ ${wt_registered} -eq 0 ]]; then
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

# Abort if the worktree was not properly initialised — git -C on a plain
# directory (without .git) silently traverses up to the parent repo.
if [[ ! -e "${QUEUE_WORKTREE}/.git" ]]; then
    echo "queue_branch.sh: ERROR — failed to initialise worktree at '${QUEUE_WORKTREE}'; remove the directory and retry" >&2
    exit 1
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
