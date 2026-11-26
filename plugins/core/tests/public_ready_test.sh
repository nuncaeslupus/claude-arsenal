#!/usr/bin/env bash
# public_ready_test.sh — audit_public_repo.py against a fake `gh`, offline.
#
# What must hold:
#   * audit reports each security gap, and a pull_request_target workflow that
#     checks out the PR head is a GAP, not a NOTE
#   * fix skips the read-only token default while a workflow declares no
#     `permissions:` (switching it would break that workflow), applies the rest
#   * --dry-run writes nothing; a private repo is skipped; no gh → exit 2
#   * scaffold substitutes the repo, writes the chosen policy, never overwrites
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR="${SCRIPT_DIR}/../skills/public-ready/scripts/audit_public_repo.py"

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

wf=$(printf 'on:\n  pull_request_target:\njobs:\n  x:\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          ref: ${{ github.event.pull_request.head.sha }}\n' | base64 | tr -d '\n')
wf_guarded=$(printf 'on:\n  workflow_run:\njobs:\n  x:\n    if: github.event.workflow_run.head_repository.full_name == github.repository\n    steps:\n      - uses: actions/checkout@v4\n        with:\n          ref: ${{ github.event.workflow_run.head_sha }}\n' | base64 | tr -d '\n')

mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/gh" <<SH
#!/usr/bin/env bash
echo "\$*" >> "\${FAKE_LOG}"
[[ "\$1" == "api" ]] || exit 1
shift
method=GET
if [[ "\$1" == "-X" ]]; then method="\$2"; shift 2; fi
[[ "\${method}" != GET ]] && { cat >/dev/null; echo '{}'; exit 0; }
case "\$1" in
    repos/o/r) echo '{"private":'"\${FAKE_PRIVATE:-false}"',"default_branch":"main","has_wiki":true,"security_and_analysis":{"secret_scanning":{"status":"disabled"}}}' ;;
    repos/o/r/private-vulnerability-reporting) echo '{"enabled":false}' ;;
    repos/o/r/contents/.github/workflows) echo '[{"name":"ci.yml"}]' ;;
    repos/o/r/contents/.github/workflows/ci.yml)
        if [[ -n "\${FAKE_GUARDED:-}" ]]; then echo '{"content":"${wf_guarded}"}'; else echo '{"content":"${wf}"}'; fi ;;
    repos/o/r/branches/main/protection)
        [[ -n "\${FAKE_PROTECTED:-}" ]] || { echo "gh: Branch not protected (HTTP 404)" >&2; exit 1; }
        echo '{"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false}}' ;;
    repos/o/r/actions/permissions/workflow) echo '{"default_workflow_permissions":"write","can_approve_pull_request_reviews":true}' ;;
    repos/o/r/rulesets) echo '[]' ;;
    repos/o/r/contents/.github/ISSUE_TEMPLATE)
        [[ -n "\${FAKE_FORMS:-}" ]] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
        echo '[{"name":"bug.yml"}]' ;;
    repos/o/r/community/profile) echo '{"files":{"contributing":null}}' ;;
    graphql) echo '{"data":{"repository":{"usesCustomOpenGraphImage":false}}}' ;;
    *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
SH
chmod +x "${tmp}/bin/gh"
export PATH="${tmp}/bin:${PATH}" FAKE_LOG="${tmp}/gh.log"

# --- 1: audit -----------------------------------------------------------------
out=$(python3 "${PR}" audit --repo o/r) || fail "audit exit non-zero: ${out}"
for want in "GAP  secret scanning" "GAP  dependabot alerts" "GAP  private vulnerability reporting" \
    "GAP  actions token default" "GAP  \`main\` force-push/delete" "GAP  release tags protected" \
    "GAP  workflow ci.yml" "NOTE workflow permissions" "NOTE fork PR approval" \
    "GAP  SECURITY.md" "GAP  CONTRIBUTING.md" "GAP  social preview" "NOTE wiki"; do
    [[ "${out}" == *"${want}"* ]] || fail "audit missing '${want}': ${out}"
done
python3 "${PR}" audit --repo o/r --fail-on-gaps >/dev/null && fail "--fail-on-gaps should exit 1"
python3 "${PR}" audit --repo o/r --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["o/r"][0]["level"]' \
    || fail "--json not parseable"

