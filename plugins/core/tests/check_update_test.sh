#!/usr/bin/env bash
# check_update_test.sh — regression test for the "already current" false
# negative reported by a downstream consumer.
#
# A repo re-vendored the bundle, was told it was current, and ran a whole
# session on a stale copy. Two independent conditions both exited 0 without a
# word: no `arsenal` remote was configured (the bundle had been hand-copied,
# so there was nothing to compare against), and the newer upstream release was
# UNTAGGED (its tag workflow never ran during an Actions outage), so the
# tag-gated check could not see it either. Silence read as "up to date".
#
# Gates:
#   - no remote                         → says the check is inert, exit 0;
#   - newest tag == installed, but the default branch ships a newer
#     .bundle-version                   → names that untagged version;
#   - newest tag < installed            → refuses to downgrade (the old
#     `installed != latest` test would have subtree-merged backwards);
#   - genuinely current                 → says so rather than staying silent;
#   - newest tag > installed            → still takes the update path.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="${SCRIPT_DIR}/../skills/init/assets/bin/check_update.sh"

[[ -f "${CHECK}" ]] || { echo "SKIP: check_update.sh not found at ${CHECK}" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
tmp="$(cd "${tmp}" && pwd -P)"
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

UPSTREAM_VERSION_PATH="plugins/core/skills/init/assets/.bundle-version"
export ARSENAL_UPSTREAM_VERSION_PATH="${UPSTREAM_VERSION_PATH}"

# --- A stand-in marketplace repo, tagged v0.20.5, whose main later bumps to
#     0.21.0 WITHOUT a tag — exactly the upstream state that broke the consumer.
market="${tmp}/marketplace"
mkdir -p "${market}/$(dirname "${UPSTREAM_VERSION_PATH}")"
git init -q -b main "${market}"
git -C "${market}" config user.email "test@arsenal.example"
git -C "${market}" config user.name "Arsenal Test"
echo "0.20.5" > "${market}/${UPSTREAM_VERSION_PATH}"
git -C "${market}" add -A
git -C "${market}" commit -q -m "chore: release 0.20.5"
git -C "${market}" tag -a v0.20.5 -m "Release v0.20.5"

# The consumer: a repo with the bundle vendored at claude-arsenal/.
consumer="${tmp}/consumer"
mkdir -p "${consumer}/claude-arsenal"
git init -q -b main "${consumer}"
git -C "${consumer}" config user.email "test@arsenal.example"
git -C "${consumer}" config user.name "Arsenal Test"
echo "0.20.5" > "${consumer}/claude-arsenal/.bundle-version"
git -C "${consumer}" add -A
git -C "${consumer}" commit -q -m "chore: vendor bundle"

run_check() { (cd "${consumer}" && bash "${CHECK}" 2>"${tmp}/err.log"); }

# --- Gate 1: no `arsenal` remote — the check is inert and must say so. -------
out="$(run_check)" || fail "check_update.sh exited non-zero with no remote"
grep -qi "INERT" "${tmp}/err.log" \
    || fail "no-remote case stayed silent; stderr was: $(cat "${tmp}/err.log")"
grep -q "git remote add" "${tmp}/err.log" \
    || fail "no-remote case did not say how to fix it"
echo "PASS: a missing 'arsenal' remote is reported, not silently treated as current"

# --- Gate 1b: the message states what was tested, and nothing else. ----------
#     A missing remote and a bundle that is not a subtree are independent facts,
#     and remotes are not cloned — so a genuine subtree arrives with no remote
#     on every fresh clone. Told "the bundle was copied, not added as a git
#     subtree", a session reasonably concludes that upgrades must be done by
#     copying files in, which is what `verify-subtree` exists to catch.
subtree_consumer="${tmp}/subtree-consumer"
mkdir -p "${subtree_consumer}/claude-arsenal"
git init -q -b main "${subtree_consumer}"
git -C "${subtree_consumer}" config user.email "test@arsenal.example"
git -C "${subtree_consumer}" config user.name "Arsenal Test"
echo "0.20.5" > "${subtree_consumer}/claude-arsenal/.bundle-version"
git -C "${subtree_consumer}" add -A
# The merge commit `git subtree add` writes, which is how the script recognises
# one. No remote here — that is the state under test.
git -C "${subtree_consumer}" commit -q -m "chore: add bundle

git-subtree-dir: claude-arsenal
git-subtree-split: 0000000000000000000000000000000000000000"
(cd "${subtree_consumer}" && bash "${CHECK}" 2>"${tmp}/subtree-err.log") \
    || fail "check_update.sh exited non-zero on a subtree with no remote"
grep -qi "INERT" "${tmp}/subtree-err.log" \
    || fail "the no-remote case must still report itself: $(cat "${tmp}/subtree-err.log")"
grep -q "was copied" "${tmp}/subtree-err.log" \
    && fail "a genuine subtree must not be reported as a copied bundle: $(cat "${tmp}/subtree-err.log")"
grep -q "IS a git subtree" "${tmp}/subtree-err.log" \
    || fail "the report should say which of the two states this repo is in: $(cat "${tmp}/subtree-err.log")"
# ...and the copied case still gets the structural half of the diagnosis.
grep -q "no subtree merge in this history" "${tmp}/err.log" \
    || fail "a hand-copied bundle should be told it cannot be merged: $(cat "${tmp}/err.log")"
# ...and a consumer whose git config sets a literal pattern type still has a
# subtree recognised: `grep.patternType=fixed` applies to `git log --grep`, and
# the trailer pattern is a regex — read literally it matches nothing, so every
# subtree would report as copied and the update path would refuse to merge one.
git -C "${subtree_consumer}" config grep.patternType fixed
(cd "${subtree_consumer}" && bash "${CHECK}" 2>"${tmp}/fixed-err.log") \
    || fail "check_update.sh exited non-zero under grep.patternType=fixed"
grep -q "IS a git subtree" "${tmp}/fixed-err.log" \
    || fail "grep.patternType=fixed hid a real subtree: $(cat "${tmp}/fixed-err.log")"
git -C "${subtree_consumer}" config --unset grep.patternType
echo "PASS: the no-remote report distinguishes a subtree from a copied bundle"

git -C "${consumer}" remote add arsenal "${market}"

# --- Gate 2: tag == installed and the branch is at that tag → genuinely
#     current, and it says so instead of exiting mute. ------------------------
out="$(run_check)" || fail "check_update.sh exited non-zero when current"
[[ "${out}" == *"current with the newest tag"* ]] \
    || fail "genuinely-current case did not report being current, stdout: '${out}'"
echo "PASS: a genuinely current bundle reports that it is current"

# --- Gate 3: main bumps to 0.21.0 but is NEVER tagged (the Actions outage).
#     The tag-gated path sees v0.20.5 == installed; the probe must still find
#     and name the untagged 0.21.0. -----------------------------------------
echo "0.21.0" > "${market}/${UPSTREAM_VERSION_PATH}"
git -C "${market}" add -A
git -C "${market}" commit -q -m "fix: ship 0.21.0 without a tag"

out="$(run_check)" || fail "check_update.sh exited non-zero on the untagged-upstream case"
grep -q "UNTAGGED UPSTREAM RELEASE" "${tmp}/err.log" \
    || fail "untagged upstream 0.21.0 was not reported; stderr: $(cat "${tmp}/err.log")"
grep -q "0\.21\.0" "${tmp}/err.log" \
    || fail "the warning does not name the newer version 0.21.0"
grep -q "make tag" "${tmp}/err.log" \
    || fail "the warning does not say how to fix it upstream"
echo "PASS: an untagged newer upstream release is detected and named"

# --- Gate 4: a consumer AHEAD of the newest tag (hand-vendored 0.21.0) must
#     never be downgraded. The old `installed != latest` test would have
#     subtree-merged v0.20.5 backwards over it. ------------------------------
echo "0.21.0" > "${consumer}/claude-arsenal/.bundle-version"
git -C "${consumer}" add -A
git -C "${consumer}" commit -q -m "chore: hand-vendor 0.21.0"

out="$(run_check)" || fail "check_update.sh exited non-zero when ahead of the newest tag"
[[ "${out}" != *"pulling update"* ]] \
    || fail "check_update.sh tried to DOWNGRADE to the older tag: '${out}'"
grep -q "not downgrading" "${tmp}/err.log" \
    || fail "ahead-of-tag case did not explain itself; stderr: $(cat "${tmp}/err.log")"
echo "PASS: a bundle ahead of the newest tag is never downgraded"

# --- Gate 5: a genuinely newer TAG still takes the update path. --------------
git -C "${market}" tag -a v0.22.0 -m "Release v0.22.0"
out="$(run_check)" || fail "check_update.sh exited non-zero on a real update"
[[ "${out}" == *"pulling update"* ]] \
    || fail "a newer tag (v0.22.0) did not trigger the update path, stdout: '${out}'"
echo "PASS: a strictly newer tag still triggers the update path"

# --- 6: the assembled-bundle dir and the subtree prefix are separate paths ---
#     One variable served both, and the layout vendor-skills.sh exists to support
#     keeps them apart: the subtree is vendored whole at vendor/claude-arsenal/
#     and the bundle assembled at claude-arsenal/. No single value satisfied both
#     readings — the default found the version but could not merge, and pointing
#     it at the subtree merged but read version 0.0.0, so every run claimed an
#     update was due.
setup_repo_at() {  # $1 = bundle dir holding .bundle-version, $2 = installed version
    rm -rf "${tmp}/split"; mkdir -p "${tmp}/split/$1"
    cd "${tmp}/split"
    git init -q -b main .
    git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
    printf '%s\n' "$2" > "$1/.bundle-version"
    mkdir -p bin && cp "${CHECK}" bin/check_update.sh
    git add -A && git commit -q -m init
}

setup_repo_at "claude-arsenal" "0.26.0"
out=$(ARSENAL_BUNDLE_DIR=claude-arsenal ARSENAL_PREFIX=vendor/claude-arsenal \
      ARSENAL_REMOTE=nope bash bin/check_update.sh 2>&1 || true)
grep -q "0.0.0" <<<"${out}" \
    && fail "ARSENAL_BUNDLE_DIR must locate .bundle-version independently of the subtree prefix: ${out}"

# --- 7: --check-only reports without writing history ---
#     The session protocol documents this as a status report, but the happy path
#     merged and committed into the tree the worker loop needs clean.
setup_repo_at "claude-arsenal" "0.1.0"
before=$(git rev-parse HEAD)
out=$(ARSENAL_REMOTE=nope bash bin/check_update.sh --check-only 2>&1 || true)
[[ "$(git rev-parse HEAD)" == "${before}" ]] || fail "--check-only must not write a commit"
git diff --quiet || fail "--check-only must leave the working tree clean"

# --- 8: an unknown argument does not abort a session ---
out=$(ARSENAL_REMOTE=nope bash bin/check_update.sh --bogus 2>&1; echo "rc=$?")
grep -q "rc=0" <<<"${out}" || fail "an unknown argument must never abort a session: ${out}"
grep -q "unknown argument" <<<"${out}" || fail "an unknown argument should say so: ${out}"

# --- 9: "updated" is never printed while the bundle version did not move ---
#     In the split layout the update path merged the subtree and re-ran init.py,
#     which faithfully reassembled the bundle out of the PRE-upgrade vendored
#     skills — nothing had refreshed those. The subtree said the new version,
#     the assembled bundle said the old one, and the run reported success. The
#     success message is the part that hid it.
setup_repo_at "claude-arsenal" "0.29.1"
mkdir -p vendor/claude-arsenal/plugins/core/skills/init/assets
printf '0.30.0\n' > vendor/claude-arsenal/plugins/core/skills/init/assets/.bundle-version
git add -A && git commit -q -m "vendored subtree at the newer version"

# no vendor-skills.sh and no init.py here, so nothing can move the bundle:
# exactly the situation the old code called a success.
out=$(ARSENAL_BUNDLE_DIR=claude-arsenal ARSENAL_PREFIX=vendor/claude-arsenal \
      ARSENAL_REMOTE=nope bash bin/check_update.sh 2>&1 || true)
if grep -q "updated to v" <<<"${out}"; then
    grep -q "still reads" <<<"${out}" \
        || fail "must not report a completed update while the bundle version is unchanged: ${out}"
fi

# --- 10: a vendored init skill OLDER than the bundle is reported --------------
#     init.py's downgrade refusal ships inside the skill, so a host vendored at
#     2.4.0 has a copy that predates it: step 0(b) rewrites twelve bundle files
#     backwards under an "Upgrading" banner and nothing objects. This script is
#     the newer of the two in exactly that case, so it is the only side that can
#     say so — and it must say it with no remote and under --check-only, since
#     the comparison is local.
skew="${tmp}/skew"
mkdir -p "${skew}/claude-arsenal" "${skew}/.claude/skills/init/assets"
git init -q -b main "${skew}"
printf '2.4.9\n' > "${skew}/claude-arsenal/.bundle-version"
printf '2.4.0\n' > "${skew}/.claude/skills/init/assets/.bundle-version"
(cd "${skew}" && ARSENAL_REMOTE=nope bash "${CHECK}" --check-only 2>"${tmp}/skew-err.log" >/dev/null) \
    || fail "check_update.sh exited non-zero on the skew case"
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-err.log" \
    || fail "a skill older than the bundle was not reported: $(cat "${tmp}/skew-err.log")"
grep -q "2\.4\.9" "${tmp}/skew-err.log" || fail "the report does not name the bundle version"
grep -q "2\.4\.0" "${tmp}/skew-err.log" || fail "the report does not name the skill version"
grep -q "0(b)" "${tmp}/skew-err.log" \
    || fail "the report does not name the step that would perform the downgrade"

# ...and the safe directions stay quiet, or the warning is noise every session.
printf '2.4.16\n' > "${skew}/.claude/skills/init/assets/.bundle-version"
(cd "${skew}" && ARSENAL_REMOTE=nope bash "${CHECK}" --check-only 2>"${tmp}/skew-ok.log" >/dev/null)
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-ok.log" \
    && fail "a skill NEWER than the bundle must not be reported as behind it"
printf '2.4.9\n' > "${skew}/.claude/skills/init/assets/.bundle-version"
(cd "${skew}" && ARSENAL_REMOTE=nope bash "${CHECK}" --check-only 2>"${tmp}/skew-eq.log" >/dev/null)
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-eq.log" \
    && fail "matching versions must not be reported as skew"
echo "PASS: a vendored skill older than the bundle is reported bundle-side"

# --- 10b: another skill's nested init/assets must not be read instead ---------
#     The probe used `find -path '*/init/assets/.bundle-version' | head -1`,
#     which is neither anchored to `.claude/skills/init/` nor sorted. A second
#     vendored skill carrying that nested path can match too, and `find` emits
#     filesystem order — so which one `head -1` got was luck, and on the wrong
#     draw the bundle was compared against a DIFFERENT skill's version (#244).
#
#     Real `find` cannot be made to lose that draw on demand, which is the bug's
#     whole character, so the ordering is forced with a stub that answers the
#     skew probe's query decoy-first and delegates everything else. The decoy is
#     NEWER than the bundle and the real init skill is older: read the decoy and
#     the comparison returns false, the probe stays silent, and step 0(b)
#     performs the downgrade this guard exists to prevent — it fails open.
stub_bin="${tmp}/stub-bin"
mkdir -p "${stub_bin}"
cat > "${stub_bin}/find" <<'STUB'
#!/usr/bin/env bash
# Answer the skew probe's exact query decoy-first; delegate anything else.
if [[ "$*" == *"init/assets/.bundle-version"* ]]; then
    printf '%s\n' ".claude/skills/zzz-other/init/assets/.bundle-version"
    printf '%s\n' ".claude/skills/aaa-decoy/init/assets/.bundle-version"
    printf '%s\n' ".claude/skills/init/assets/.bundle-version"
    exit 0
fi
exec /usr/bin/env -i PATH=/usr/bin:/bin find "$@"
STUB
chmod +x "${stub_bin}/find"

mkdir -p "${skew}/.claude/skills/aaa-decoy/init/assets"
printf '9.9.9\n' > "${skew}/.claude/skills/aaa-decoy/init/assets/.bundle-version"
printf '2.4.0\n' > "${skew}/.claude/skills/init/assets/.bundle-version"
(cd "${skew}" && PATH="${stub_bin}:${PATH}" ARSENAL_REMOTE=nope bash "${CHECK}" --check-only \
    2>"${tmp}/skew-decoy.log" >/dev/null) \
    || fail "check_update.sh exited non-zero with a decoy skill present"
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-decoy.log" \
    || fail "a decoy skill's version was read instead of .claude/skills/init: $(cat "${tmp}/skew-decoy.log")"
grep -q "2\.4\.0" "${tmp}/skew-decoy.log" \
    || fail "the report does not name the canonical skill's version"
grep -q "9\.9\.9" "${tmp}/skew-decoy.log" \
    && fail "the report named the decoy skill's version"
echo "PASS: the skew probe reads .claude/skills/init, not whatever find hits first"

# --- 10c: with no canonical copy and several candidates, DECLINE (#253) -------
#     v2.4.22 sorted the fallback, which made it deterministic. Determinism is
#     not correctness: with two or more candidates it still picked one — the
#     lexicographically first, which has nothing to do with which skill owns the
#     bundle — and reported a confident verdict about it. `sort` converted
#     "wrong on some machines" into "wrong on every machine, reproducibly".
#
#     `aaa-first` is CURRENT and sorts first; `zzz-second` is the stale one. The
#     sorted fallback reads aaa-first, `_semver_gt` returns false, the probe
#     stays SILENT — and step 0(b) then runs a skill that rewrites the bundle
#     backwards. That is the exact fail-open #244 exists to prevent, surviving in
#     the narrower case. A probe that cannot identify its own subject must say so
#     rather than answer anyway.
rm -rf "${skew}/.claude/skills/init" "${skew}/.claude/skills/aaa-decoy"
mkdir -p "${skew}/.claude/skills/aaa-first/init/assets" \
         "${skew}/.claude/skills/zzz-second/init/assets"
printf '9.9.9\n' > "${skew}/.claude/skills/aaa-first/init/assets/.bundle-version"
printf '2.4.0\n' > "${skew}/.claude/skills/zzz-second/init/assets/.bundle-version"
(cd "${skew}" && ARSENAL_REMOTE=nope bash "${CHECK}" --check-only \
    2>"${tmp}/skew-amb.log" >/dev/null) \
    || fail "check_update.sh exited non-zero on the ambiguous case"
grep -q "AMBIGUOUS VENDORED SKILL" "${tmp}/skew-amb.log" \
    || fail "TWO CANDIDATES AND NO CANONICAL FILE WERE ANSWERED ANYWAY: $(cat "${tmp}/skew-amb.log")"
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-amb.log" \
    && fail "a verdict was reported about a skill the probe cannot identify"
grep -q "aaa-first" "${tmp}/skew-amb.log" \
    || fail "the refusal should name the candidates it found: $(cat "${tmp}/skew-amb.log")"
grep -q "0(b)" "${tmp}/skew-amb.log" \
    || fail "the refusal should say the guard is inert for step 0(b): $(cat "${tmp}/skew-amb.log")"
echo "PASS: an ambiguous vendored layout is declined, not guessed at"

# ...and ONE candidate with no canonical copy is still answered — declining
# there would disable the guard for every host with an unusual but unambiguous
# layout, which is the fallback's whole reason to exist.
rm -rf "${skew}/.claude/skills/aaa-first"
(cd "${skew}" && ARSENAL_REMOTE=nope bash "${CHECK}" --check-only \
    2>"${tmp}/skew-one.log" >/dev/null) \
    || fail "check_update.sh exited non-zero on the single-candidate case"
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-one.log" \
    || fail "a single unambiguous candidate must still be reported: $(cat "${tmp}/skew-one.log")"
grep -q "AMBIGUOUS" "${tmp}/skew-one.log" \
    && fail "one candidate is not ambiguous"
echo "PASS: a single fallback candidate is still resolved and reported"

rm -rf "${skew}/.claude/skills/zzz-second"

rm -rf "${stub_bin}"
mkdir -p "${skew}/.claude/skills/init/assets"
printf '2.4.9\n' > "${skew}/.claude/skills/init/assets/.bundle-version"

# --- 11: the update hint fits the layout it is printed for --------------------
#     `consumer` installed by copy, not by subtree, so both halves of the
#     suggested command fail there — the tag's tree has no claude-arsenal/ at
#     its root to merge from. It was suggested anyway.
out="$(cd "${consumer}" && bash "${CHECK}" --check-only 2>/dev/null)"
grep -q "UPDATE AVAILABLE" <<<"${out}" || fail "expected an available update, got: ${out}"
grep -q "git subtree merge" <<<"${out}" \
    && fail "a non-subtree install was told to run a subtree merge that cannot work: ${out}"
grep -q "plugin update claude-arsenal" <<<"${out}" \
    || fail "a non-subtree install was not given a route that works: ${out}"

git -C "${subtree_consumer}" remote add arsenal "${market}"
out="$(cd "${subtree_consumer}" && bash "${CHECK}" --check-only 2>/dev/null)"
grep -q "git subtree merge" <<<"${out}" \
    || fail "a real subtree must still get the subtree command: ${out}"
echo "PASS: the update hint matches how the bundle was installed"

# --- 12: CHANGELOG entries print alongside the update message ----------------
#     check_update.sh already knew a newer tag existed; it used to say only
#     that. A consumer with no reason to browse the marketplace's own commit
#     history had no way to learn what an update actually contains.
cat > "${market}/plugins/core/skills/init/assets/CHANGELOG.md" <<'EOF'
# Changelog

## [0.23.0] - 2026-02-01

- Newest entry, in range — must print.

## [0.22.0] - 2026-01-15

- Middle entry, in range — must print.

## [0.21.0] - 2026-01-01

- AT the consumer's installed version — must NOT print.

## [0.20.5] - 2025-12-01

- Older than installed — must NOT print.
EOF
git -C "${market}" add -A
git -C "${market}" commit -q -m "docs: changelog through 0.23.0"
git -C "${market}" tag -a v0.23.0 -m "Release v0.23.0"

out="$(run_check)" || fail "check_update.sh exited non-zero with a CHANGELOG.md present"
grep -q "Newest entry, in range" <<<"${out}" || fail "the 0.23.0 changelog entry did not print: ${out}"
grep -q "Middle entry, in range" <<<"${out}" || fail "the 0.22.0 changelog entry did not print: ${out}"
grep -q "must NOT print" <<<"${out}" && fail "an entry at or before the installed version printed: ${out}"
newest_at=$(grep -n "Newest entry" <<<"${out}" | cut -d: -f1)
middle_at=$(grep -n "Middle entry" <<<"${out}" | cut -d: -f1)
[[ -n "${newest_at}" && -n "${middle_at}" && "${newest_at}" -lt "${middle_at}" ]] \
    || fail "changelog entries must print newest first: ${out}"
echo "PASS: check_update.sh prints CHANGELOG entries strictly between installed and latest"

# --- Gate: "Exit: 0 always" holds when the remote is unreachable (#301) -----
# This script's own header promises it never aborts a session, because
# session-start step 0(a) runs it as a *report*. Under `set -euo pipefail` the
# unguarded `git ls-remote` in _report_untagged_upstream made a credential-less
# or unreachable remote exit 128 instead — taking with it the rest of the
# report, so the session carried on knowing nothing about a stale bundle.
offline="${tmp}/offline"
mkdir -p "${offline}/claude-arsenal"
git init -q -b main "${offline}"
git -C "${offline}" config user.email "test@arsenal.example"
git -C "${offline}" config user.name "Arsenal Test"
echo "0.20.5" > "${offline}/claude-arsenal/.bundle-version"
git -C "${offline}" add -A
git -C "${offline}" commit -q -m "chore: vendor bundle"
git -C "${offline}" remote add arsenal "${tmp}/no-such-repository"

set +e
(cd "${offline}" && bash "${CHECK}" >"${tmp}/offline.out" 2>"${tmp}/offline.err")
offline_code=$?
set -e
[[ ${offline_code} -eq 0 ]] \
    || fail "an unreachable remote aborted the report with exit ${offline_code}; the header promises 0 always"
[[ -s "${tmp}/offline.err" ]] \
    || fail "the unreachable-remote case said nothing at all"
echo "PASS: an unreachable remote is a warning, not an abort"

# --- 14: a CONFLICTING subtree merge must leave no merge in progress ---------
#     The clean-tree check above is what the worker loop relies on, and a
#     conflicting `git subtree merge` used to leave MERGE_HEAD, a populated
#     index and conflict markers behind while this script warned and exited 0 --
#     so the session reported no failure and workers ran against a tree the
#     script had just declared clean.
cmarket="${tmp}/cmarket"
mkdir -p "${cmarket}/$(dirname "${UPSTREAM_VERSION_PATH}")"
git init -q -b main "${cmarket}"
git -C "${cmarket}" config user.email "test@arsenal.example"
git -C "${cmarket}" config user.name "Arsenal Test"
echo "0.20.5" > "${cmarket}/${UPSTREAM_VERSION_PATH}"
echo "upstream original" > "${cmarket}/shared.txt"
git -C "${cmarket}" add -A
git -C "${cmarket}" commit -q -m "chore: release 0.20.5"
git -C "${cmarket}" tag -a v0.20.5 -m "Release v0.20.5"

cconsumer="${tmp}/cconsumer"
git init -q -b main "${cconsumer}"
git -C "${cconsumer}" config user.email "test@arsenal.example"
git -C "${cconsumer}" config user.name "Arsenal Test"
echo "seed" > "${cconsumer}/README.md"
git -C "${cconsumer}" add -A
git -C "${cconsumer}" commit -q -m "chore: seed"
git -C "${cconsumer}" remote add arsenal "${cmarket}"
git -C "${cconsumer}" fetch -q arsenal
# A real subtree, so `_is_subtree` passes and the update path reaches the merge.
git -C "${cconsumer}" subtree add -q --prefix=claude-arsenal arsenal main --squash \
    >/dev/null 2>&1 || { echo "SKIP: git subtree unavailable"; git -C "${cconsumer}" rev-parse HEAD >/dev/null; }

if git -C "${cconsumer}" rev-parse HEAD:claude-arsenal >/dev/null 2>&1; then
    # Both sides edit the same line under the prefix, and upstream publishes a
    # newer tag. The squash merge then has a conflict it cannot resolve.
    echo "consumer edit" > "${cconsumer}/claude-arsenal/shared.txt"
    git -C "${cconsumer}" add -A
    git -C "${cconsumer}" commit -q -m "chore: local edit under the prefix"
    echo "upstream edit" > "${cmarket}/shared.txt"
    echo "0.23.0" > "${cmarket}/${UPSTREAM_VERSION_PATH}"
    git -C "${cmarket}" add -A
    git -C "${cmarket}" commit -q -m "chore: release 0.23.0"
    git -C "${cmarket}" tag -a v0.23.0 -m "Release v0.23.0"

    conflict_code=0
    (cd "${cconsumer}" && bash "${CHECK}" >/dev/null 2>"${tmp}/conflict.err") || conflict_code=$?
    [[ ${conflict_code} -eq 0 ]] \
        || fail "a conflicting update aborted the session with exit ${conflict_code}; the header promises 0 always"
    if git -C "${cconsumer}" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
        fail "a conflicting subtree merge left MERGE_HEAD behind: the worker loop would run against a mid-merge tree"
    fi
    git -C "${cconsumer}" grep -q '^<<<<<<< ' -- claude-arsenal \
        && fail "conflict markers were left under the prefix"
    echo "PASS: a conflicting subtree merge is aborted, not left in the tree"
else
    echo "SKIP: git subtree add did not produce a subtree here"
fi

echo "PASS: check_update_test — all gates passed"
exit 0
