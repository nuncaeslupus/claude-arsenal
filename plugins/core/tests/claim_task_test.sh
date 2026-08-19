#!/usr/bin/env bash
# claim_task_test.sh — the claim ref IS the lock, so the key must not be movable.
#
# The attempt suffix exists because a sandboxed session cannot delete a claim
# ref, so a crashed claim would otherwise block a task forever. But the escape
# hatch and the lock shared a key: any attempt other than 1 targets a ref nobody
# contends for, so GitHub's 422-on-existing-ref — the entire arbitration — is
# evaluated against the wrong name and a retry reports `won` while another
# session holds the task.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAIM="${SCRIPT_DIR}/../skills/init/assets/bin/claim_task.sh"
[[ -f "${CLAIM}" ]] || { echo "SKIP: ${CLAIM} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# A stub channel: --slug answers, and every ref creation is a collision (422 →
# exit 3), which is what GitHub returns when the ref already exists.
# claim_task.sh finds its channel beside itself, so stage a bin dir with the
# real script and a stub channel rather than adding a test-only hook to it.
BIN="${tmpdir}/bin"
mkdir -p "${BIN}"
cp "${CLAIM}" "${BIN}/claim_task.sh"
CLAIM="${BIN}/claim_task.sh"
STUB="${BIN}/github_channel.sh"
cat > "${STUB}" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    --slug)   echo "o/r" ;;
    --detect) echo "rest" ;;
    --api)    echo '{"message":"Reference already exists"}'; exit 3 ;;
esac
EOF
chmod +x "${STUB}"

REPO="${tmpdir}/repo"
git init -q -b main "${REPO}"
cd "${REPO}"
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
git commit -q --allow-empty -m init
git remote add origin https://github.com/o/r.git

run() { ARSENAL_DEFAULT_BRANCH=main bash "${CLAIM}" "$@" 2>&1; }

# --- 1: a contended base ref is reported lost, not won ---
out=$(run t-lock1); rc=$?
[[ "${out}" == "lost" ]] || fail "a colliding claim must report lost, got '${out}' (exit ${rc})"

# --- 2: a bare retry must NOT sidestep the lock ---
out=$(run t-lock1 2); rc=$?
grep -q '^won' <<<"${out}" && fail "attempt 2 must not win a task another session holds: ${out}"
[[ ${rc} -eq 2 ]] || fail "a refused retry should exit 2 (misconfiguration), got ${rc}"
grep -qi "stale" <<<"${out}" || fail "the refusal should say what to establish first: ${out}"

# --- 3: the escape hatch still exists, but has to be asked for ---
#     A crashed claim must not block a task forever; the point is that stepping
#     past a live claim is now a deliberate act rather than a second argument.
out=$(ARSENAL_CLAIM_STALE_OK=1 ARSENAL_DEFAULT_BRANCH=main \
        bash "${CLAIM}" t-lock1 2 2>&1)
grep -qi "bypassing the base claim" <<<"${out}" || fail "the bypass should announce itself: ${out}"

echo "PASS: claim_task_test — all gates passed"
