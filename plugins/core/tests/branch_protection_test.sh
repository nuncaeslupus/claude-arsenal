#!/usr/bin/env bash
# branch_protection_test.sh — branch_protection.py against a fake `gh`, offline.
#
# What must hold (#461):
#   * only checks that REPORTED on every sampled PR head become required — a bot
#     that is installed but skips must not, or every PR waits forever
#   * existing protection is reported and left alone; --force keeps what it had
#   * --dry-run prints the payload and writes nothing
#   * 403 / no gh / no GitHub remote fail soft: exit 0, a reason, a manual step
#   * init applies it once on a deliberate run, records the outcome, never on
#     --silent, and --no-branch-protection records `off`
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BP="${SCRIPT_DIR}/../skills/init/assets/scripts/branch_protection.py"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
BUNDLE_DIR="${SCRIPT_DIR}/../skills/init/assets"

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
unset GH_REPO
export ARSENAL_UPSTREAM_CHECK=0
export ARSENAL_BRANCH_PROTECTION=1

# --- the fake gh ------------------------------------------------------------
# FAKE_PROTECTION: none | exists | forbidden ; FAKE_AUTH: ok | no
mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/gh" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "${FAKE_LOG}"
if [[ "$1" == "auth" ]]; then [[ "${FAKE_AUTH:-ok}" == ok ]]; exit $?; fi
[[ "$1" == "api" ]] || exit 1
shift
method=GET
if [[ "$1" == "-X" ]]; then method="$2"; shift 2; fi
path="$1"
case "${method} ${path}" in
    "GET repos/o/r")
        if [[ "${FAKE_REPO:-ok}" == missing ]]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
        echo '{"default_branch":"trunk","private":'"${FAKE_PRIVATE:-true}"'}' ;;
    "GET repos/o/r/branches/trunk/protection")
        case "${FAKE_PROTECTION:-none}" in
            none) echo '{"message":"Branch not protected"}'
                  echo "gh: Branch not protected (HTTP 404)" >&2; exit 1 ;;
            nobranch) echo '{"message":"Branch not found"}'
                  echo "gh: Branch not found (HTTP 404)" >&2; exit 1 ;;
            forbidden) echo '{"message":"Upgrade to GitHub Pro or make this repository public to enable this feature."}'
                  echo "gh: Upgrade to GitHub Pro or make this repository public to enable this feature. (HTTP 403)" >&2; exit 1 ;;
            exists) echo '{"required_status_checks":{"strict":true,"contexts":["legacy"]},"required_pull_request_reviews":{"required_approving_review_count":2}}' ;;
        esac ;;
    "GET repos/o/r/pulls"*)
        echo '[{"head":{"sha":"a1"}},{"head":{"sha":"a2"}},{"head":{"sha":"a3"}}]' ;;
    "GET repos/o/r/commits/a3/check-runs"*)
        echo '{"check_runs":[]}' ;;
    "GET repos/o/r/commits/"*"/check-runs"*)
        # lint + test report everywhere; the review bot is installed but skips;
        # docs only ran on one head (path-filtered).
        extra=""
        [[ "${path}" == *a1* ]] && extra=',{"name":"docs","status":"completed","conclusion":"success"}'
        echo '{"check_runs":[{"name":"lint","status":"completed","conclusion":"success"},{"name":"test","status":"completed","conclusion":"failure"},{"name":"review-bot","status":"completed","conclusion":"skipped"}'"${extra}"']}' ;;
    "GET repos/o/r/commits/"*"/status")
        echo '{"statuses":[]}' ;;
    "PUT repos/o/r/branches/trunk/protection")
        cat > "${FAKE_PUT}"; echo '{}' ;;
    *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
SH
chmod +x "${tmp}/bin/gh"
export PATH="${tmp}/bin:${PATH}"
export FAKE_LOG="${tmp}/gh.log" FAKE_PUT="${tmp}/put.json"

repo="${tmp}/repo"
mkdir -p "${repo}"
git -C "${repo}" init -q
git -C "${repo}" remote add origin git@github.com:o/r.git

bp() { python3 "${BP}" --repo-root "${repo}" "$@"; }

# --- 1: apply — only the checks that reported everywhere ---------------------
out=$(bp) || fail "exit non-zero on apply"
[[ "${out}" == *"outcome: applied"* ]] || fail "expected applied, got: ${out}"
python3 - "${FAKE_PUT}" <<'PY' || fail "PUT payload wrong: $(cat "${FAKE_PUT}")"
import json, sys
p = json.load(open(sys.argv[1]))
assert p["required_status_checks"]["contexts"] == ["lint", "test"], p
assert p["enforce_admins"] is True
assert p["required_pull_request_reviews"]["required_approving_review_count"] == 0
PY
[[ "${out}" == *"review-bot: 0/2"* ]] || fail "skipping bot not reported as not required: ${out}"
echo "PASS: required checks are the ones that reported on every head"

