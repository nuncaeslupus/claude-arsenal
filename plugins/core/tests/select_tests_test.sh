#!/usr/bin/env bash
# select_tests_test.sh — select_tests.py picks the tests a change touches, and
# falls back to every test whenever it cannot place a change.
#
# The fallback is the property worth pinning: a selector that returned a short
# list for a file it could not map would skip a test silently, which is the one
# failure a preflight gate must not have. Speed is the secondary claim.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEL="${SCRIPT_DIR}/../skills/init/assets/bin/select_tests.py"
[[ -f "${SEL}" ]] || { echo "SKIP: ${SEL} not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $*"; }

cd "${tmp}"
git init -q -b main .
mkdir -p src/pkg tests docs a b
touch src/pkg/foo.py src/pkg/bar.py src/pkg/orphan.py docs/guide.md a/conf.py b/conf.py pyproject.toml
echo 'import pkg.foo' > tests/test_foo.py
echo 'covers bar'     > tests/bar_extra_test.py
echo 'reads b/conf.py' > tests/test_settings.py
echo 'scans the tree' > tests/test_lint_all.py
git add -A && git -c user.email=t@x -c user.name=t commit -qm init

run() { ARSENAL_CHANGED_FILES="$1" python3 "${SEL}" --tests 'tests/**/test_*.py' \
        --tests 'tests/*_test.py' --ignore 'docs/*' --always pyproject.toml "${@:2}" 2>/dev/null \
        | tr '\n' ' ' | sed 's/ $//'; }
ALL="tests/bar_extra_test.py tests/test_foo.py tests/test_lint_all.py tests/test_settings.py"

[[ "$(run src/pkg/foo.py)" == "tests/test_foo.py" ]] || fail "foo.py -> test_foo.py, got: $(run src/pkg/foo.py)"
pass "a source file selects the test named after it"
[[ "$(run src/pkg/bar.py)" == "tests/bar_extra_test.py" ]] || fail "bar.py prefix match, got: $(run src/pkg/bar.py)"
pass "a test named <stem>_<more>_test matches by prefix"
[[ "$(run tests/test_settings.py)" == "tests/test_settings.py" ]] || fail "a changed test selects itself"
pass "a changed test selects itself"
[[ "$(run b/conf.py)" == "tests/test_settings.py" ]] || fail "b/conf.py by parent/basename, got: $(run b/conf.py)"
pass "a non-unique basename matches on parent/basename, not on the twin"
[[ "$(run src/pkg/orphan.py)" == "${ALL}" ]] || fail "an unmapped file must select every test"
pass "a file no test maps to selects every test"
[[ "$(run pyproject.toml)" == "${ALL}" ]] || fail "--always must select every test"
pass "an --always match selects every test"
[[ "$(run '')" == "${ALL}" ]] || fail "no changed files must select every test"
pass "no changed files selects every test"
[[ -z "$(run docs/guide.md)" ]] || fail "an --ignore-only change selects nothing"
pass "an --ignore-only change selects nothing"
[[ "$(run docs/guide.md --include 'tests/test_lint_*')" == "tests/test_lint_all.py" ]] \
    || fail "--include must add tree-scanning tests"
[[ "$(run src/pkg/foo.py --include 'tests/test_lint_*')" == "tests/test_foo.py tests/test_lint_all.py" ]] \
    || fail "--include must ride along with a selection"
pass "--include tests run with every selection"
why=$(ARSENAL_CHANGED_FILES=src/pkg/orphan.py python3 "${SEL}" --tests 'tests/*' 2>&1 >/dev/null)
[[ "${why}" == *"no test maps to src/pkg/orphan.py"* ]] || fail "the fallback must say why: ${why}"
pass "the fallback names the file that caused it"

[[ -z "$(ARSENAL_CHANGED_FILES= python3 "${SEL}" --tests 'src/*.py' 2>/dev/null)" ]] \
    || fail "a single * must not cross a directory"
[[ -n "$(ARSENAL_CHANGED_FILES= python3 "${SEL}" --tests 'src/**/*.py' 2>/dev/null)" ]] \
    || fail "** must cross directories"
pass "globs are shell-style: * stays in one directory, ** spans them"

# Without ARSENAL_CHANGED_FILES it reads the diff against --base itself.
git checkout -qb feature && echo x >> src/pkg/foo.py
[[ "$(python3 "${SEL}" --tests 'tests/**/test_*.py' --base main 2>/dev/null)" == "tests/test_foo.py" ]] \
    || fail "the git-diff path must see an uncommitted change"
pass "with no file list it diffs against --base, uncommitted changes included"

cd / && python3 "${SEL}" --tests '*' >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "outside a repo must exit 2"
pass "outside a git repository it exits 2"
echo "=== select_tests_test: all passed ==="
