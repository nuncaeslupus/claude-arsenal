#!/usr/bin/env bash
# windows_compat_test.sh — the bundle runs on Windows + Git Bash, not only POSIX.
#
# Five of these were reported from one consumer's 4.4.0 -> 4.16.0 update on
# Windows 11 + Git Bash + cp1252, where the first three together made
# `merge_ready.sh` unreachable: the one protocol step with a configured answer
# could not be taken at all.
#
# Most of it is asserted on Linux by construction — a cp1252 stream is
# reproducible anywhere with PYTHONIOENCODING, and CRLF is just bytes. The two
# path fixes cannot be executed here (no `cygpath`, no native python.exe), so
# those two cases assert the fix is present and, as importantly, that it is the
# identity on this platform.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUNDLE="${ROOT}/plugins/core/skills/init/assets"
INIT_PY="${ROOT}/plugins/core/skills/init/scripts/init.py"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

# --- 1. a legacy console codepage must not kill a script -------------------

# Every shipped entry point, not just the three that happen to print an arrow
# today: any of them can emit a non-ASCII byte read out of a task title or a PR
# title, and on a cp1252 console that is an UnicodeEncodeError, not a mojibake.
missing=""
while IFS= read -r py; do
    grep -q '__main__' "${py}" || continue
    awk '/^if __name__ == "__main__":/{f=1} f && /reconfigure/{found=1} END{exit !found}' \
        "${py}" || missing="${missing} ${py#"${ROOT}/"}"
done < <(find "${ROOT}/plugins" -name '*.py' \
    -not -path '*/tests/*' -not -path '*/__pycache__/*' \
    \( -path '*/scripts/*' -o -path '*/bin/*' -o -path '*/hooks/*' \))
[[ -z "${missing}" ]] || fail "entry point(s) with no UTF-8 stream guard:${missing}"
pass "every shipped entry point reconfigures stdout/stderr before running"

# And it actually survives the codepage that broke it. U+2192 has no cp1252
# encoding; U+2014 does, which is why the failure looked intermittent.
cat > "${tmp}/arrow.py" <<'PY'
import sys

if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    print("Upgrading claude-arsenal bundle: 4.4.0 → 4.16.0")
PY
PYTHONIOENCODING=cp1252 python3 "${tmp}/arrow.py" >/dev/null 2>"${tmp}/arrow.err" \
    || fail "the guard did not survive a cp1252 stream: $(cat "${tmp}/arrow.err")"
grep -q 'UnicodeEncodeError' "${tmp}/arrow.err" \
    && fail "UnicodeEncodeError still raised under cp1252"
pass "a U+2192 progress line survives a cp1252 stream"

# --- 2. `gh api` is given a slashless endpoint ------------------------------

# Git Bash rewrites any leading-slash argument into a Windows path, and `gh`
# rejects the result. The curl branch still needs the slash: it concatenates.
grep -q 'api -X "${method}" "${path#/}"' "${BUNDLE}/bin/github_channel.sh" \
    || fail "github_channel.sh: gh branch does not strip the leading slash"
grep -q 'https://api.github.com${path}"' "${BUNDLE}/bin/github_channel.sh" \
    || fail "github_channel.sh: curl branch no longer builds an absolute URL"
pass "gh gets a slashless endpoint, curl keeps its slash"

# --- 3. python is handed a path it can open ---------------------------------

# A python.org interpreter reads `/c/Users/...` as relative to the drive root.
# Every bundle script that hands python3 a path built from its own directory
# resolves that directory through cygpath first.
for sh in adversarial_review merge_ready claim_task open_task_pr host_setup \
          rebase_stack gate_run check_skill_workshop_loaded; do
    grep -q 'cygpath -m' "${BUNDLE}/bin/${sh}.sh" \
        || fail "${sh}.sh hands python3 a path it never normalises"
done
pass "every bundle script that runs python3 normalises its own directory first"