# --- 2: fix --dry-run writes nothing ------------------------------------------
: > "${FAKE_LOG}"
out=$(python3 "${PR}" fix --repo o/r --dry-run) || fail "dry run exit non-zero"
grep -q -- '-X' "${FAKE_LOG}" && fail "dry run wrote: $(cat "${FAKE_LOG}")"
[[ "${out}" == *"skipped: actions token default"*"ci.yml"* ]] || fail "token default not skipped: ${out}"
[[ "${out}" == *"would apply: ruleset 'public-ready: release tags'"* ]] || fail "tag ruleset not planned: ${out}"

# --- 3: fix applies -----------------------------------------------------------
: > "${FAKE_LOG}"
python3 "${PR}" fix --repo o/r >/dev/null || fail "fix exit non-zero"
for call in "-X PATCH repos/o/r" "-X PUT repos/o/r/vulnerability-alerts" \
    "-X PUT repos/o/r/private-vulnerability-reporting" "-X POST repos/o/r/rulesets"; do
    grep -qF -- "${call}" "${FAKE_LOG}" || fail "fix did not call '${call}'"
done
grep -qF -- "actions/permissions/workflow --input" "${FAKE_LOG}" && fail "token default switched despite undeclared permissions"

# --- 4: private repo skipped --------------------------------------------------
out=$(FAKE_PRIVATE=true python3 "${PR}" fix --repo o/r) || fail "private fix exit non-zero"
[[ "${out}" == *"skipped: private repository"* ]] || fail "private not skipped: ${out}"

# --- 5: scaffold --------------------------------------------------------------
clone="${tmp}/clone"; mkdir -p "${clone}"
echo "mine" > "${clone}/SECURITY.md"
out=$(python3 "${PR}" scaffold --repo o/r --repo-root "${clone}") || fail "scaffold exit non-zero"
[[ "$(cat "${clone}/SECURITY.md")" == mine ]] || fail "scaffold overwrote SECURITY.md"
grep -q "not accepted for now" "${clone}/CONTRIBUTING.md" || fail "issues policy not written"
grep -q "github.com/o/r/security/advisories/new" "${clone}/.github/ISSUE_TEMPLATE/config.yml" || fail "repo not substituted"
grep -q "{{repo}}" -r "${clone}" && fail "placeholder left in output"
clone2="${tmp}/clone2"; mkdir -p "${clone2}/docs"; echo "dev guide" > "${clone2}/docs/CONTRIBUTING.md"
python3 "${PR}" scaffold --repo o/r --repo-root "${clone2}" >/dev/null
[[ -e "${clone2}/CONTRIBUTING.md" ]] && fail "scaffold added a second CONTRIBUTING.md beside docs/"

# --- 6: a same-repo guard downgrades the head checkout; classic protection is kept
out=$(FAKE_GUARDED=1 python3 "${PR}" audit --repo o/r)
[[ "${out}" == *"NOTE workflow ci.yml: checks out a head ref"* ]] || fail "guarded workflow not a NOTE: ${out}"
[[ "${out}" == *"GAP  workflow ci.yml"* ]] && fail "guarded workflow still a GAP"
out=$(FAKE_PROTECTED=1 python3 "${PR}" fix --repo o/r --dry-run)
[[ "${out}" == *"public-ready: default branch"* ]] && fail "branch ruleset planned despite classic protection: ${out}"
[[ "${out}" == *"public-ready: release tags"* ]] || fail "tag ruleset dropped: ${out}"

# YAML issue forms count, though the community profile does not report them
out=$(FAKE_FORMS=1 python3 "${PR}" audit --repo o/r)
[[ "${out}" == *"PASS issue templates"* ]] || fail "issue forms not seen: ${out}"

# --- 7: no gh -----------------------------------------------------------------
# A PATH holding only python3: a runner's real /usr/bin/gh must not leak in.
mkdir -p "${tmp}/nogh" && ln -s "$(command -v python3)" "${tmp}/nogh/python3"
PATH="${tmp}/nogh" python3 "${PR}" audit --repo o/r 2>/dev/null; [[ $? == 2 ]] || fail "no gh should exit 2"

echo "PASS: public_ready_test"
