#!/usr/bin/env bash
# open_task_pr.sh <task_id> <title> [<type>]
# Commit a worker's task changes on a feature branch cut from the host DEFAULT
# branch (origin/main), push it, and open a PR that closes the task's issue.
#
# Prints ONE line on stdout, consumed by the caller and recorded on the queue
# task's issue via the PR body's `Closes #<issue>` line:
#   <pr-url>            — a PR was created (a `gh` backend was available).
#   branch:<name>       — the branch was pushed but no PR backend exists here;
#                         the orchestrator/operator opens the PR (github skill /
#                         MCP). The branch ref is enough to do so.
#
# Conventional Commits message: `<type>: <title>` (type defaults to feat). The
# Co-Authored-By trailer is NEVER hardcoded — it is taken verbatim from
# ARSENAL_COAUTHOR ("Name <email>") when the caller exports the active model
# identity supplied by the harness. Absent it, no trailer is written.
#
# The PR body AND the commit message both carry `Closes #<issue>`, because that
# is the whole completion mechanism: GitHub closes the task's issue when the PR
# merges, so no session has to remember to update the queue afterwards. The
# number is resolved here rather than left to the caller — this used to be an
# instruction in the worker's prose ("make sure the body carries Closes #N")
# with no data path behind it, so every PR this script opened closed nothing and
# every merged task stayed `claimed` until a human noticed. Both places on
# purpose: the body fires on a merge into the default branch, the commit message
# survives a squash and fires for a stacked PR whose base is another branch.
#
# It also moves the task file into `tasks/_history/` with `status: merged` as
# part of the PR's own diff, so the archive lands exactly when the merge does
# and no follow-up commit is owed to anyone.
#
# Env: ARSENAL_QUEUE_REMOTE (default origin); ARSENAL_COAUTHOR (optional);
#      ARSENAL_TASK_ISSUE (issue number, when the caller already knows it);
#      ARSENAL_ISSUES_JSON (saved issue list, default /tmp/arsenal-issues.json);
#      ARSENAL_HOME (task tree, default arsenal);
#      ARSENAL_ALLOW_UNLINKED_PR=1 (open a PR that closes nothing — see below);
#      ARSENAL_ALLOW_SHARED_ADD (operator escape hatch, see the guard below).
# Exit: 0 branch pushed (PR opened or branch emitted), 1 on push failure /
#       usage / an unresolvable issue handle.

set -uo pipefail

REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
TASK_ID="${1:?open_task_pr.sh requires <task_id>}"
TITLE="${2:?open_task_pr.sh requires <title>}"
TYPE="${3:-feat}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo .)"
BUNDLE_SCRIPTS="$(cd "${SCRIPT_DIR}/../scripts" && pwd 2>/dev/null || echo "${SCRIPT_DIR}/../scripts")"
ARSENAL_HOME="${ARSENAL_HOME:-arsenal}"

# Snapshot the working tree to a permanent refs/arsenal-rescue/… ref. Used
# before the stale-base replay below, which force-moves HEAD across the tree.
# Echoes the ref (empty when the tree is clean or the helper is unavailable).
_rescue_snapshot() {
    [[ -f "${SCRIPT_DIR}/rescue_snapshot.sh" ]] || return 0
    bash "${SCRIPT_DIR}/rescue_snapshot.sh" "$1" 2>/dev/null || true
}

# True when this process runs in a LINKED git worktree (`git worktree add`),
# i.e. real per-worker isolation: a linked worktree has its own git dir that
# differs from the repository's common dir. Derived from git, never from an
# env var the caller sets about itself.
_in_linked_worktree() {
    local git_dir common_dir
    git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null || true)"
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -z "${common_dir}" ]]; then
        # git < 2.31 has no --path-format; resolve the (possibly relative) path.
        common_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
        [[ -n "${common_dir}" ]] && common_dir="$(cd "${common_dir}" 2>/dev/null && pwd -P || true)"
    fi
    [[ -n "${git_dir}" && -n "${common_dir}" && "${git_dir}" != "${common_dir}" ]]
}

# Slug: lowercase, non-alphanumerics → single hyphens, trimmed, capped.
slug="$(printf '%s' "${TITLE}" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')"
[[ -z "${slug}" ]] && slug="task"
BRANCH="arsenal/${TASK_ID}-${slug}"

