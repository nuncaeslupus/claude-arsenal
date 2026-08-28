#!/usr/bin/env bash
# detect_surface_test.sh — the surface probe names every cloud surface, not just the web app.
#
# CLAUDE_CODE_REMOTE is set by the desktop and mobile apps, Claude Tag and routines as
# well as by the web app, so `surface:web` named a subset of what it matched. The probe
# emits `surface:cloud` for that branch and keeps `surface:web` beside it, because task
# files already written against the old spelling must keep matching.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CANONICAL="${REPO_ROOT}/plugins/core/skills/init/assets/bin/detect_surface.sh"
HOOK_COPY="${REPO_ROOT}/plugins/core/hooks/detect_surface.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}" || fail "cannot enter tmpdir"
mkdir -p arsenal/session

caps() { python3 -c 'import json,sys;print(" ".join(json.load(open(sys.argv[1]))["capabilities"]))' "$1"; }
surface() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["surface"])' "$1"; }

PROFILE="arsenal/session/surface_profile.json"

# --- 1: a local session is surface:cli and nothing cloud-shaped ---
env -u CLAUDE_CODE_REMOTE bash "${CANONICAL}" || fail "probe exited non-zero on cli"
c=$(caps "${PROFILE}")
s=$(surface "${PROFILE}")
[[ "${s}" == "cli" ]] || fail "expected surface=cli, got '${s}'"
grep -q 'surface:cli' <<<"${c}" || fail "cli session must offer surface:cli, got '${c}'"
grep -q 'surface:cloud\|surface:web' <<<"${c}" && fail "cli session must not offer a cloud capability: '${c}'"

# --- 2: a cloud session offers the new name AND the old one ---
CLAUDE_CODE_REMOTE=true bash "${CANONICAL}" || fail "probe exited non-zero on cloud"
c=$(caps "${PROFILE}")
s=$(surface "${PROFILE}")
[[ "${s}" == "cloud" ]] || fail "expected surface=cloud, got '${s}'"
grep -q 'surface:cloud' <<<"${c}" || fail "cloud session must offer surface:cloud, got '${c}'"
grep -q 'surface:web' <<<"${c}" || fail "surface:web must stay granted so old task files keep matching, got '${c}'"
grep -q 'surface:cli' <<<"${c}" && fail "cloud session must not claim surface:cli: '${c}'"

# --- 3: no arsenal/session/ means no write — the probe runs in uninitialised repos too ---
rm -rf arsenal
CLAUDE_CODE_REMOTE=true bash "${CANONICAL}" || fail "probe must exit 0 when uninitialised"
[[ ! -e "${PROFILE}" ]] || fail "probe wrote a profile into an uninitialised repo"

# --- 4: the hook copy has not drifted from the canonical one ---
diff -q "${CANONICAL}" "${HOOK_COPY}" >/dev/null \
    || fail "plugins/core/hooks/detect_surface.sh has drifted from the canonical copy"

echo "PASS: the surface probe grants surface:cloud and surface:web together, and cli alone"
