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

# --- 4: a clean rebase that leaves committed evidence stale does not publish it ---
# featE conflicts on nothing, but main added files, so the measurement moved.
git checkout -q -b featE "${BASE}"
# No regen here: the branch never touches the evidence, so nothing conflicts —
# but main moves the tree the measurement is taken over.
echo e > e.txt && git add -A && git commit -qm E
git push -q origin featE
E_PUSHED=$(git rev-parse HEAD)
git checkout -q main
echo m1 > m1.txt && echo m2 > m2.txt && ./regen.sh && git add -A && git commit -qm "main moved"
git push -q origin main
git checkout -q featE

set +e
out="$(bash "${REBASE_SH}" featE "${BASE}" 2>&1)"
rc=$?
set -e
(( rc != 0 )) || fail "stale evidence must not be published: ${out}"
grep -q "regenerated evidence differs" <<<"${out}" || fail "expected the stale-evidence refusal: ${out}"
[[ "$(git rev-parse origin/featE)" == "${E_PUSHED}" ]] || fail "a stale head was pushed"
git add -A && git commit -qm "refresh evidence"
out="$(bash "${REBASE_SH}" featE "$(git rev-parse HEAD)" 2>&1)" || fail "committing the evidence should unblock the push: ${out}"

# --- 5: a `./`-prefixed declaration still matches git's path for the file ---
GATE_PY="${SCRIPT_DIR}/../skills/init/assets/scripts/gate_evidence.py"
sed -i.bak 's|^evidence: status|evidence: ./status|' arsenal/tasks/t-1.md
listed="$(python3 "${GATE_PY}" --list-only arsenal/tasks)"
[[ "${listed}" == "status/evidence/E1.json" ]] \
    || fail "a ./-prefixed declaration must normalise to git's path, got: ${listed}"
mv arsenal/tasks/t-1.md.bak arsenal/tasks/t-1.md

# --- 6: invoked by a relative path from a subdirectory ---
# The bundle is found relative to the script, and the script is found relative
# to wherever it was invoked from — so it has to be resolved before the cd to
# the repo root. When it was not, evidence paths silently resolved to nothing
# and every conflict reported as a real one.
git checkout -q -b featF "${BASE}"
echo f > f.txt && ./regen.sh && git add -A && git commit -qm F
TIP_F=$(git rev-parse HEAD)
git checkout -q -b featG
echo g > g.txt && ./regen.sh && git add -A && git commit -qm G
git push -q origin featG
git checkout -q main && git merge -q --squash featF && git commit -qm "F squashed"
echo h > h.txt && ./regen.sh && git add -A && git commit -qm "later main work"
git push -q origin main
git checkout -q featG

# Vendored the way a consumer has it — `claude-arsenal/bin` beside
# `claude-arsenal/scripts` — so the relative path is the one an operator types.
mkdir -p sub vendor/claude-arsenal
cp -R "${SCRIPT_DIR}/../skills/init/assets/bin" "${SCRIPT_DIR}/../skills/init/assets/scripts" vendor/claude-arsenal/
out="$(cd sub && bash ../vendor/claude-arsenal/bin/rebase_stack.sh featG "${TIP_F}" 2>&1)" \
    || fail "a relative invocation from a subdirectory should still resolve the bundle: ${out}"
grep -q "evidence-only conflict" <<<"${out}" || fail "expected the evidence auto-resolve from a subdirectory: ${out}"
rm -rf sub vendor

# --- 7: a conflict --theirs cannot resolve stops instead of staging the other side ---
# The branch deletes an evidence file main modified: there is no "theirs" to
# check out, and taking main's copy would resurrect a file the branch removed.
git checkout -q -b featH "${BASE}"
git rm -q status/evidence/E1.json && git commit -qm "H drops the evidence file"
git push -q origin featH
H_PUSHED=$(git rev-parse HEAD)
git checkout -q main
echo i > i.txt && ./regen.sh && git add -A && git commit -qm "main regenerates it"
git push -q origin main
git checkout -q featH

set +e
out="$(bash "${REBASE_SH}" featH "${BASE}" 2>&1)"
rc=$?
set -e
(( rc != 0 )) || fail "an unresolvable evidence conflict must not exit 0: ${out}"
grep -q "cannot take the branch's side" <<<"${out}" || fail "expected the unresolvable-conflict diagnosis: ${out}"
[[ "$(git rev-parse origin/featH)" == "${H_PUSHED}" ]] || fail "nothing should have been pushed"
git rebase --abort

# --- an unreadable config must not read as "no gate declared" (#265) --------
# The host-gate read was `2>/dev/null || true`, so a malformed config.toml gave
# `host_gate=""` — and an empty host gate is a no-op. The pre-push check
# silently stopped running, which reads as protection while granting none.
# `open_task_pr.sh` states exactly this policy for the identical call.
git checkout -q main 2>/dev/null || git checkout -q featH
cp arsenal/config.toml "${tmpdir}/config.toml.bak"
printf 'host-gate = "bash regen.sh\nthis is not toml [[[\n' > arsenal/config.toml
set +e
out="$(bash "${REBASE_SH}" featH "${BASE}" 2>&1)"
rc=$?
set -e
cp "${tmpdir}/config.toml.bak" arsenal/config.toml
(( rc != 0 )) || fail "a malformed config.toml must not read as 'no gate declared': ${out}"
grep -qi "could not read host-gate\|refusing" <<<"${out}" \
    || fail "the refusal must say the config could not be read: ${out}"
echo "PASS: an unreadable config.toml refuses rather than disabling the host gate"

# --- outside a repository, refuse instead of running in the caller's cwd -----
# `cd "$(git rev-parse --show-toplevel)"` was unchecked: outside a repo the
# command prints nothing, `cd ""` succeeds by staying put, and every path below
# would resolve against whatever directory the caller happened to be in.
outside="${tmpdir}/not-a-repo"
mkdir -p "${outside}"
set +e
out="$(cd "${outside}" && bash "${REBASE_SH}" featH main 2>&1)"
rc=$?
set -e
(( rc != 0 )) || fail "outside a git repository rebase_stack must refuse: ${out}"
grep -qi "not inside a git repository" <<<"${out}" \
    || fail "the refusal must name the reason: ${out}"
echo "PASS: outside a git repository the helper refuses"

echo "PASS: rebase_stack_test.sh"
