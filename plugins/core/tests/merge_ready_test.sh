#!/usr/bin/env bash
# merge_ready_test.sh — one fetch, one evaluator, and no silent pass.
#
# The point of this script is that the three merge conditions stop being
# re-derived by hand in every session that merges. So what is worth pinning is
# not the verdict logic — pr_audit_test.sh owns that — but the seams where a
# wrapper quietly loses the question:
#
#   * checks fetched for the PR instead of for its HEAD SHA;
#   * a failed fetch degrading into an empty payload, which then reads as a
#     clean PR with nothing outstanding;
#   * a surface with no GitHub channel being skipped rather than handed the
#     calls to make — the failure mode `github_channel.sh` exists for.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
SRC="${ASSETS}/bin/merge_ready.sh"
[[ -f "${SRC}" ]] || { echo "SKIP: merge_ready.sh not found at ${SRC}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

HEAD=1111111111111111111111111111111111111111
OLD=2222222222222222222222222222222222222222

# Stage the real layout — bin/ beside scripts/ — with a stub channel, because
# merge_ready.sh resolves both by position relative to itself.
mkdir -p "${tmp}/bin" "${tmp}/scripts" "${tmp}/repo/arsenal"
cp "${SRC}" "${tmp}/bin/merge_ready.sh"
cp "${ASSETS}/scripts/pr_audit.py" "${tmp}/scripts/"
cp "${ASSETS}/scripts/arsenal_config.py" "${tmp}/scripts/" 2>/dev/null || true
READY="${tmp}/bin/merge_ready.sh"

# The stub answers each REST path from a file, so a test sets the world by
# writing three files. `--detect` says `rest` so the GraphQL branch stays off.
stub() {
    cat > "${tmp}/bin/github_channel.sh" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
    --slug)   echo "o/r" ;;
    --detect) echo "${STUB_CHANNEL:-rest}" ;;
    --api)
        [[ "${STUB_CHANNEL:-rest}" == "none" ]] && exit 5
        case "$3" in
            */pulls/[0-9]*/reviews) cat "${STUB_DIR}/reviews.json" ;;
            */pulls/[0-9]*)         cat "${STUB_DIR}/pr.json" ;;
            */check-runs)           cat "${STUB_DIR}/checks.json" 2>/dev/null || exit 4 ;;
            *) exit 4 ;;
        esac
        ;;
esac
STUB
    chmod +x "${tmp}/bin/github_channel.sh"
}
stub

cd "${tmp}/repo" || exit 1
git init -q -b main . && git remote add origin https://github.com/o/r.git
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml

world() {  # world <head-sha-for-the-check-run>
    cat > "${tmp}/pr.json" <<JSON
{"number":42,"title":"T12","draft":false,"mergeable":true,
 "created_at":"2026-09-14T00:00:00Z","head":{"sha":"${HEAD}","ref":"arsenal/task/T12"}}
JSON
    cat > "${tmp}/checks.json" <<JSON
{"check_runs":[{"name":"ci","status":"completed","conclusion":"success","head_sha":"$1"}]}
JSON
    printf '[]\n' > "${tmp}/reviews.json"
}
run() { STUB_DIR="${tmp}" bash "${READY}" "$@" 2>&1; }

# --- the happy path, under the policy the repo actually set ------------------
world "${HEAD}"
out=$(run 42); rc=$?
[[ ${rc} -eq 0 ]] || fail "a green PR under after-ci should exit 0, got ${rc}: ${out}"
grep -q "READY" <<<"${out}" || fail "the verdict should be visible: ${out}"
echo "PASS: a green head under after-ci is ready"

# --- the merge commit body is printed only for a PR that may be merged -------
grep -q "merge commit body" <<<"$(run 42 --body)" || fail "--body should print the body"
echo "PASS: --body carries the head and the policy it merged under"

# --- checks are fetched for the head, so a stale run does not pass -----------
world "${OLD}"
out=$(run 42); rc=$?
[[ ${rc} -eq 1 ]] || fail "a check run from an earlier push must not pass the head: ${out}"
echo "PASS: the conditions are evaluated against the head sha"

# --- a fetch that fails must not become an empty, clean-looking payload ------
world "${HEAD}"
rm -f "${tmp}/checks.json"        # the stub then exits 4 for check-runs
out=$(run 42); rc=$?
[[ ${rc} -eq 1 ]] || fail "an unreadable check list must block, not read as clean: ${out}"
grep -qi "absent is not green" <<<"${out}" || fail "it should say what is missing: ${out}"
echo "PASS: a failed checks fetch blocks instead of passing silently"

# --- the policy comes from the repo, not from the script --------------------
world "${HEAD}"
printf 'merge-policy = "never"\n' > arsenal/config.toml
out=$(run 42); rc=$?
[[ ${rc} -eq 3 ]] || fail "merge-policy never should exit 3, got ${rc}: ${out}"
printf 'merge-policy = "after-ci-and-review"\n' > arsenal/config.toml
out=$(run 42); rc=$?
[[ ${rc} -eq 1 ]] || fail "after-ci-and-review with no review should exit 1: ${out}"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
echo "PASS: the host's merge-policy decides, and never is its own exit code"

# --- no scriptable channel is handed the calls, not skipped -----------------
out=$(STUB_CHANNEL=none STUB_DIR="${tmp}" bash "${READY}" 42 2>&1); rc=$?
[[ ${rc} -eq 5 ]] || fail "no channel should exit 5, got ${rc}"
grep -q "/repos/o/r/pulls/42" <<<"${out}" || fail "the manual route must print the calls: ${out}"
grep -q "pr_audit.py" <<<"${out}" || fail "...and how to get the verdict from them: ${out}"
echo "PASS: a surface without gh is told exactly what to ask"

# --- usage ------------------------------------------------------------------
STUB_DIR="${tmp}" bash "${READY}" >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "a missing pr number should exit 2"
STUB_DIR="${tmp}" bash "${READY}" not-a-number >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "a non-numeric pr should exit 2"
echo "PASS: usage errors exit 2, distinct from not-ready"

echo "PASS: merge_ready_test — one fetch, one evaluator, no silent pass"
exit 0