# Resolve the host default branch from the remote's published HEAD symref, then
# fetch it so we branch off its real tip. NEVER fall back to the current HEAD:
# the worker may run in the orchestrator's tree, and branching off it would drag the entire
# queue-coordination history into the PR. Fail fast instead.
default_branch="$(git ls-remote --symref "${REMOTE}" HEAD 2>/dev/null \
    | sed -n 's|^ref:[[:space:]]*refs/heads/\([^[:space:]]*\).*|\1|p')"
[[ -z "${default_branch}" ]] && default_branch="main"
if git fetch "${REMOTE}" "${default_branch}" >/dev/null 2>&1; then
    default_ref="FETCH_HEAD"
else
    default_ref="${REMOTE}/${default_branch}"
fi
default_base="${default_branch}"

# Cut (or switch to) the feature branch off the default branch. Uncommitted
# worktree changes from the worker carry across the checkout.
#
# A plain `git checkout -b` refuses when those changes touch a file whose
# content differs between the worker's base and the fetched tip — the worker's
# worktree was cut from a STALE base and the default branch has moved since
# (a merged PR from an earlier task in the same session is the common case).
# That is not a real conflict, so do not hard-fail on it: replay the worker's
# edits onto the fresh base instead (`_carry_onto`), which is what a rebase
# would have done. The pre-replay snapshot means even the unresolvable case
# leaves the work on a ref rather than losing it.
_carry_onto() {
    local branch="$1" base="$2" head_sha snapshot ref
    head_sha="$(git rev-parse --verify --quiet HEAD 2>/dev/null || true)"
    [[ -n "${head_sha}" ]] || return 1

    ref="$(_rescue_snapshot "open_task_pr: ${TASK_ID} edits before replay onto ${base}")"
    snapshot=""
    [[ -n "${ref}" ]] && snapshot="$(git rev-parse --verify --quiet "${ref}" 2>/dev/null || true)"
    if [[ -z "${snapshot}" ]]; then
        # No snapshot → no safety net, so do not touch the tree. Either the tree
        # is clean (the checkout failed for some other reason) or
        # rescue_snapshot.sh is unavailable.
        echo "open_task_pr: cannot branch off '${base}' and could not snapshot the working tree first — refusing to move it. Check that claude-arsenal/bin/rescue_snapshot.sh is present, then re-run." >&2
        return 1
    fi

    # Clear the tree to its stale HEAD before moving: the snapshot holds every
    # edit, and leaving the worker's untracked files in place would make the
    # replay below fail with "untracked working tree files would be
    # overwritten". `clean -fd` (no -x) keeps ignored files — node_modules and
    # friends stay put.
    git reset -q --hard >/dev/null 2>&1 || true
    git clean -fdq >/dev/null 2>&1 || true
    git checkout -f -B "${branch}" "${base}" >/dev/null 2>&1 || return 1
    # Applies the snapshot's diff against its parent (the stale base) onto the
    # fresh base, three-way. -n leaves it staged; unstage so the tree looks
    # exactly like the normal carry-across path before `git add -A` below.
    if ! git cherry-pick -n "${snapshot}" >/dev/null 2>&1; then
        git cherry-pick --quit >/dev/null 2>&1 || true
        git reset -q --hard "${base}" >/dev/null 2>&1 || true
        echo "open_task_pr: worker edits for ${TASK_ID} conflict with '${base}' and could not be replayed automatically. They are saved at ${ref} — resolve with 'git cherry-pick -n ${ref}' on the fresh base, then re-run." >&2
        return 1
    fi
    git reset -q >/dev/null 2>&1 || true
    echo "open_task_pr: worker's base was stale; replayed its edits onto '${base}' (snapshot kept at ${ref})" >&2
    return 0
}

