#!/usr/bin/env bash
# claim_review_test.sh — the review claim keys on the HEAD, not on the PR.
#
# A task is claimed once. A review is about one tree, and a fleet's most common
# review event is the second read after three more pushes. Keying the claim on
# the PR number would make the first reader's ref block every later re-read —
# turning the lock into a lease nobody can release, since a sandboxed session
# cannot delete a ref.
#
# The other thing worth pinning is the exit-code overlap: 1 means `lost`, so a
# usage error that exits 1 makes a session skip a review it should have run.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../skills/init/assets/bin/claim_review.sh"
[[ -f "${SRC}" ]] || { echo "SKIP: claim_review.sh not found at ${SRC}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# The script finds its channel beside itself, so stage a bin dir rather than
# adding a test-only hook. The stub echoes the request back, which is how the
# ref name is inspected without a network.
BIN="${tmp}/bin"
mkdir -p "${BIN}"
cp "${SRC}" "${BIN}/claim_review.sh"
CLAIM="${BIN}/claim_review.sh"
write_stub() {  # write_stub <api-exit-code>
    cat > "${BIN}/github_channel.sh" <<STUB
#!/usr/bin/env bash
case "\${1:-}" in
    --slug)   echo "o/r" ;;
    --detect) echo "rest" ;;
    --api)    echo "REQ \$2 \$3 \$4"; exit $1 ;;
esac
STUB
    chmod +x "${BIN}/github_channel.sh"
}

REPO="${tmp}/repo"
git init -q -b main "${REPO}"
cd "${REPO}" || exit 1
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
git commit -q --allow-empty -m init
git remote add origin https://github.com/o/r.git
HEAD_SHA=$(git rev-parse HEAD)

run() { ARSENAL_DEFAULT_BRANCH=main bash "${CLAIM}" "$@" 2>&1; }

# --- usage errors exit 2, never 1 -------------------------------------------
write_stub 0
for args in "" "42" "notanumber ${HEAD_SHA}" "42 main" "42 zzzz"; do
    # shellcheck disable=SC2086
    run ${args} >/dev/null 2>&1
    [[ $? -eq 2 ]] || fail "bad usage '${args}' must exit 2, not be read as a lost race"
done
echo "PASS: usage errors exit 2, so nothing reads them as a lost race"

# --- the ref carries both the PR and the head -------------------------------
out=$(run 42 "${HEAD_SHA}")
grep -q "^won refs/heads/arsenal/reviews/42-${HEAD_SHA}\$" <<<"${out}" \
    || fail "the claim ref must be <pr>-<head>, got: ${out}"

# A second head of the same PR is a different unit of work and must be
# claimable — the whole reason the sha is in the key.
other=$(git commit -q --allow-empty -m second && git rev-parse HEAD)
out=$(run 42 "${other}")
grep -q "42-${other}" <<<"${out}" || fail "a new head must be separately claimable: ${out}"
echo "PASS: the claim is per head, so a re-read after a push is not blocked"

# --- case does not make two locks out of one --------------------------------
upper=$(printf '%s' "${HEAD_SHA}" | tr '[:lower:]' '[:upper:]')
out=$(run 42 "${upper}")
grep -q "42-${HEAD_SHA}" <<<"${out}" \
    || fail "an upper-case sha must normalise to the same ref: ${out}"
echo "PASS: sha case is normalised before it becomes a key"

# --- 422 is a lost race, not a fault ----------------------------------------
write_stub 3
out=$(run 42 "${HEAD_SHA}"); rc=$?
[[ "${out}" == "lost" && ${rc} -eq 1 ]] \
    || fail "a colliding review claim must report lost/1, got '${out}' (${rc})"
echo "PASS: 422 is reported as lost"

# --- no scriptable channel prints the exact call ----------------------------
write_stub 5
out=$(run 42 "${HEAD_SHA}"); rc=$?
[[ ${rc} -eq 5 ]] || fail "no channel should exit 5, got ${rc}"
grep -q "^manual POST /repos/o/r/git/refs " <<<"${out}" \
    || fail "the manual route must print the call to make: ${out}"
grep -q "42-${HEAD_SHA}" <<<"${out}" || fail "the manual body must carry the ref: ${out}"
echo "PASS: a surface with no channel is handed the request, not skipped"

# --- an unknown sha still claims --------------------------------------------
# A reader dispatched without a fetch does not have the object locally; refusing
# would make the claim unavailable exactly to the session that needs it.
write_stub 0
out=$(run 42 "abc1234")
grep -q "^won refs/heads/arsenal/reviews/42-abc1234\$" <<<"${out}" \
    || fail "a sha not present locally must still be claimable: ${out}"
echo "PASS: an abbreviated or unfetched sha still claims"

echo "PASS: claim_review_test — one reader per head, and no silent skips"
exit 0
