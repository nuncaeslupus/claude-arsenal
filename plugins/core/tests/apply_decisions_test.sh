#!/usr/bin/env bash
# apply_decisions_test.sh — acting on the human's digest decisions (review-digest P2, T4).
#
# A decision is about the commit the human saw: an approval of a head that has
# since moved must do nothing. Merges follow dependencies, and a denied
# dependency holds its dependents back instead of merging them on top of nothing.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${here}/../skills/init/assets"
[[ -f "${ASSETS}/scripts/apply_decisions.py" ]] || { echo "FAIL: apply_decisions.py not found" >&2; exit 1; }

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# A private copy of the scripts, with GitHub and merge_ready stubbed: every call
# the script makes lands in calls.log.
mkdir -p "${tmp}/bin" "${tmp}/scripts" "${tmp}/repo/arsenal"
cp "${ASSETS}"/scripts/{apply_decisions,digest,review_policy,arsenal_config}.py "${tmp}/scripts/"
cat > "${tmp}/bin/github_channel.sh" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    --slug) echo "o/r" ;;
    --api)  echo "$2 $3 ${4:-}" >> "${CALLS}"; [[ "$2" == "GET" ]] && cat "${PRDIR}/pr-${3##*/}.json"; exit 0 ;;
esac
STUB
printf '#!/usr/bin/env bash\necho READY; echo "--- merge commit body ---"; echo "Risk-tier: low"\n' > "${tmp}/bin/merge_ready.sh"
APPLY="${tmp}/scripts/apply_decisions.py"
export CALLS="${tmp}/calls.log" PRDIR="${tmp}"
cd "${tmp}/repo" || exit 1

# Three open PRs: 11 depends on 10, 12 is independent; 13 is merged and awaits ratification.
mk() {  # mk <n> <head> <state> <merged> <deps>
    python3 - "$@" <<'PY'
import json, sys
n, head, state, merged, deps = sys.argv[1:]
rec = {"v": 1, "pr": int(n), "head": head[:7], "deps": json.loads(deps), "state": "x", "questions": []}
print(json.dumps({"number": int(n), "title": f"PR {n}", "state": state, "merged": merged == "1",
                  "head": {"sha": head}, "merge_commit_sha": "c" * 40 if merged == "1" else None,
                  "body": "intro\n\n<!-- arsenal-digest\n" + json.dumps(rec) + "\n-->"}))
PY
}
mk 10 aaaaaaa111 open 0 '[]' > "${tmp}/pr-10.json"
mk 11 bbbbbbb222 open 0 '[10]' > "${tmp}/pr-11.json"
mk 12 ccccccc333 open 0 '[]' > "${tmp}/pr-12.json"
mk 13 ddddddd444 closed 1 '[]' > "${tmp}/pr-13.json"
python3 -c 'import json,sys; print(json.dumps([json.load(open(f)) for f in sys.argv[1:]]))' "${tmp}"/pr-1{0,1,2,3}.json > "${tmp}/prs.json"

dec() {  # dec <json> → a decisions file
    printf '# Review decisions\n\n<!-- ARSENAL-DECISIONS %s -->\n' "$1" > "${tmp}/d.md"
}

# --- planning (dry run) ---------------------------------------------------------
dec '{"10":{"decision":"approve","head":"aaaaaaa111"},"11":{"decision":"approve","head":"bbbbbbb222"},"12":{"decision":"approve","head":"ccccccc"}}'
out="$(python3 "${APPLY}" "${tmp}/d.md" --dry-run --prs-json "${tmp}/prs.json")"
grep -q "#12 stale" <<<"${out}" || fail "test_stale_approval_not_merged: ${out}"
grep -q "#12 merge" <<<"${out}" && fail "a stale approval must not be merged"
[[ "$(grep -o '#1[01] merge' <<<"${out}" | tr '\n' ' ')" == "#10 merge #11 merge " ]] \
    || fail "test_merge_order_follows_deps: ${out}"