# Refuse a shared checkout BEFORE anything mutates git.
#
# Safety guard: git add -A stages everything in the working tree, which risks
# sweeping a CONCURRENT worker's files or secrets into this commit when workers
# share one checkout. The guard used to require ARSENAL_SURFACE=worktree — but
# nothing set it, so every worker hit the refusal and exported it itself. A
# guard the guarded party certifies is not a guard. So derive the answer:
#
#   1. A linked worktree (`git worktree add`) IS the isolation → allow.
#   2. Serialized in-place mode → allow. Not the caller's word for it: the
#      sentinel is written by worktree_probe.sh / worker_postcheck.sh (the
#      orchestrator's own probes), and `unavailable` is exactly what clamps
#      task_select.py to one worker — so there is no concurrent worker to
#      clobber.
#   3. Otherwise refuse. ARSENAL_ALLOW_SHARED_ADD=1 is the operator escape
#      hatch for a bespoke setup, named so it reads as what it is.
_isolation_sentinel() {
    local dir="${ARSENAL_SESSION_DIR:-${ARSENAL_HOME:-arsenal}/session}"
    [[ -f "${dir}/worktree_isolation" ]] || return 1
    [[ "$(tr -d '[:space:]' < "${dir}/worktree_isolation" 2>/dev/null)" == "unavailable" ]]
}
if _in_linked_worktree; then
    :
elif [[ "${ARSENAL_WORKTREE_ISOLATION:-}" == "unavailable" ]] || _isolation_sentinel; then
    :
elif [[ "${ARSENAL_ALLOW_SHARED_ADD:-}" == "1" ]]; then
    :
else
    echo "open_task_pr: git add -A refused on shared checkout — not running in a linked git worktree and serialized in-place mode is not recorded (arsenal/session/worktree_isolation). Run from an isolated worktree, or set ARSENAL_ALLOW_SHARED_ADD=1 if you have verified no other worker shares this checkout." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve the task's issue number BEFORE touching git.
#
# Everything below this point mutates the tree, and a PR that cannot close its
# issue is worse than no PR at all: it merges, the work lands, and the board
# still shows the task claimed — the exact drift the next session pays to find.
# Failing here instead leaves the worker's edits untouched and the fix obvious.
#
# Three sources, cheapest first. The saved issue list is the common case: the
# session-start protocol already fetched every `arsenal:task` issue, so the
# answer is usually sitting on disk.
_resolve_issue() {
    local out

    if [[ -n "${ARSENAL_TASK_ISSUE:-}" ]]; then
        printf '%s' "${ARSENAL_TASK_ISSUE}"
        return 0
    fi

    local resolver="${BUNDLE_SCRIPTS}/issue_for_task.py"
    [[ -f "${resolver}" ]] || return 1

    local saved="${ARSENAL_ISSUES_JSON:-/tmp/arsenal-issues.json}"
    if [[ -s "${saved}" ]] \
        && out="$(python3 "${resolver}" --task "${TASK_ID}" --issues "${saved}" 2>/dev/null)"; then
        printf '%s' "${out}"
        return 0
    fi

    # Nothing saved (or the task is newer than the snapshot) — ask GitHub over
    # whatever channel this surface has. `none` exits 5 here and falls through
    # to the refusal below, which tells the caller to pass --issue: on a surface
    # with no scriptable channel the model holds the number, not the script.
    local slug
    slug="$(bash "${SCRIPT_DIR}/github_channel.sh" --slug 2>/dev/null)" || return 1
    if out="$(bash "${SCRIPT_DIR}/github_channel.sh" --api GET \
                "/repos/${slug}/issues?labels=arsenal:task&state=all&per_page=100" 2>/dev/null)"; then
        if out="$(printf '%s' "${out}" | python3 "${resolver}" --task "${TASK_ID}" --issues - 2>/dev/null)"; then
            printf '%s' "${out}"
            return 0
        fi
    fi
    return 1
}

ISSUE=""
if ! ISSUE="$(_resolve_issue)" || [[ -z "${ISSUE}" ]]; then
    if [[ "${ARSENAL_ALLOW_UNLINKED_PR:-}" == "1" ]]; then
        ISSUE=""
        echo "open_task_pr: no issue handle for ${TASK_ID}; opening an UNLINKED PR because ARSENAL_ALLOW_UNLINKED_PR=1 — merging it will NOT close the task, so close the issue by hand" >&2
    else
        cat >&2 <<EOF
open_task_pr: cannot resolve the issue handle for ${TASK_ID}, so a PR opened now
would merge without closing its task and leave the queue claiming work that is
already done. Nothing has been committed — your edits are untouched.

Fix one of these, then re-run:
  * pass the number you already have:  ARSENAL_TASK_ISSUE=<n> open_task_pr.sh ...
  * point at the session's issue list: ARSENAL_ISSUES_JSON=/tmp/arsenal-issues.json
  * create the missing handle:         python3 ${BUNDLE_SCRIPTS}/handle_sync.py --issues <file>