# --- 2: dry run writes nothing ----------------------------------------------
rm -f "${FAKE_PUT}"
out=$(bp --dry-run) || fail "dry-run exit"
[[ "${out}" == *"outcome: dry-run"* && "${out}" == *'"enforce_admins": true'* ]] || fail "dry-run output: ${out}"
[[ ! -e "${FAKE_PUT}" ]] || fail "dry-run issued a PUT"
echo "PASS: --dry-run prints the payload and writes nothing"

# --- 3: existing protection is left alone; --force keeps what it required -----
out=$(FAKE_PROTECTION=exists bp) || fail "exists exit"
[[ "${out}" == *"outcome: existing"* && ! -e "${FAKE_PUT}" ]] || fail "existing clobbered: ${out}"
out=$(FAKE_PROTECTION=exists bp --force) || fail "force exit"
python3 - "${FAKE_PUT}" <<'PY' || fail "--force dropped existing requirements: $(cat "${FAKE_PUT}")"
import json, sys
p = json.load(open(sys.argv[1]))
assert p["required_status_checks"]["contexts"] == ["legacy", "lint", "test"], p
assert p["required_status_checks"]["strict"] is True
assert p["required_pull_request_reviews"]["required_approving_review_count"] == 2
PY
echo "PASS: existing protection kept; --force only adds"

# --- 4: fail soft ------------------------------------------------------------
rm -f "${FAKE_PUT}"
out=$(FAKE_PROTECTION=forbidden bp); rc=$?
[[ ${rc} -eq 0 && "${out}" == *"outcome: unavailable"* && "${out}" == *"manual:"* ]] \
    || fail "403 not soft (rc=${rc}): ${out}"
out=$(FAKE_AUTH=no bp); rc=$?
[[ ${rc} -eq 0 && "${out}" == *"outcome: skipped"* && "${out}" == *"not authenticated"* ]] \
    || fail "unauthenticated not soft: ${out}"
out=$(PATH="/usr/bin:/bin" python3 "${BP}" --repo-root "${repo}"); rc=$?
if ! PATH="/usr/bin:/bin" command -v gh >/dev/null 2>&1; then
    [[ ${rc} -eq 0 && "${out}" == *"not installed"* ]] || fail "no gh not soft: ${out}"
fi
norem="${tmp}/norem"; mkdir -p "${norem}"; git -C "${norem}" init -q
: > "${FAKE_LOG}"
out=$(python3 "${BP}" --repo-root "${norem}"); rc=$?
[[ ${rc} -eq 0 && "${out}" == *"no GitHub remote"* && ! -s "${FAKE_LOG}" ]] \
    || fail "no remote should no-op without calling gh: ${out}"
echo "PASS: 403, no login, no gh and no remote all exit 0 with a reason"

# --- 5: workflow fallback when no PR has reported ----------------------------
fb="${tmp}/fb"; mkdir -p "${fb}/.github/workflows"
cat > "${fb}/.github/workflows/ci.yml" <<'YML'
on: [pull_request]
jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
  matrix-job:
    strategy:
      matrix: {py: [3.11]}