dec '{"10":{"decision":"deny","head":"aaaaaaa111","note":"split"},"11":{"decision":"approve","head":"bbbbbbb222"}}'
out="$(python3 "${APPLY}" "${tmp}/d.md" --dry-run --prs-json "${tmp}/prs.json")"; rc=$?
grep -q "#11 blocked — waits on #10, which was denied" <<<"${out}" || fail "test_denied_dep_blocks_dependent: ${out}"
grep -q "#10 close" <<<"${out}" || fail "a denied open PR should be closed"
[[ ${rc} -eq 1 ]] || fail "a blocked PR should make the run exit 1"

out="$(python3 "${APPLY}" --text "approve 13; question 12: why a new dep?" --dry-run --prs-json "${tmp}/prs.json" 2>&1)"
grep -q "#13 stale" <<<"${out}" || fail "typed approve with no recorded head must be stale: ${out}"
mkdir -p arsenal/session && printf '{"heads":{"13":"ddddddd444"}}' > arsenal/session/digest.json
out="$(python3 "${APPLY}" --text "approve 13; question 12: why a new dep?" --dry-run --prs-json "${tmp}/prs.json")"
grep -q "#13 ratify" <<<"${out}" && grep -q "#12 ask — why a new dep?" <<<"${out}" \
    || fail "typed decisions should use the digest's heads: ${out}"
python3 "${APPLY}" --text "merge 12" --dry-run --prs-json "${tmp}/prs.json" >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "an unknown verb is bad input"
# A dependency chain: deny 10 blocks 11, and 11 not merging blocks 14 (deps [11]).
mk 14 eeeeeee555 open 0 '[11]' > "${tmp}/pr-14.json"
python3 -c 'import json,sys; print(json.dumps([json.load(open(f)) for f in sys.argv[1:]]))' "${tmp}"/pr-1{0,1,2,3,4}.json > "${tmp}/prs.json"
printf '{"heads":{"11":"bbbbbbb222","14":"eeeeeee555","10":"aaaaaaa111"}}' > arsenal/session/digest.json
out="$(python3 "${APPLY}" --text "deny 10: big; split it
approve 11
approve 14" --dry-run --prs-json "${tmp}/prs.json" 2>&1)"
grep -q "#10 close — big; split it" <<<"${out}" || fail "a ';' inside a note must stay in the note: ${out}"
grep -q "#14 blocked — waits on #11" <<<"${out}" || fail "a blocked dep must block its dependents: ${out}"
# A dep merged earlier, with no decision of its own, satisfies its dependent.
mk 15 fffffff666 open 0 '[13]' > "${tmp}/pr-15.json"
python3 -c 'import json,sys; print(json.dumps([json.load(open(f)) for f in sys.argv[1:]]))' "${tmp}"/pr-1{0,1,2,3,4,5}.json > "${tmp}/prs.json"
printf '{"heads":{"15":"fffffff666"}}' > arsenal/session/digest.json
out="$(python3 "${APPLY}" --text "approve 15" --dry-run --prs-json "${tmp}/prs.json")"
grep -q "#15 merge" <<<"${out}" || fail "a dep already merged must not block: ${out}"
echo "PASS: plan — stale heads, dependency order, denied deps, typed decisions"

# --- execution against the stub -------------------------------------------------
: > "${CALLS}"
dec '{"10":{"decision":"approve","head":"aaaaaaa111"},"12":{"decision":"question","head":"ccccccc333","note":"why?"}}'
python3 "${APPLY}" "${tmp}/d.md" >/dev/null || fail "execution failed: $(cat "${CALLS}")"
grep -q 'POST /repos/o/r/issues/10/comments .*arsenal-decision: approve head=aaaaaaa111 via=digest' "${CALLS}" \
    || fail "an approval should post the SHA-bound marker: $(cat "${CALLS}")"
grep -q 'PUT /repos/o/r/pulls/10/merge .*"sha": "aaaaaaa111"' "${CALLS}" || fail "the merge should pin the head"
grep -q 'PATCH /repos/o/r/pulls/12 .*why?' "${CALLS}" || fail "a question should land in the record"
echo "PASS: execute — marker, pinned merge, question recorded"

echo "PASS: apply_decisions_test — all gates passed"
