#!/usr/bin/env bash
# open_task_pr_args_test.sh — argument validation (#352) and branch-slug
# normalisation (#350) for open_task_pr.sh.
#
# Both bugs shipped because the script accepted, silently, input it could not
# represent: an unknown option became the PR subject and got merged, and a
# non-ASCII title became a branch name `git push` refuses. Neither needs a
# remote, so these cases run against the script's front half only — everything
# here is asserted before the first git operation.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/../skills/init/assets/bin/open_task_pr.sh"

if [[ ! -f "${HELPER}" ]]; then
    echo "SKIP: open_task_pr.sh not found at ${HELPER}" >&2; exit 0
fi

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- #352: an unknown option must never become the title ---------------------
# The exact call that merged `tmp/pr-cf3d.md: --body-file` into a consumer's
# main. It has to be refused before anything touches git.
out="$(bash "${HELPER}" lo-cf3d --body-file tmp/pr.md --message-file tmp/msg.txt 2>&1)"
rc=$?
[[ "${rc}" -eq 1 ]] || fail "the reported call exited ${rc}, expected 1"
grep -q "unknown option: --message-file" <<<"${out}" \
    || fail "an unknown option was not named in the error: ${out}"
grep -q "usage: open_task_pr.sh" <<<"${out}" || fail "no usage printed on a bad option"
echo "PASS: an unknown option is refused, not taken as the PR title"

# A single dash-leading argument in the title position is the same mistake.
out="$(bash "${HELPER}" lo-cf3d --title 2>&1)"; rc=$?
[[ "${rc}" -eq 1 ]] || fail "--title with no value exited ${rc}, expected 1"
grep -q -- "--title needs a value" <<<"${out}" || fail "--title with no value not reported: ${out}"
echo "PASS: an option missing its value is refused"

# --- a missing required argument still says which one ------------------------
out="$(bash "${HELPER}" 2>&1)"; rc=$?
[[ "${rc}" -eq 1 ]] || fail "no arguments exited ${rc}, expected 1"
grep -q "requires <task_id>" <<<"${out}" || fail "missing task_id not reported: ${out}"
out="$(bash "${HELPER}" lo-x 2>&1)"; rc=$?
grep -q "requires <title>" <<<"${out}" || fail "missing title not reported: ${out}"
echo "PASS: a missing positional argument is named"

# --- #352 item 3: --help exists and exits 0 ----------------------------------
out="$(bash "${HELPER}" --help 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "--help exited ${rc}, expected 0"
grep -q -- "--body-file <path>" <<<"${out}" || fail "--help does not document --body-file"
echo "PASS: --help prints the invocation form"

# --- too many positionals are a usage error, not a silently dropped argument --
out="$(bash "${HELPER}" a b c d 2>&1)"; rc=$?
[[ "${rc}" -eq 1 ]] || fail "four positionals exited ${rc}, expected 1"
grep -q "too many arguments" <<<"${out}" || fail "extra positionals not reported: ${out}"
echo "PASS: a fourth positional argument is refused"

# --- #350: the slug is [a-z0-9-] under any locale ----------------------------
# The pipeline is extracted verbatim from the helper so the assertion tracks the
# real code. Under a UTF-8 locale glibc collates accented letters inside `a-z`,
# so the pre-fix pipeline let them through; the runners are C.UTF-8, which is
# why CI never saw it. Asserting the invariant catches it on every locale,
# including the ones a test machine cannot install.
_slug() {
    export LC_ALL=C
    printf '%s' "$1" | tr -d '\n\r' \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 \
        | sed -E 's/[^a-z0-9-]+//g; s/-+$//'
}
grep -q "s/\[^a-z0-9-\]+//g; s/-+\$//" "${HELPER}" \
    || fail "the helper no longer carries the C-locale normalisation pass this test asserts"

# Titles that broke a real branch: an accent far from the cut, an accent landing
# on byte 40, a title that is entirely non-ASCII, and a trailing newline.
while IFS= read -r title; do
    [[ -z "${title}" ]] && continue
    for loc in C C.UTF-8 en_US.UTF-8 es_ES.UTF-8; do
        slug="$(LC_ALL="${loc}" bash -c "$(declare -f _slug); _slug \"\$1\"" _ "${title}" 2>/dev/null)"
        [[ "${slug}" =~ ^[a-z0-9-]*$ ]] \
            || fail "locale ${loc}: slug for '${title}' is not [a-z0-9-]: $(printf '%s' "${slug}" | cat -v)"
        [[ "${#slug}" -le 40 ]] || fail "locale ${loc}: slug for '${title}' exceeds 40 chars"
        [[ "${slug}" != *-- ]] || fail "locale ${loc}: slug for '${title}' has a doubled hyphen tail"
    done
done <<'TITLES'
D 20-40 Adjudicaciones huérfanas en SOS
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaé x
Ñandú ÁÉÍÓÚ — reforma del régimen
ÜBERPRÜFUNG
TITLES
echo "PASS: the branch slug is [a-z0-9-] and capped, on every locale tested"

# A title with nothing usable still yields a branch name.
[[ "$(_slug '——')" == "" ]] || fail "an all-punctuation title should reduce to empty before the fallback"
grep -q 'slug="task"' "${HELPER}" || fail "the empty-slug fallback is gone"
echo "PASS: an unusable title falls back to a fixed slug"

echo "PASS: open_task_pr_args_test — all gates passed"
exit 0
