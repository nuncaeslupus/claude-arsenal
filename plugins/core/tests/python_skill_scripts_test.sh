#!/usr/bin/env bash
# python_skill_scripts_test.sh — one behaviour check per python-section skill script.
#
# Each script has real logic (it guards a PyPI upload, classifies a lockfile diff,
# ranks coverage gaps, ...) and none was named by any test (#612). Every check
# asserts the one decision that script exists to make.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail
SK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
# jget <json> <python expr over d>
jget() { python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(eval(sys.argv[2]))' "$1" "$2"; }

# --- validate_release.py: a stale artifact and a version drift are both named ----
mkdir -p "${tmp}/rel/src/pkg" "${tmp}/rel/dist"
printf '[project]\nname="pkg"\nversion="1.2.0"\n' > "${tmp}/rel/pyproject.toml"
echo '__version__ = "1.1.0"' > "${tmp}/rel/src/pkg/__init__.py"
touch "${tmp}/rel/dist/pkg-1.1.0-py3-none-any.whl" "${tmp}/rel/dist/pkg-1.2.0.tar.gz"
out=$(cd "${tmp}/rel" && python3 "${SK}/pypi-release/scripts/validate_release.py" --tag v1.2.0) || fail "validate_release failed"
[[ "$(jget "${out}" 'd["version_consistent"]')" == False ]] || fail "validate_release missed pyproject/__version__ drift"
[[ "$(jget "${out}" 'd["dist"]["stale"]')" == "['pkg-1.1.0-py3-none-any.whl']" ]] || fail "validate_release: stale wheel not flagged: ${out}"
[[ "$(jget "${out}" 'd["tag_matches_version"]')" == True ]] || fail "validate_release: v1.2.0 should match 1.2.0"
(cd "${tmp}" && python3 "${SK}/pypi-release/scripts/validate_release.py" >/dev/null 2>&1); [[ $? -eq 2 ]] \
    || fail "validate_release must exit 2 without a pyproject.toml"
echo "PASS: validate_release names drift and stale artifacts"

# --- compare_lockfile.py: bump / add / remove, direct vs transitive ---------------
mkdir "${tmp}/lock"
printf '[project]\nname="app"\ndependencies=["a>=1"]\n' > "${tmp}/lock/pyproject.toml"
printf 'version=1\n[[package]]\nname="a"\nversion="1.0"\n[[package]]\nname="t"\nversion="2.0"\n' > "${tmp}/lock/before"
printf 'version=1\n[[package]]\nname="a"\nversion="1.1"\n[[package]]\nname="n"\nversion="3.0"\n' > "${tmp}/lock/after"
out=$(cd "${tmp}/lock" && python3 "${SK}/dep-upgrade/scripts/compare_lockfile.py" before after) || fail "compare_lockfile failed"
[[ "$(jget "${out}" '(d["direct_changes"], d["transitive_changes"])')" == "(1, 0)" ]] || fail "compare_lockfile: direct bump miscounted: ${out}"
[[ "$(jget "${out}" '[x["name"] for x in d["added"]]+[x["name"] for x in d["removed"]]')" == "['n', 't']" ]] \
    || fail "compare_lockfile: added/removed wrong: ${out}"
echo "PASS: compare_lockfile classifies bumps, additions and removals"

# --- analyze_coverage.py: contiguous runs, ranked by gap size ---------------------
mkdir "${tmp}/cov"
echo '{"files":{"b.py":{"summary":{"num_statements":10,"percent_covered":90.0,"missing_lines":1},"missing_lines":[4]},
"a.py":{"summary":{"num_statements":10,"percent_covered":50.0,"missing_lines":5},"missing_lines":[1,2,3,7,9]}}}' > "${tmp}/cov/coverage.json"
out=$(cd "${tmp}/cov" && python3 "${SK}/coverage-gaps/scripts/analyze_coverage.py") || fail "analyze_coverage failed"
[[ "$(jget "${out}" 'd["gaps"][0]["file"]')" == a.py ]] || fail "analyze_coverage: biggest gap not first: ${out}"
[[ "$(jget "${out}" 'd["gaps"][0]["missing_runs"]')" == "[[1, 3], [7, 7], [9, 9]]" ]] || fail "analyze_coverage: runs not collapsed: ${out}"
(cd "${tmp}/cov" && python3 "${SK}/coverage-gaps/scripts/analyze_coverage.py" --input nope.json >/dev/null 2>&1); [[ $? -eq 2 ]] \
    || fail "analyze_coverage must exit 2 on a missing report"
echo "PASS: analyze_coverage ranks gaps and collapses contiguous runs"

# --- analyze_project.py: a bare project is reported with what it lacks ------------
mkdir "${tmp}/proj"
printf '[project]\nname="x"\nrequires-python=">=3.12"\n' > "${tmp}/proj/pyproject.toml"
out=$(python3 "${SK}/python-bootstrap/scripts/analyze_project.py" "${tmp}/proj") || fail "analyze_project failed"
[[ "$(jget "${out}" '(d["mode"], d["requires_python_ok"], d["ruff"]["present"])')" == "('retrofit', True, False)" ]] \
    || fail "analyze_project: wrong verdict on a bare project: ${out}"