YML
out=$(python3 - "${BP}" "${fb}" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("bp", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
from pathlib import Path
print(m._workflow_jobs(Path(sys.argv[2])))
PY
)
[[ "${out}" == "['Build']" ]] || fail "workflow fallback: ${out}"
echo "PASS: workflow fallback names plain pull_request jobs only"

# --- 6: init integration -----------------------------------------------------
rm -f "${FAKE_PUT}"
echo "# t" > "${repo}/CLAUDE.md"
printf 'lint:\n\ttrue\ntest:\n\ttrue\n' > "${repo}/Makefile"
mkdir -p "${repo}/.github/workflows"; printf 'on: pull_request\n' > "${repo}/.github/workflows/ci.yml"
out=$(python3 "${INIT_PY}" --repo-path "${repo}" --bundle-dir "${BUNDLE_DIR}" --profile minimal 2>&1) \
    || fail "init failed: ${out}"
grep -q '^branch-protection = "applied"' "${repo}/arsenal/config.toml" || fail "outcome not recorded"
[[ -e "${FAKE_PUT}" ]] || fail "init did not apply protection"
[[ "${out}" == *"HOST-GATE UNSET"* && "${out}" == *'`make lint test`'* ]] || fail "no host-gate prompt: ${out}"
[[ "${out}" == *"MERGE-POLICY is"* ]] || fail "no merge-policy prompt"
# #463: a private repo's minutes are metered, so the advice is the local gates.
[[ "${out}" == *"private repo"*'`always`'*'pre-pr-review = "required"'* ]] \
    || fail "private repo did not get the local-gates merge-policy advice: ${out}"
[[ "${out}" == *"PREFLIGHT-GATE UNSET"*'`make lint`'* ]] || fail "no preflight-gate prompt: ${out}"
grep -q '^merge-policy = "after-ci"' "${repo}/arsenal/config.toml" \
    || fail "the advice must not rewrite merge-policy"
: > "${FAKE_LOG}"
python3 "${INIT_PY}" --repo-path "${repo}" --bundle-dir "${BUNDLE_DIR}" >/dev/null 2>&1
python3 "${INIT_PY}" --repo-path "${repo}" --bundle-dir "${BUNDLE_DIR}" --silent >/dev/null 2>&1
[[ ! -s "${FAKE_LOG}" ]] || fail "re-run / --silent called gh: $(cat "${FAKE_LOG}")"
python3 - "${repo}/arsenal/config.toml" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read().replace('\nhost-gate = ""', '\nhost-gate = "none"', 1)
open(p, "w").write(t)
PY
out=$(python3 "${INIT_PY}" --repo-path "${repo}" --bundle-dir "${BUNDLE_DIR}" 2>&1)
[[ "${out}" != *"HOST-GATE UNSET"* ]] || fail "host-gate = none still nagged"
got=$(cd "${repo}" && python3 claude-arsenal/scripts/arsenal_config.py --get host-gate)
[[ -z "${got}" ]] || fail "host-gate = none must read as no gate, got '${got}'"
echo "PASS: init applies once, records it, stays off the API afterwards"

opt="${tmp}/opt"; mkdir -p "${opt}"; git -C "${opt}" init -q
git -C "${opt}" remote add origin https://github.com/o/r.git
: > "${FAKE_LOG}"
python3 "${INIT_PY}" --repo-path "${opt}" --bundle-dir "${BUNDLE_DIR}" --profile minimal \
    --no-branch-protection >/dev/null 2>&1 || fail "init --no-branch-protection failed"
grep -q '^branch-protection = "off"' "${opt}/arsenal/config.toml" || fail "opt-out not recorded"
[[ ! -s "${FAKE_LOG}" ]] || fail "--no-branch-protection still called gh"
echo "PASS: --no-branch-protection records off and calls nothing"

# --- 7: an empty or not-yet-created GitHub repo is retried, not "unavailable" ---
# A first /init often runs before the first push: GitHub answers 404 "Branch not
# found" (or 404 for the repo itself). Recording that as `unavailable` never
# retried it, and the merge-policy advice then read it as a private Free-plan repo.
out=$(FAKE_PROTECTION=nobranch bp); rc=$?
[[ ${rc} -eq 0 && "${out}" == *"outcome: skipped"* ]] || fail "empty repo not skipped: ${out}"
out=$(FAKE_REPO=missing bp); rc=$?
[[ ${rc} -eq 0 && "${out}" == *"outcome: skipped"* ]] || fail "missing repo not skipped: ${out}"
empty="${tmp}/empty"; mkdir -p "${empty}/.github/workflows"; git -C "${empty}" init -q
git -C "${empty}" remote add origin https://github.com/o/r.git
printf 'on: pull_request\n' > "${empty}/.github/workflows/ci.yml"
out=$(FAKE_PROTECTION=nobranch FAKE_PRIVATE=false python3 "${INIT_PY}" --repo-path "${empty}" \
    --bundle-dir "${BUNDLE_DIR}" --profile minimal 2>&1) || fail "init on an empty repo failed: ${out}"
! grep -q '^branch-protection = ' "${empty}/arsenal/config.toml" \
    || fail "a skipped outcome was recorded: $(grep branch-protection "${empty}/arsenal/config.toml")"
[[ "${out}" != *"private repo"* ]] || fail "a skipped outcome was read as a private repo: ${out}"
: > "${FAKE_LOG}"
FAKE_PROTECTION=nobranch FAKE_PRIVATE=false python3 "${INIT_PY}" --repo-path "${empty}" \
    --bundle-dir "${BUNDLE_DIR}" >/dev/null 2>&1
grep -q 'branches/trunk/protection' "${FAKE_LOG}" || fail "the next deliberate /init did not retry"
echo "PASS: an empty or missing GitHub repo is retried, never recorded as unavailable"

# --- 8: --workspace forwards --no-branch-protection ------------------------------
ws="${tmp}/ws"; mkdir -p "${ws}"; git -C "${ws}" init -q
git -C "${ws}" remote add origin https://github.com/o/r.git
: > "${FAKE_LOG}"
python3 "${INIT_PY}" --repo-path "${ws}" --bundle-dir "${BUNDLE_DIR}" --profile minimal \
    --workspace api --no-branch-protection >/dev/null 2>&1 || fail "init --workspace failed"
grep -q '^branch-protection = "off"' "${ws}/arsenal/config.toml" || fail "--workspace dropped --no-branch-protection"
[[ ! -s "${FAKE_LOG}" ]] || fail "--workspace --no-branch-protection still called gh: $(cat "${FAKE_LOG}")"
echo "PASS: --workspace forwards --no-branch-protection"
