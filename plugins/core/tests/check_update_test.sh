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

# ...and with no canonical copy the fallback is what answers. It must sort, or
# the same tree hands different machines different verdicts — the hardest kind
# of report to act on. The stub hands it `zzz-other` (current) ahead of
# `aaa-decoy` (stale): unsorted, `head -1` takes the current one and the probe
# says nothing; sorted, the stale copy is found and reported.
rm -rf "${skew}/.claude/skills/init"
printf '2.4.0\n' > "${skew}/.claude/skills/aaa-decoy/init/assets/.bundle-version"
mkdir -p "${skew}/.claude/skills/zzz-other/init/assets"
printf '9.9.9\n' > "${skew}/.claude/skills/zzz-other/init/assets/.bundle-version"
(cd "${skew}" && PATH="${stub_bin}:${PATH}" ARSENAL_REMOTE=nope bash "${CHECK}" --check-only \
    2>"${tmp}/skew-fb1.log" >/dev/null) \
    || fail "check_update.sh exited non-zero on the fallback case"
grep -q "VENDORED SKILL BEHIND BUNDLE" "${tmp}/skew-fb1.log" \
    || fail "the fallback did not report a skewed skill: $(cat "${tmp}/skew-fb1.log")"
grep -q "aaa-decoy" "${tmp}/skew-fb1.log" \
    || fail "the fallback did not resolve to the sorted-first copy"
(cd "${skew}" && PATH="${stub_bin}:${PATH}" ARSENAL_REMOTE=nope bash "${CHECK}" --check-only \
    2>"${tmp}/skew-fb2.log" >/dev/null)
diff -q "${tmp}/skew-fb1.log" "${tmp}/skew-fb2.log" >/dev/null \
    || fail "the fallback lookup is not deterministic across runs"
echo "PASS: the fallback lookup is sorted, so it answers the same way twice"

rm -rf "${skew}/.claude/skills/aaa-decoy" "${skew}/.claude/skills/zzz-other" "${stub_bin}"
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

echo "PASS: check_update_test — all gates passed"
exit 0
