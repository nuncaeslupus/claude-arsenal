#!/usr/bin/env bash
# adversarial_review_test.sh — the pre-PR review gate holds its own contract.
#
# Two properties are load-bearing and both have already broken once here:
#
#   1. A verdict must survive from `emit` to `verdict`. The first version hashed
#      a copy of the diff captured in a shell variable — command substitution
#      strips trailing newlines — while the freshness check hashed the raw
#      stream. They never matched, so every review came back "the tree changed
#      while the review ran" for a tree nobody had touched. A staleness check
#      that always fires is one a consumer learns to ignore, which leaves the
#      gate present and inert.
#   2. Silence is not approval. No verdict line, no receipt, and a receipt for
#      an older tree must each be distinguishable from CLEAR, at the exit code,
#      because `open_task_pr.sh` decides what to write in the PR body from it.
#
# The integration half asserts the part a consumer actually sees: a task PR
# opened with no independent review says so in its body, and `required` refuses.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
REVIEW="${BIN}/adversarial_review.sh"
HELPER="${BIN}/open_task_pr.sh"
[[ -f "${REVIEW}" ]] || { echo "SKIP: adversarial_review.sh not found" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

# ---------------------------------------------------------------- unit half --
REPO="${tmp}/repo"
mkdir -p "${REPO}/status"
cd "${REPO}"
git init -q -b main .
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
echo "print('hi')" > app.py
printf '# Spec\n\nMake the app say bye.\n' > status/specification.md
git add -A; git commit -qm init

echo "print('bye')" >> app.py       # tracked, uncommitted
echo "brand new" > extra.txt        # untracked
V="tmp/arsenal-review/verdict.md"

# --- 1: the packet carries intent, both kinds of change, and the rubric ---
out=$(bash "${REVIEW}" emit) || fail "emit exited non-zero: ${out}"
[[ "${out}" == "tmp/arsenal-review/packet.md" ]] || fail "emit should print the packet path, printed: ${out}"
packet=$(cat "${out}")
grep -q "Make the app say bye" <<<"${packet}" || fail "the packet must carry the stated intent"
grep -q "print('bye')" <<<"${packet}" || fail "the packet must carry the uncommitted tracked change"
grep -q "brand new" <<<"${packet}" || fail "the packet must carry untracked files — a whole new module is invisible to git diff"
grep -q "Your brief" <<<"${packet}" || fail "the packet must embed the reviewer rubric"
grep -q "VERDICT: CLEAR" <<<"${packet}" || fail "the packet must state the verdict contract"
echo "PASS: the packet is self-contained — intent, tracked diff, untracked files, rubric"

# --- 2: the review directory never reviews itself ---
grep -q "arsenal-review" <<<"$(git status --short)" && fail "the review directory must exclude itself from git"
echo "PASS: the review directory excludes itself, so it cannot land in the PR it reviewed"

# --- 3: a CLEAR survives from emit to verdict (the digest-drift regression) ---
printf 'VERDICT: CLEAR — nothing blocking\n' > "${V}"
bash "${REVIEW}" verdict 2>/dev/null
rc=$?
(( rc == 0 )) || fail "a CLEAR on an unchanged tree must exit 0, got ${rc} (digest drift between emit and verdict?)"
bash "${REVIEW}" check 2>/dev/null || fail "check must pass on a fresh CLEAR"
echo "PASS: a verdict survives from emit to verdict on an unchanged tree"

# --- 4: no verdict line is not a pass ---
printf 'This change looks fine to me, ship it.\n' > "${V}"
bash "${REVIEW}" verdict 2>/dev/null
(( $? == 2 )) || fail "a reply with no VERDICT line must exit 2, never 0"
echo "PASS: a review that returned no verdict is not a pass"

# --- 5: the LAST verdict line wins (the packet quotes the format) ---
printf 'the format is VERDICT: CLEAR — example\nVERDICT: BLOCK — the real answer\n' > "${V}"
bash "${REVIEW}" verdict 2>/dev/null
(( $? == 1 )) || fail "the last VERDICT line must win, so a quoted example cannot clear a blocked change"
bash "${REVIEW}" check 2>/dev/null
(( $? == 1 )) || fail "check must report the recorded BLOCK"
echo "PASS: the last verdict line wins, and a BLOCK is held"

# --- 6: a tree that moves after CLEAR is stale, not cleared ---
printf 'VERDICT: CLEAR — nothing blocking\n' > "${V}"
bash "${REVIEW}" verdict >/dev/null 2>&1 || fail "setup: re-clearing should succeed"
echo "print('sneaked in after the review')" >> app.py
bash "${REVIEW}" check 2>/dev/null
(( $? == 3 )) || fail "editing after a CLEAR must read as stale — 'reviewed, then kept coding' cannot pass"
bash "${REVIEW}" verdict 2>/dev/null
(( $? == 3 )) || fail "verdict must also refuse to record a review of a tree that has moved"
echo "PASS: a CLEAR does not carry over to a tree edited after it"

# --- 7: re-emitting retires the previous answer ---
bash "${REVIEW}" emit >/dev/null || fail "setup: re-emit should succeed"
bash "${REVIEW}" check 2>/dev/null
(( $? == 2 )) || fail "a new packet must retire the old receipt — round one's CLEAR says nothing about round two"
echo "PASS: a second review round starts with no verdict on record"

# --- 8: nothing to review is its own outcome ---
git stash -q -u 2>/dev/null || { git checkout -q -- .; rm -f extra.txt; }
bash "${REVIEW}" emit >/dev/null 2>&1
(( $? == 3 )) || fail "a clean tree must exit 3 (nothing to review), not emit an empty packet"
echo "PASS: a clean tree is reported as nothing to review"

# --- 9: no rubric, no packet ---
git stash pop -q 2>/dev/null || true
alt="${tmp}/norubric"; mkdir -p "${alt}/bin"
cp "${REVIEW}" "${alt}/bin/"                      # copied WITHOUT ../agents/reviewer.md
echo "changed" >> app.py
bash "${alt}/bin/adversarial_review.sh" emit >/dev/null 2>&1
(( $? == 1 )) || fail "emit must refuse when the rubric is missing — a review with no rubric is the skim this replaces"
echo "PASS: emit refuses to build a packet with no rubric"

# --------------------------------------------------------- integration half --
[[ -f "${HELPER}" ]] || { echo "PASS: adversarial_review_test — unit half (open_task_pr.sh absent)"; exit 0; }

BARE="${tmp}/remote.git"; SEED="${tmp}/seed"; WORK="${tmp}/work"; FAKEBIN="${tmp}/bin"
git init -q --bare "${BARE}"
git -C "${BARE}" symbolic-ref HEAD refs/heads/main

cd "${tmp}" && git init -q -b main "${SEED}" && cd "${SEED}"
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
git remote add origin "${BARE}"
mkdir -p arsenal/tasks
# One task per case: open_task_pr.sh pushes `arsenal/<id>-<slug>`, so reusing an
# id across cases means the second push is a non-fast-forward onto the branch
# the first one left on the remote — a failure that has nothing to do with what
# is being tested.
for _id in t-rev-warn t-rev-clear t-rev-req; do
    printf -- '---\nid: %s\ntitle: "Review fixture"\npriority: 1\n---\n\n## Acceptance gate\n```bash\ntrue\n```\n' \
        "${_id}" > "arsenal/tasks/${_id}.md"
done
echo base > base.txt
git add -A; git commit -qm "chore: base"; git push -q -u origin main

# A fake `gh` that records the PR body instead of reaching GitHub. Prepended to
# PATH so it shadows a real gh if the runner has one.
mkdir -p "${FAKEBIN}"
cat > "${FAKEBIN}/gh" <<'GH'
#!/usr/bin/env bash
body=""; prev=""
for a in "$@"; do [[ "${prev}" == "--body" ]] && body="${a}"; prev="${a}"; done
printf '%s' "${body}" > "${GH_BODY_FILE}"
echo "https://github.com/o/r/pull/1"
GH
chmod +x "${FAKEBIN}/gh"
export PATH="${FAKEBIN}:${PATH}"

_fresh_work() {   # a clean worker checkout with an uncommitted change
    cd "${tmp}"   # never rm the directory we are standing in — getcwd() then fails
    rm -rf "${WORK}"
    git clone -q "${BARE}" "${WORK}"
    cd "${WORK}"
    git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
    mkdir -p arsenal/session
    echo unavailable > arsenal/session/worktree_isolation   # unlocks `git add -A`
    echo feature > feature.txt
}

# --- 10: no review → the PR still opens, and its body says nobody looked ---
_fresh_work
export GH_BODY_FILE="${tmp}/body1.txt"
ARSENAL_TASK_ISSUE=7 ARSENAL_COAUTHOR="" bash "${HELPER}" t-rev-warn "Review fixture" >/dev/null 2>&1 \
    || fail "warn mode must still open the PR when no review ran"
grep -q "not run" "${GH_BODY_FILE}" \
    || fail "a PR opened with no independent review must say so in its body, got: $(cat "${GH_BODY_FILE}")"
echo "PASS: an unreviewed task PR opens under warn, and states that in its body"

# --- 11: a CLEAR review is recorded in the PR body ---
_fresh_work
bash "${REVIEW}" emit >/dev/null || fail "setup: emit in the work tree"
printf 'VERDICT: CLEAR — checked the diff against the task\n' > "${V}"
bash "${REVIEW}" verdict >/dev/null 2>&1 || fail "setup: recording a CLEAR"
export GH_BODY_FILE="${tmp}/body2.txt"
ARSENAL_TASK_ISSUE=7 ARSENAL_COAUTHOR="" bash "${HELPER}" t-rev-clear "Review fixture" >/dev/null 2>&1 \
    || fail "a cleared change must open its PR"
grep -q "CLEAR" "${GH_BODY_FILE}" \
    || fail "a cleared review must be recorded in the PR body, got: $(cat "${GH_BODY_FILE}")"
git log -1 --name-only --format= | grep -q "arsenal-review" \
    && fail "the review's own working files must never be committed into the PR"
echo "PASS: a cleared review is recorded in the PR body, and the packet stays out of the commit"

# --- 12: required refuses without a review ---
_fresh_work
printf 'pre-pr-review = "required"\n' > arsenal/config.toml
export GH_BODY_FILE="${tmp}/body3.txt"; : > "${GH_BODY_FILE}"
out=$(ARSENAL_TASK_ISSUE=7 ARSENAL_COAUTHOR="" bash "${HELPER}" t-rev-req "Review fixture" 2>&1)
(( $? != 0 )) || fail "pre-pr-review=required must refuse to open a PR with no review"
grep -q "no PR opened" <<<"${out}" || fail "the refusal should say no PR was opened: ${out}"
[[ -s "${GH_BODY_FILE}" ]] && fail "required must refuse BEFORE any PR is opened"
git rev-parse --verify --quiet "arsenal/t-rev-req" >/dev/null 2>&1 \
    && fail "no branch should exist after a refused review gate"
echo "PASS: pre-pr-review=required refuses before touching git"

echo "PASS: adversarial_review_test — all gates passed"
