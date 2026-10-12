#!/usr/bin/env bash
# repo_health_test.sh — repo_health.py against a fake `gh` and a file:// PyPI, offline.
#
# What must hold:
#   * a bare public repo reports every gap, each with a fix command
#   * a repo with everything set reports nothing and `outcome: ok`
#   * a PyPI project that does not link back is a NOTE, never a GAP
#   * it never writes (GET only) and fails soft on an unreadable repo
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RH="${SCRIPT_DIR}/../skills/init/assets/scripts/repo_health.py"

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
unset GH_REPO

# FAKE_STATE: bare | full | missing
mkdir -p "${tmp}/bin" "${tmp}/pypi/pkg" "${tmp}/repo"
cat > "${tmp}/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "${FAKE_LOG}"
[[ "$1" == "api" ]] || exit 1
full=0; [[ "${FAKE_STATE}" == full ]] && full=1
case "$2" in
    repos/o/r)
        [[ "${FAKE_STATE}" == missing ]] && { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
        if (( full )); then
            echo '{"default_branch":"main","private":false,"description":"d","topics":["t"],"license":{"key":"mit"},"homepage":"https://example.com","has_pages":true,"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
        else
            echo '{"default_branch":"master","private":false,"description":null,"topics":[],"license":null,"homepage":"","has_pages":true,"security_and_analysis":{"secret_scanning":{"status":"disabled"},"secret_scanning_push_protection":{"status":"disabled"}}}'
        fi ;;
    repos/o/r/branches/*/protection)
        (( full )) && { echo '{}'; exit 0; }
        echo "gh: Branch not protected (HTTP 404)" >&2; exit 1 ;;
    repos/o/r/pages) echo '{"html_url":"https://o.example.com/r/"}' ;;
    repos/o/r/tags*) echo '[{"name":"v0.9.0"},{"name":"v0.10.0"},{"name":"latest"}]' ;;
    repos/o/r/releases/tags/v0.10.0)
        (( full )) && { echo '{}'; exit 0; }
        echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
    *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
FAKE
chmod +x "${tmp}/bin/gh"
export PATH="${tmp}/bin:${PATH}" FAKE_LOG="${tmp}/gh.log"
export ARSENAL_PYPI_JSON="file://${tmp}/pypi"

repo="${tmp}/repo"
git -C "${repo}" init -q
git -C "${repo}" remote add origin git@github.com:o/r.git
printf '[project]\nname = "pkg"\n' > "${repo}/pyproject.toml"
rh() { python3 "${RH}" --repo-root "${repo}" "$@"; }

# --- 1: a bare repo reports every gap ---------------------------------------
echo '{"info":{"version":"0.11.0","project_urls":{"Source":"https://github.com/o/r"}}}' > "${tmp}/pypi/pkg/json"
out=$(FAKE_STATE=bare rh) || fail "exit non-zero without --fail-on-gaps"
for want in "not \`main\`" "is unprotected" "no description" "no topics" "no license" \
    "secret_scanning and secret_scanning_push_protection disabled" \
    "--homepage https://o.example.com/r/" "tag v0.10.0 has no release" \
    "PyPI has pkg 0.11.0 but no tag" "outcome: gaps"; do
    [[ "${out}" == *"${want}"* ]] || fail "missing '${want}' in: ${out}"
done
FAKE_STATE=bare rh --fail-on-gaps >/dev/null && fail "--fail-on-gaps exited 0 with gaps"
echo "PASS: a bare repo reports every gap with its fix"

# --- 2: a complete repo reports nothing --------------------------------------
echo '{"info":{"version":"0.10.0","home_page":"https://github.com/O/R"}}' > "${tmp}/pypi/pkg/json"
out=$(FAKE_STATE=full rh --fail-on-gaps) || fail "complete repo failed: ${out}"
[[ "${out}" == *"nothing missing"* && "${out}" == *"outcome: ok"* && "${out}" != *GAP* ]] \
    || fail "complete repo not clean: ${out}"
echo "PASS: a complete repo is clean"

# --- 3: somebody else's PyPI name, and an unpublished one, are NOTEs ----------
echo '{"info":{"version":"9.0.0","project_urls":{"Source":"https://github.com/x/y"}}}' > "${tmp}/pypi/pkg/json"
out=$(FAKE_STATE=full rh)
[[ "${out}" == *"NOTE a PyPI project named \`pkg\` exists but does not link"* && "${out}" == *"outcome: ok"* ]] \
    || fail "foreign PyPI project not a NOTE: ${out}"
rm "${tmp}/pypi/pkg/json"
out=$(FAKE_STATE=full rh)
[[ "${out}" == *"NOTE package \`pkg\`"*"is not on PyPI"* && "${out}" == *"outcome: ok"* ]] \
    || fail "unpublished package not a NOTE: ${out}"
echo "PASS: PyPI uncertainty is a NOTE, not a GAP"

# --- 4: read-only, and soft on an unreadable repo ----------------------------
grep -q -- '-X' "${FAKE_LOG}" && fail "issued a non-GET call: $(grep -- '-X' "${FAKE_LOG}")"
out=$(FAKE_STATE=missing rh --fail-on-gaps); rc=$?
[[ ${rc} -eq 0 && "${out}" == *"outcome: skipped"* ]] || fail "unreadable repo not soft (rc=${rc}): ${out}"
echo "PASS: read-only; an unreadable repo is skipped"

echo "ALL PASS"
