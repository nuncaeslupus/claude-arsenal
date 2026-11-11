#!/usr/bin/env bash
# ci_shape_test.sh — ci_shape.py against workflow files written here, offline.
#
# What must hold (one case per way the reader can be wrong, not per message):
#   * a bare push/PR workflow reports all four findings
#   * a workflow that follows the advice is clean, block or inline `on:`
#   * a path filter alone is a NOTE and never fails the run
#   * a costly runner is only a problem where a pull request reaches it
#   * workflows that push/PR do not trigger, and repos with none, are skipped
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS="${SCRIPT_DIR}/../skills/init/assets/scripts/ci_shape.py"

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
wf="${tmp}/.github/workflows"
mkdir -p "${wf}"
cs() { python3 "${CS}" --repo-root "${tmp}" "$@"; }

# --- 1: no workflows is skipped, not a failure -------------------------------
out=$(cs --fail-on-problems) || fail "empty repo exited non-zero: ${out}"
[[ "${out}" == *"outcome: skipped"* ]] || fail "empty repo not skipped: ${out}"

# --- 2: a bare workflow reports everything -----------------------------------
cat > "${wf}/ci.yml" <<'YML'
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - run: make test
  build:
    runs-on: windows-latest   # installer
    steps:
      - name: timeout-minutes: not a job key
        run: make build
YML
out=$(cs) || fail "exit non-zero without --fail-on-problems"
for want in "PROBLEM ci.yml: no \`concurrency\`" "no \`timeout-minutes\` on: test, build" \
    "test (macos), build (windows)" "NOTE    ci.yml: no \`paths\`/\`paths-ignore\` on pull_request, push" \
    "outcome: problems"; do
    [[ "${out}" == *"${want}"* ]] || fail "missing '${want}' in: ${out}"
done
cs --fail-on-problems >/dev/null && fail "--fail-on-problems exited 0 with problems"
echo "PASS: a bare workflow reports all four findings"

# --- 3: the advised shape is clean; an unfiltered trigger is only a NOTE ------
cat > "${wf}/ci.yml" <<'YML'
"on":
  pull_request:
    types: [opened]
    paths-ignore: ['**/*.md']
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
  mac:
    if: github.event_name == 'push'
    runs-on: macos-latest
    timeout-minutes: 20
  call:
    uses: ./.github/workflows/reusable.yml
YML
out=$(cs --fail-on-problems) || fail "a NOTE failed the run: ${out}"
[[ "${out}" != *PROBLEM* && "${out}" == *"\`paths-ignore\` on push"* && "${out}" == *"outcome: ok"* ]] \
    || fail "advised shape not clean: ${out}"
echo "PASS: the advised shape is clean; a main-only macOS job and a reusable call are left alone"

# --- 4: cancel-in-progress: false does not count; push-only has no PR path ----
cat > "${wf}/ci.yml" <<'YML'
on:
  push:
    paths: ['src/**']
concurrency:
  group: x
  cancel-in-progress: false
jobs:
  test:
    runs-on: macos-latest
    timeout-minutes: 5
YML
out=$(cs)
[[ "${out}" == *"no \`concurrency\`"* && "${out}" != *"non-Linux"* && "${out}" != *NOTE* ]] \
    || fail "cancel-in-progress: false / push-only misread: ${out}"
echo "PASS: cancel-in-progress: false is reported; a push-only workflow has no PR path"

# --- 5: a workflow push/PR does not trigger is not checked --------------------
printf 'on:\n  schedule:\n    - cron: "0 3 * * *"\njobs:\n  nightly:\n    runs-on: macos-latest\n' > "${wf}/ci.yml"
out=$(cs --fail-on-problems) || fail "scheduled-only workflow failed: ${out}"
[[ "${out}" == *"0 push/pull_request workflow(s) checked"* ]] || fail "scheduled workflow was checked: ${out}"
echo "PASS: a scheduled-only workflow is skipped"

echo "ALL PASS"