# It has to be the identity here, or it breaks the platform it was not for.
have_cygpath=0
command -v cygpath >/dev/null 2>&1 && have_cygpath=1
[[ ${have_cygpath} -eq 0 ]] || echo "  (note: cygpath present; the no-op check is vacuous here)"
bash "${BUNDLE}/bin/merge_ready.sh" --help >/dev/null 2>&1
[[ $? -le 2 ]] || fail "merge_ready.sh no longer starts on this platform"
pass "the normalisation is a no-op where there is no cygpath"

# --- 4. CRLF is not a content change ----------------------------------------

# With core.autocrlf=true the working copy is CRLF and the bundle ships LF, so a
# byte comparison called 38 unchanged files "refreshed" — in the one report a
# consumer reads to tell a real update from noise.
mkdir -p "${tmp}/repo"
git -C "${tmp}/repo" init -q 2>/dev/null || fail "cannot init a scratch repo"
python3 "${INIT_PY}" --repo-path "${tmp}/repo" --silent >/dev/null 2>&1 \
    || fail "init.py does not complete on a fresh repo"
victim="${tmp}/repo/claude-arsenal/bin/merge_ready.sh"
[[ -f "${victim}" ]] || fail "expected a vendored bin/merge_ready.sh"
python3 - "${victim}" <<'PY'
import sys
from pathlib import Path

p = Path(sys.argv[1])
p.write_bytes(p.read_bytes().replace(b"\n", b"\r\n"))
PY
out="$(python3 "${INIT_PY}" --repo-path "${tmp}/repo" 2>&1)" \
    || fail "init.py failed on the CRLF re-run"
grep -q 'refreshed:  bin/merge_ready.sh' <<<"${out}" \
    && fail "a CRLF-only difference is still reported as a refresh"
pass "a CRLF working copy is not reported as 38 files refreshed"

# --- 5. the tree says where it came from ------------------------------------

# A non-subtree install has no `arsenal` remote by definition. Until this was
# recorded, nothing else in the vendored tree named upstream either, and a
# consumer twelve minor versions behind had to ask for the URL.
manifest="${tmp}/repo/claude-arsenal/.arsenal-manifest"
[[ -f "${manifest}" ]] || fail "no .arsenal-manifest written"
url="$(sed -n 's/^# source: //p' "${manifest}" | head -1)"
[[ -n "${url}" ]] || fail ".arsenal-manifest records no source URL"
pass "the vendored tree records where it was installed from (${url})"

# The path list must still be readable as a path list.
grep -q '^bin/merge_ready.sh$' "${manifest}" \
    || fail "the provenance line displaced the manifest's path list"
pass "the provenance line is a comment, not a path entry"

# And the message a consumer reads at the moment they need it names the URL.
report="$(cd "${tmp}/repo" && bash claude-arsenal/bin/check_update.sh 2>&1)"
grep -q -- "${url}" <<<"${report}" \
    || fail "the INERT report still says <marketplace-url>: ${report}"
pass "check_update.sh's INERT report names the recorded upstream"

# --- 6. the gate blocks writes, not reads -----------------------------------

GATE="${ROOT}/plugins/skill-workshop/hooks/gate_target.py"
gate() { printf '%s' "$1" | python3 "${GATE}"; }

read_cmd='python3 -c '"'"'import os
for d, _, fs in os.walk("plugins/core/skills/init/scripts"):
    print(d, fs)'"'"''
payload="$(python3 - "${read_cmd}" <<'PY'
import json
import sys

print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
PY
)"
[[ -z "$(gate "${payload}")" ]] \
    || fail "an os.walk over a skill folder is still refused as a write"
pass "a read-only tree scan is not blocked"

write_cmd='python3 -c '"'"'import os
for d, _, fs in os.walk("plugins/core/skills/init/scripts"):
    open("plugins/core/skills/init/scripts/init.py", "w").close()'"'"''
payload="$(python3 - "${write_cmd}" <<'PY'
import json
import sys

print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
PY
)"
[[ -n "$(gate "${payload}")" ]] \
    || fail "a truncating open() inside an os.walk slipped past the gate"
pass "a write inside the same scan is still refused"

echo "PASS: windows_compat_test — all gates passed"
