#!/usr/bin/env bash
# ideas_log_test.sh — explore-idea's durable backlog, `status/ideas.md`.
#
# One parser (ideas_log.py) is read three ways: its own `check`, the one line
# query_status.py prints at session start, and validate_spec.py's warning when
# an agreed decision never reached the spec. Each is exercised here, plus the
# rule the file exists for — ids are stable, so one that vanishes is a problem.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPT_DIR}/../skills/init/assets/scripts"
IL="${SCRIPTS}/ideas_log.py"
QS="${SCRIPTS}/query_status.py"
VS="${SCRIPT_DIR}/../skills/specify/scripts/validate_spec.py"
TEMPLATE="${SCRIPT_DIR}/../skills/explore-idea/references/ideas-backlog.md"
for f in "${IL}" "${QS}" "${VS}" "${TEMPLATE}"; do
    [[ -f "${f}" ]] || { echo "FAIL: ${f} not found" >&2; exit 1; }
done

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

repo="${tmp}/repo"
mkdir -p "${repo}/status" "${repo}/tasks"
ideas="${repo}/status/ideas.md"
# The template the skill points at is the fixture: if it stops parsing, the
# skill is teaching a format its own checker rejects.
sed -n '/^```markdown$/,/^```$/p' "${TEMPLATE}" | sed '1d;$d' > "${ideas}"

# --- 1: the shipped template passes its own check ----------------------------
out=$(python3 "${IL}" check --file "${ideas}" 2>&1) || fail "template fails check: ${out}"
echo "PASS: the reference template passes ideas_log.py check"

# --- 2: summary is one line, and silent with no file -------------------------
line=$(python3 "${IL}" summary --file "${ideas}")
[[ "${line}" == "ideas: 1 parked, 1 exploring, 1 sub-projects without spec" ]] \
    || fail "unexpected summary: ${line}"
[[ -z "$(python3 "${IL}" summary --file "${tmp}/absent.md")" ]] \
    || fail "summary printed something with no ideas file"
echo "PASS: summary is one line, and nothing when the file is absent"

# --- 3: query_status prints that line, and only when the file exists --------
board=$(cd "${repo}" && python3 "${QS}" --tasks-dir tasks --no-remote-check 2>/dev/null)
grep -qx "ideas: 1 parked, 1 exploring, 1 sub-projects without spec" <<<"${board}" \
    || fail "query_status did not print the ideas line: ${board}"
mkdir -p "${tmp}/bare/tasks"
board=$(cd "${tmp}/bare" && python3 "${QS}" --tasks-dir tasks --no-remote-check 2>/dev/null)
grep -q "^ideas:" <<<"${board}" && fail "query_status printed an ideas line with no file"
board=$(cd "${repo}" && python3 "${QS}" --tasks-dir tasks --no-remote-check --json 2>/dev/null)
grep -q "^ideas:" <<<"${board}" && fail "query_status --json mixed the ideas line into JSON"
echo "PASS: query_status prints the ideas line only when status/ideas.md exists"

# --- 4: malformed ids and statuses are problems -------------------------------
bad="${tmp}/bad.md"
cat > "${bad}" <<'EOF'
# Ideas backlog
## Groups
### A. Things
- first  (I-1)
- second  (I-1)
- no id at all
## Sub-projects
| ID | Name | Groups | Status | Spec section |
|----|------|--------|--------|--------------|
| S-1 | One | A, Z | someday | |
| S-2 | Two | A | specified | |
## Decision log
| ID | Decision | Status | Date |
|----|----------|--------|------|
| D-1 | Something | maybe | 2026-01-01 |
| D-2 | Other | superseded by D-9 | 2026-01-01 |
EOF
python3 "${IL}" check --file "${bad}" 2>"${tmp}/bad.err" >/dev/null
[[ $? -eq 1 ]] || fail "check passed a malformed file"
for needle in "I-1 is used twice" "idea without an (I-N) id" "status 'someday'" \
    "names group Z" "S-2: specified, but its Spec section cell is empty" \
    "D-1: status 'maybe'" "superseded by D-9, which has no row"; do
    grep -qF "${needle}" "${tmp}/bad.err" || fail "check missed '${needle}': $(cat "${tmp}/bad.err")"
done
python3 "${IL}" summary --file "${bad}" | grep >/dev/null "problem(s)" \
    || fail "summary hid the problems in a malformed file"
echo "PASS: duplicate ids, missing ids, unknown statuses and dangling refs are problems"

# --- 5: --base catches an id that disappeared ---------------------------------
(
    cd "${repo}" && git init -q . && git add status/ideas.md \
        && git -c user.name=t -c user.email=t@example.com commit -qm seed
) || fail "could not seed a git repo"
(cd "${repo}" && python3 "${IL}" check --base HEAD >/dev/null 2>&1) \
    || fail "--base HEAD failed on an unchanged file"
perl -ni -e 'print unless /\(I-2\)$/' "${ideas}"
python3 "${IL}" check --file "${ideas}" --base HEAD >/dev/null 2>"${tmp}/base.err"
[[ $? -eq 1 ]] || fail "--base did not catch a removed id"
grep -q "I-2 was in HEAD and is gone" "${tmp}/base.err" || fail "wrong message: $(cat "${tmp}/base.err")"
(cd "${repo}" && git checkout -q -- status/ideas.md)
echo "PASS: --base fails when an id present in the base revision is gone"

# --- 6: validate_spec warns on an agreed decision missing from the spec ------
spec="${repo}/status/specification.md"
cat > "${spec}" <<'EOF'
# Specification: accounts

**Revision**: 1

## 1. Problem statement

People cannot join without a password. Ideas covered: I-1, I-2.

**Success criteria (measurable)**

- [ ] sign-up completes in under two minutes, judged by a timed walkthrough

## 2. Systems & Impact

The sign-up page and the mailer.

## 3. Options

Email link or passkey.

## 4. Recommendation

Email link.
EOF
out=$(cd "${repo}" && python3 "${VS}" --input status/specification.md) \
    || fail "validate_spec failed a well-formed spec: ${out}"
grep -q "agreed decision(s) D-1 .* are not in this spec" <<<"${out}" \
    || fail "validate_spec did not warn about D-1: ${out}"
printf '\n| D-1 | Web app first, mobile later | agreed | 2026-09-29 |\n' >> "${spec}"
out=$(cd "${repo}" && python3 "${VS}" --input status/specification.md) || fail "validate_spec failed: ${out}"
grep -q "are not in this spec" <<<"${out}" && fail "validate_spec warned after D-1 was cited: ${out}"
perl -ni -e 'print unless eof' "${spec}"   # D-1 uncited again
mv "${ideas}" "${tmp}/ideas.aside"
out=$(cd "${tmp}/bare" && python3 "${VS}" --input "${spec}") || fail "validate_spec failed: ${out}"
grep -q "are not in this spec" <<<"${out}" && fail "validate_spec warned with no ideas file: ${out}"
mv "${tmp}/ideas.aside" "${ideas}"
echo "PASS: validate_spec warns (never fails) when an agreed decision is missing from the spec"

echo "PASS: ideas_log_test.sh"
