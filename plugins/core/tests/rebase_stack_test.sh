#!/usr/bin/env bash
# rebase_stack_test.sh — evidence-conflict handling in rebase_stack.sh.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBASE_SH="${SCRIPT_DIR}/../skills/init/assets/bin/rebase_stack.sh"
[[ -f "${REBASE_SH}" ]] || { echo "SKIP: ${REBASE_SH} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

git init --bare -q "${tmpdir}/remote.git"
git init -q -b main "${tmpdir}/repo"
cd "${tmpdir}/repo"
git config user.email t@t; git config user.name t
git remote add origin "${tmpdir}/remote.git"

mkdir -p arsenal/tasks status/evidence
# The host gate regenerates the evidence from the tree, the way a real one does.
cat > regen.sh <<'GATE'
#!/usr/bin/env bash
printf '{"files": %s}\n' "$(find . -path ./.git -prune -o -type f -print | wc -l | tr -d ' ')" > status/evidence/E1.json
GATE
chmod +x regen.sh
printf 'host-gate = "bash regen.sh"\n' > arsenal/config.toml
cat > arsenal/tasks/t-1.md <<'TASK'
---
id: t-1
---
## Acceptance gate

```gate
files >= 1
evidence: status/evidence/E1.json
key: files
```
TASK
echo base > src.txt
./regen.sh
git add -A && git commit -qm base
git push -q origin main
BASE=$(git rev-parse HEAD)

# --- 1: evidence-only conflict auto-resolves ---
git checkout -q -b featA
echo a > a.txt && ./regen.sh && git add -A && git commit -qm A
TIP_A=$(git rev-parse HEAD)
git checkout -q -b featB
echo b > b.txt && ./regen.sh && git add -A && git commit -qm B
git push -q origin featB
# featA lands on main (squash-merge shape), and then main moves again — which is
# what makes the evidence conflict: both sides of it changed since featB was cut.
git checkout -q main && git merge -q --squash featA && git commit -qm "A squashed"
echo c > c.txt && echo c2 > c2.txt && ./regen.sh && git add -A && git commit -qm "later main work"
git push -q origin main
git checkout -q featB

out="$(bash "${REBASE_SH}" featB "${TIP_A}" 2>&1)" || fail "rebase should have succeeded: ${out}"
grep -q "evidence-only conflict" <<<"${out}" || fail "expected the evidence auto-resolve to report itself: ${out}"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || fail "tree left dirty after rebase"
git merge-base --is-ancestor origin/main HEAD || fail "featB was not replayed onto main"
[[ "$(git rev-parse origin/featB)" == "$(git rev-parse HEAD)" ]] || fail "featB was not pushed"
# The regenerated evidence describes the rebased tree, not either old side.
grep -q "\"files\": $(find . -path ./.git -prune -o -type f -print | wc -l | tr -d ' ')" status/evidence/E1.json \
    || fail "evidence not regenerated for the rebased tree: $(cat status/evidence/E1.json)"

# --- 2: a conflict outside the evidence set stops, and stops the push ---
git checkout -q -b featC "${BASE}"
echo one > shared.txt && ./regen.sh && git add -A && git commit -qm C
TIP_C=$(git rev-parse HEAD)
git checkout -q -b featD
echo two > shared.txt && ./regen.sh && git add -A && git commit -qm D
git push -q origin featD
D_PUSHED=$(git rev-parse HEAD)
git checkout -q main && git merge -q --squash featC && git commit -qm "C squashed"
echo three > shared.txt && ./regen.sh && git add -A && git commit -qm "later main work"
git push -q origin main
git checkout -q featD

set +e
out="$(bash "${REBASE_SH}" featD "${TIP_C}" 2>&1)"
rc=$?
set -e
(( rc != 0 )) || fail "a real conflict must not exit 0: ${out}"
grep -q "conflicts outside the declared evidence set" <<<"${out}" || fail "expected the real-conflict diagnosis: ${out}"
grep -q "shared.txt" <<<"${out}" || fail "the diagnosis must name the file: ${out}"
[[ "$(git rev-parse origin/featD)" == "${D_PUSHED}" ]] || fail "nothing should have been pushed"
git rebase --abort

# --- 3: --no-push rebases without touching the remote ---
git checkout -q featB
out="$(bash "${REBASE_SH}" --no-push featB "${TIP_A}" 2>&1)" || fail "--no-push run failed: ${out}"
grep -q "nothing was pushed" <<<"${out}" || fail "expected the --no-push notice: ${out}"

echo "PASS: rebase_stack_test.sh"