[[ "$(jget "${out}" '"lint" in d["makefile"]["missing_targets"]')" == True ]] || fail "analyze_project: missing Makefile targets not listed"
printf 'not [toml' > "${tmp}/proj/pyproject.toml"
python3 "${SK}/python-bootstrap/scripts/analyze_project.py" "${tmp}/proj" >/dev/null 2>&1; [[ $? -eq 2 ]] \
    || fail "analyze_project must exit 2 on malformed pyproject.toml"
echo "PASS: analyze_project reports the gaps against the defaults"

# --- create_handoff.py: writes the template, refuses to clobber without --force ---
(cd "${tmp}" && python3 "${SK}/session-end/scripts/create_handoff.py" --output h/handoff.md 2>/dev/null) || fail "create_handoff failed"
grep -q "^# Handoff" "${tmp}/h/handoff.md" || fail "create_handoff wrote no template"
echo kept > "${tmp}/h/handoff.md"
(cd "${tmp}" && python3 "${SK}/session-end/scripts/create_handoff.py" --output h/handoff.md 2>/dev/null); [[ $? -eq 1 ]] \
    || fail "create_handoff must exit 1 when it would overwrite"
[[ "$(cat "${tmp}/h/handoff.md")" == kept ]] || fail "create_handoff overwrote without --force"
(cd "${tmp}" && python3 "${SK}/session-end/scripts/create_handoff.py" --output h/handoff.md --force 2>/dev/null) || fail "--force failed"
grep -q "^# Handoff" "${tmp}/h/handoff.md" || fail "--force did not rewrite"
echo "PASS: create_handoff never overwrites without --force"

# --- query_project_type.py: classic wins, v2 by count, marker written once --------
mkdir -p "${tmp}/gh-bin"
cat > "${tmp}/gh-bin/gh" <<'GH'
#!/usr/bin/env bash
# a stub gh: GH_STUB_CLASSIC=1 answers the classic-projects call, GH_STUB_V2=n the graphql count
case "$*" in
    *"/projects"*) [[ "${GH_STUB_CLASSIC:-0}" == 1 ]] && { echo '[{"id":1}]'; exit 0; }; echo '{"message":"Not Found"}'; exit 1 ;;
    *graphql*) echo "{\"data\":{\"repository\":{\"projectsV2\":{\"totalCount\":${GH_STUB_V2:-0}}}}}" ;;
esac
GH
chmod +x "${tmp}/gh-bin/gh"
QPT="${SK}/github/scripts/query_project_type.py"
q() { PATH="${tmp}/gh-bin:${PATH}" python3 "${QPT}" --repo o/r "$@" 2>/dev/null; }
[[ "$(GH_STUB_CLASSIC=1 GH_STUB_V2=3 q)" == classic ]] || fail "query_project_type: classic should win"
[[ "$(GH_STUB_V2=3 q)" == v2 ]] || fail "query_project_type: v2 not detected"
[[ "$(GH_STUB_V2=0 q)" == none ]] || fail "query_project_type: none not detected"
printf '# Host\n' > "${tmp}/CLAUDE.md"
GH_STUB_V2=3 q --write-claude-md --claude-md "${tmp}/CLAUDE.md" >/dev/null
GH_STUB_V2=0 q --write-claude-md --claude-md "${tmp}/CLAUDE.md" >/dev/null
[[ "$(grep -c 'github-skill: projects=' "${tmp}/CLAUDE.md")" == 1 ]] || fail "marker duplicated instead of updated"
grep -q "projects=none" "${tmp}/CLAUDE.md" || fail "marker not updated to the new answer"
echo "PASS: query_project_type detects the project kind and keeps one marker"

# --- analyze_mutmut.py: survivors are classified, equivalents are not 'gaps' ------
mkdir -p "${tmp}/mm/mutants" "${tmp}/mm/bin"
cat > "${tmp}/mm/bin/mutmut" <<'MM'
#!/usr/bin/env bash
case "$1" in
    results) printf 'pkg.mod.x_f__mutmut_1: survived\npkg.mod.x_g__mutmut_2: survived\npkg.mod.x_h__mutmut_3: killed\n' ;;
    show)    case "$2" in
                 *x_f__mutmut_1) printf -- '--- a\n+++ b\n-    y = cast(int, v)\n+    y = cast(None, v)\n' ;;
                 *) printf -- '--- a\n+++ b\n-    s = "hello"\n+    s = "XXhelloXX"\n' ;;
             esac ;;
esac
MM
chmod +x "${tmp}/mm/bin/mutmut"
out=$(cd "${tmp}/mm" && python3 "${SK}/mutmut-report/scripts/analyze_mutmut.py" --venv "${tmp}/mm" 2>/dev/null) || fail "analyze_mutmut failed"
grep -q "Total surviving mutants: 2" <<<"${out}" || fail "analyze_mutmut counted killed mutants: ${out}"
grep -q "Real gaps  (tests needed):  1" <<<"${out}" || fail "analyze_mutmut: the XX string mutant is a real gap: ${out}"
grep -q "Equivalent (accept):        1" <<<"${out}" || fail "analyze_mutmut: cast() mutant is equivalent: ${out}"
(cd "${tmp}" && python3 "${SK}/mutmut-report/scripts/analyze_mutmut.py" >/dev/null 2>&1); [[ $? -eq 1 ]] \
    || fail "analyze_mutmut must exit 1 without a mutants/ directory"
echo "PASS: analyze_mutmut separates real gaps from equivalent mutants"
