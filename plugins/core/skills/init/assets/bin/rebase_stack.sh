#!/usr/bin/env bash
# rebase_stack.sh [--no-push] <branch> <old-base>
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
# --no-push  — rebase only; skip the host gate and the force-push
#
# Evidence conflicts resolve themselves. A repo that uses evidence gates
# commits a measurement of its own tree (`evidence:` in a task's gate block),
# so every branch touches those files and every replay onto a moved base
# conflicts on them. Hand-merging two of them is meaningless — the right answer
# is neither side, it is whatever the code measures on the resulting tree. So
# when the conflicted set is a SUBSET of the declared evidence paths, this takes
# the branch's side, re-runs the host gate to regenerate, and continues.
# Anything outside that set stops the rebase and is reported: that is a real
# conflict and a human's to resolve. The subset test is what makes the
# auto-resolve safe to run without thinking about it.

set -euo pipefail

NO_PUSH=0
args=()
for a in "$@"; do
    case "${a}" in
        --no-push) NO_PUSH=1 ;;
        *) args+=("${a}") ;;
    esac
done
set -- "${args[@]+"${args[@]}"}"

# Run from the repo root so `git diff --name-only` and the declared evidence
# paths are in the same frame of reference (both repo-root-relative), and so
# ARSENAL_HOME resolves the way every other script resolves it.
cd "$(git rev-parse --show-toplevel)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_SCRIPTS="${SCRIPT_DIR}/../scripts"
ARSENAL_HOME="${ARSENAL_HOME:-arsenal}"

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
OLD_BASE="${2:?rebase_stack.sh requires <old-base> (tip of the parent branch)}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"

# The host's own aggregate gate. Regenerating evidence is part of what it runs,
# which is why it is also what resolves an evidence conflict. Absent by default,
# so a repo without one is unaffected — it just gets the diagnosis instead of
# the auto-resolve.
host_gate=""
if [[ -f "${BUNDLE_SCRIPTS}/arsenal_config.py" ]]; then
    host_gate="$(python3 "${BUNDLE_SCRIPTS}/arsenal_config.py" \
        --repo-root "$(pwd)" --get host-gate 2>/dev/null || true)"
fi

# SECURITY: host-gate runs verbatim, like a payload's gate block. It comes from
# arsenal/config.toml, which is host-owned and reviewed like any other file in
# the repo — but it is code, not data.
run_host_gate() {
    [[ -n "${host_gate}" ]] || return 0
    echo "rebase_stack: running host gate: ${host_gate}" >&2
    bash -c "${host_gate}" >&2
}

evidence_paths=""
if [[ -f "${BUNDLE_SCRIPTS}/gate_evidence.py" ]]; then
    evidence_paths="$(python3 "${BUNDLE_SCRIPTS}/gate_evidence.py" \
        --list-only "${ARSENAL_HOME}/tasks" 2>/dev/null || true)"
fi

is_evidence() {
    [[ -n "${evidence_paths}" ]] && grep -qxF -- "$1" <<<"${evidence_paths}"
}

conflicted() { git diff --name-only --diff-filter=U; }

# Explain, then leave the rebase in progress: the tree is the reader's to
# resolve and `git rebase --abort` is theirs to decide on.
stop_here() {
    echo "rebase_stack: $1" >&2
    echo "rebase_stack: the rebase is still in progress — resolve and 'git rebase --continue', or 'git rebase --abort'" >&2
    exit 1
}

resolve_evidence_conflicts() {
    local files f outside
    files="$(conflicted)"
    [[ -n "${files}" ]] || stop_here "the rebase stopped with no conflicted files — read the message above"

    outside=""
    while IFS= read -r f; do
        is_evidence "${f}" || outside+="  ${f}"$'\n'
    done <<<"${files}"

    if [[ -n "${outside}" ]]; then
        echo "rebase_stack: conflicts outside the declared evidence set:" >&2
        printf '%s' "${outside}" >&2
        stop_here "a real conflict — nothing was auto-resolved"
    fi

    if [[ -z "${host_gate}" ]]; then
        echo "rebase_stack: every conflicted file is a declared evidence path — a build product:" >&2
        sed 's/^/  /' <<<"${files}" >&2
        stop_here "do not hand-merge these; regenerate them instead. Declare the command as 'host-gate' in ${ARSENAL_HOME}/config.toml and this resolves itself"
    fi

    echo "rebase_stack: evidence-only conflict; regenerating rather than merging:" >&2
    sed 's/^/  /' <<<"${files}" >&2
    while IFS= read -r f; do
        # --theirs is the commit being replayed (the branch's own work). Either
        # side would do — the gate is about to overwrite it — but a file the
        # gate does not in fact rewrite is then the branch's, not the base's.
        git checkout --theirs -- "${f}" 2>/dev/null || true
    done <<<"${files}"
    run_host_gate || stop_here "the host gate failed while regenerating evidence"
    while IFS= read -r f; do
        git add -A -- "${f}"
    done <<<"${files}"
}

default_branch="$(git ls-remote --symref "${REMOTE}" HEAD 2>/dev/null \
    | sed -n 's|^ref:[[:space:]]*refs/heads/\([^[:space:]]*\).*|\1|p')"
[[ -z "${default_branch}" ]] && default_branch="main"
git fetch "${REMOTE}" "${default_branch}" >/dev/null 2>&1

fork="$(git merge-base "${BRANCH}" "${OLD_BASE}")"
echo "rebase_stack: replaying ${BRANCH} commits after ${fork:0:12} onto ${REMOTE}/${default_branch}"

if ! git rebase --onto "${REMOTE}/${default_branch}" "${fork}" "${BRANCH}"; then
    # One pass per conflicting commit. The bound is a backstop, not a budget:
    # a stack deeper than this is not what went wrong.
    for _ in $(seq 1 50); do
        resolve_evidence_conflicts
        if GIT_EDITOR=true git rebase --continue; then
            break
        fi
    done
    if [[ -d "$(git rev-parse --git-path rebase-merge)" || -d "$(git rev-parse --git-path rebase-apply)" ]]; then
        stop_here "still rebasing after 50 conflict passes — stopping rather than looping"
    fi
fi

if (( NO_PUSH )); then
    echo "rebase_stack: ${BRANCH} rebased; --no-push, so nothing was pushed"
    exit 0
fi

# Before publishing, not after. A rebase can succeed and still leave committed
# evidence that no longer describes the tree it now sits on; pushing that
# publishes a head that fails the host's own gate.
run_host_gate || {
    echo "rebase_stack: host gate failed after the rebase — NOT pushing ${BRANCH}" >&2
    echo "rebase_stack: fix it, commit, and push yourself (or re-run with --no-push to skip this)" >&2
    exit 1
}

git push --force-with-lease "${REMOTE}" "${BRANCH}"
echo "rebase_stack: ${BRANCH} rebased and pushed"