EOF
        exit 1
    fi
fi

current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${current}" != "${BRANCH}" ]]; then
    if git rev-parse --verify --quiet "${BRANCH}" >/dev/null 2>&1; then
        git checkout "${BRANCH}" >/dev/null 2>&1 || { echo "open_task_pr: cannot switch to ${BRANCH}" >&2; exit 1; }
    elif ! git checkout -b "${BRANCH}" "${default_ref}" >/dev/null 2>&1; then
        if ! git rev-parse --verify --quiet "${default_ref}" >/dev/null 2>&1; then
            echo "open_task_pr: cannot resolve default branch '${default_branch}' (ref '${default_ref}') to branch off" >&2
            exit 1
        fi
        _carry_onto "${BRANCH}" "${default_ref}" || exit 1
    fi
fi

# Archive the task file as part of THIS PR's diff.
#
# A finished task's file is not work any more — it is what makes a dep on
# completed work resolve instead of reading as unknown, and what keeps its gate
# on disk. `task_select.py` already reads `tasks/_history/` and already treats a
# `status: merged` front-matter key as terminal; nothing ever wrote either. So
# the archive was a step owed to some later session, and later sessions do not
# run it.
#
# Riding it in the PR fixes the timing exactly: the rename lands on the default
# branch at the moment the merge does, and if the PR never merges the task file
# never moves. No follow-up commit, no push to a protected branch, nothing to
# reconcile.
_archive_task_file() {
    local live="${ARSENAL_HOME}/tasks/${TASK_ID}.md"
    local hist_dir="${ARSENAL_HOME}/tasks/_history"
    local dest="${hist_dir}/${TASK_ID}.md"

    # An unlinked PR closes nothing, so archiving would record work as merged
    # while its issue stays open — a contradiction this script exists to prevent.
    # Leave the task file live: the PR is then just code, and the task is still
    # open, which is the truth.
    if [[ -z "${ISSUE}" ]]; then
        echo "open_task_pr: unlinked PR — leaving ${live} live, since merging it completes nothing" >&2
        return 0
    fi

    # No task file is legitimate (a task worked from a payload elsewhere); a
    # file that exists and cannot be archived is not. Every failure below is
    # fatal, because the PR body promises the archive and a half-done one leaves
    # exactly the drift this whole change removes.
    [[ -f "${live}" ]] || return 0

    mkdir -p "${hist_dir}" || { echo "open_task_pr: cannot create ${hist_dir}" >&2; return 1; }
    if ! git mv "${live}" "${dest}" 2>/dev/null; then
        mv "${live}" "${dest}" 2>/dev/null \
            || { echo "open_task_pr: cannot move ${live} to ${dest}" >&2; return 1; }
    fi

    # Stamp the terminal status inside the front matter, so the record survives
    # even if the issue is later deleted or the repo is read without GitHub.
    python3 - "${dest}" <<'PY' || { echo "open_task_pr: cannot stamp 'status: merged' into ${dest}" >&2; return 1; }
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
match = re.match(r"\A---\r?\n(.*?)\r?\n---\r?\n", text, re.DOTALL)
if not match:
    sys.exit(0)
front = match.group(1)
if re.search(r"^status:", front, re.MULTILINE):
    front = re.sub(r"^status:.*$", "status: merged", front, count=1, flags=re.MULTILINE)
else:
    front = front + "\nstatus: merged"
path.write_text(text[: match.start(1)] + front + text[match.end(1) :], encoding="utf-8")
PY
    # Assert the outcome rather than assume it: the PR body tells a reader the
    # gate lives at the archived path, and `task_select.py` only treats the file
    # as finished work when it parses a terminal `status`.
    if [[ ! -f "${dest}" ]] || ! grep -q '^status: merged$' "${dest}"; then
        echo "open_task_pr: ${dest} is not a complete archive (missing, or no 'status: merged')" >&2
        return 1
    fi
    echo "open_task_pr: archived ${live} -> ${dest} (status: merged)" >&2
}
if ! _archive_task_file; then
    echo "open_task_pr: refusing to open a PR whose task file could not be archived — the merge would close the issue and leave the task file live. Fix the error above and re-run; nothing has been committed." >&2
    exit 1
fi

