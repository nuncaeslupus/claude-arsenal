#!/usr/bin/env bash
# claim.sh <task_id> [<session_id>]
# Attempts to claim an open task with optimistic git-push concurrency.
#
# The queue lives on a dedicated coordination branch (default: arsenal-queue,
# override with ARSENAL_QUEUE_BRANCH). All orchestrator sessions MUST run on
# that branch so its remote ref is the shared lock: two sessions race to
# fast-forward the same ref and Git lets exactly one win. Per-task code work
# happens in worktrees on feature branches, never on this branch.
#
# Stdout:
#   "won" + task JSON   — claim landed on the remote.
#   "lost"              — another session won the race (remote ref moved on).
#   "error: <reason>"   — misconfiguration (wrong branch, protected branch,
#                         no upstream/remote). NOT a race; the loop must stop.
# Exit:
#   0 — won or lost.
#   2 — error (loud failure, kept distinct from a lost race).

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
QUEUE_FILE="claude-arsenal/queue/tasks.jsonl"
TASK_ID="${1:?claim.sh requires <task_id>}"
SESSION_ID="${2:-${CLAUDE_SESSION_ID:-"session-$$"}}"

_fail() { echo "error: $1"; exit 2; }

# Guard: must be on the coordination branch. Off it, HEAD diverges from the
# push target and every claim silently looks "lost" — fail loud instead.
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${current_branch}" != "${QUEUE_BRANCH}" ]]; then
    _fail "not on coordination branch '${QUEUE_BRANCH}' (HEAD=${current_branch:-unknown}); run queue_branch.sh first"
fi

_claim_json() {
    python3 - "${TASK_ID}" "${SESSION_ID}" "${QUEUE_FILE}" <<'PY'
import sys, json, pathlib

task_id, session_id, queue_path = sys.argv[1:]
path = pathlib.Path(queue_path)
if not path.exists():
    print("lost")
    sys.exit(0)

rows = []
for line in path.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line:
        try:
            data = json.loads(line)
            if isinstance(data, dict):
                rows.append(data)
        except json.JSONDecodeError:
            pass

target = next(
    (r for r in rows if r.get("id") == task_id and r.get("status") == "open"),
    None,
)
if target is None:
    print("lost")
    sys.exit(0)

target["status"] = "in_progress"
target["assignee"] = session_id
path.write_text(
    "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n",
    encoding="utf-8",
)
print("ok")
print(json.dumps(target))
PY
}

result=$(_claim_json 2>/dev/null)
first="${result%%$'\n'*}"

if [[ "${first}" != "ok" ]]; then
    echo "lost"
    exit 0
fi

task_json="${result#ok$'\n'}"

# Stage, commit, and push to the coordination branch.
git add "${QUEUE_FILE}" 2>/dev/null || { echo "lost"; exit 0; }

if ! git commit -m "claim: ${TASK_ID} → in_progress [${SESSION_ID}]" >/dev/null 2>&1; then
    # Nothing staged or already committed — race lost locally.
    git checkout -- "${QUEUE_FILE}" 2>/dev/null || true
    echo "lost"
    exit 0
fi

# Push the local claim commit to the shared coordination ref. Exactly one
# racer fast-forwards; the rest are rejected non-fast-forward.
if push_err="$(git push origin "HEAD:refs/heads/${QUEUE_BRANCH}" 2>&1)"; then
    echo "won"
    echo "${task_json}"
    exit 0
fi

# Push failed. Unwind the local claim either way: mixed reset (not --hard)
# preserves any uncommitted user files.
git reset HEAD~1 >/dev/null 2>&1 || true
git checkout -- "${QUEUE_FILE}" >/dev/null 2>&1 || true

if printf '%s' "${push_err}" | grep -qiE 'non-fast-forward|fetch first|cannot lock ref|but expected|failed to update ref'; then
    # Remote ref advanced — a genuine race (a plain non-fast-forward, or an
    # atomic ref-update CAS loss: "cannot lock ref … is at X but expected Y").
    # The local claim was already unwound above, so there is nothing to rebase:
    # just resync to the new remote tip (robust against unrelated unstaged
    # files) so the next loop iteration re-evaluates against fresh queue state.
    git fetch origin "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    git reset "origin/${QUEUE_BRANCH}" >/dev/null 2>&1 || true
    git checkout -- "${QUEUE_FILE}" >/dev/null 2>&1 || true
    echo "lost"
    exit 0
fi

# Anything else (protected branch, permission denied, no remote/upstream) is a
# misconfiguration, not a race. Fail loud so the loop stops instead of spinning
# on a deadlock that looks like an endless lost race.
_fail "push to '${QUEUE_BRANCH}' failed (not a race): ${push_err}"