# Stage and commit — the shared-checkout guard above already cleared `git add
# -A`, and a dynamic Co-Authored-By is added only when supplied.
git add -A

# `Closes #<issue>` goes in the commit message as well as the PR body. The body
# form only fires on a merge into the default branch; the commit form survives a
# squash merge and is what closes the issue for a stacked PR based on another
# branch. Writing both costs one line and removes a caveat nobody remembers.
commit_args=(-m "${TYPE}: ${TITLE}")
if [[ -n "${ISSUE}" ]]; then
    commit_args+=(-m "Closes #${ISSUE}")
fi
if [[ -n "${ARSENAL_COAUTHOR:-}" ]]; then
    commit_args+=(-m "Co-Authored-By: ${ARSENAL_COAUTHOR}")
fi
if ! git commit "${commit_args[@]}" >/dev/null 2>&1; then
    echo "open_task_pr: nothing to commit for ${TASK_ID} (empty diff); return outcome 'open' with failure notes" >&2
    exit 1
fi

# Push with exponential backoff (network-transient retry only).
delay=1
pushed=0
for _ in 1 2 3; do
    if git push -u "${REMOTE}" "${BRANCH}" >/dev/null 2>&1; then pushed=1; break; fi
    sleep "${delay}"
    delay=$((delay * 2))
done
if [[ "${pushed}" -ne 1 ]]; then
    echo "open_task_pr: push of ${BRANCH} to ${REMOTE} failed" >&2
    exit 1
fi

# The PR body. `Closes #<issue>` is the first line of the summary rather than a
# trailer, because a squash merge that truncates the body still keeps the top.
closes_line=""
[[ -n "${ISSUE}" ]] && closes_line="Closes #${ISSUE}"
if [[ -n "${ISSUE}" ]]; then
    gate_note="$(printf 'Acceptance gate in `%s/tasks/_history/%s.md` (archived by this PR); it passed before the PR was opened.' "${ARSENAL_HOME}" "${TASK_ID}")"
else
    gate_note="$(printf 'Acceptance gate in `%s/tasks/%s.md`; it passed before the PR was opened. This PR closes no issue, so merging it does NOT complete the task.' "${ARSENAL_HOME}" "${TASK_ID}")"
fi
BODY="$(printf '## Summary\n\n%s\n\n%s\n\n## Test plan\n\n%s\n' \
    "${closes_line}" "${TITLE}" "${gate_note}")"
PR_TITLE="${TYPE}: ${TITLE}"

# Open the PR over whichever channel exists. `gh` first, then REST — the REST
# leg matters because the push-only outcome is not a completed task: it hands
# back a branch nobody has opened a PR for, and if the session ends there the
# task stays claimed with its work sitting on an orphan branch. Every surface
# that can reach the API should close that gap itself rather than delegate it.
if command -v gh >/dev/null 2>&1; then
    if url="$(gh pr create --base "${default_base}" --head "${BRANCH}" \
                --title "${PR_TITLE}" --body "${BODY}" 2>/dev/null)"; then
        echo "${url}"
        exit 0
    fi
fi

if slug="$(bash "${SCRIPT_DIR}/github_channel.sh" --slug 2>/dev/null)" && [[ -n "${slug}" ]]; then
    payload="$(python3 -c 'import json,sys; print(json.dumps({"title":sys.argv[1],"head":sys.argv[2],"base":sys.argv[3],"body":sys.argv[4]}))' \
        "${PR_TITLE}" "${BRANCH}" "${default_base}" "${BODY}" 2>/dev/null || true)"
    if [[ -n "${payload}" ]] \
        && response="$(bash "${SCRIPT_DIR}/github_channel.sh" --api POST "/repos/${slug}/pulls" "${payload}" 2>/dev/null)"; then
        url="$(printf '%s' "${response}" \
            | python3 -c 'import json,sys; print(json.load(sys.stdin).get("html_url",""))' 2>/dev/null || true)"
        if [[ -n "${url}" ]]; then
            echo "${url}"
            exit 0
        fi
    fi
fi

# No PR backend at all. Say what still has to happen, including the keyword —
# the caller opening this PR by hand is the one path where the body is written
# by someone other than this script.
echo "open_task_pr: no PR backend here — open the PR for ${BRANCH} with a body containing '${closes_line:-Closes #<issue>}', or the merge will not close the task" >&2
echo "branch:${BRANCH}"
exit 0
