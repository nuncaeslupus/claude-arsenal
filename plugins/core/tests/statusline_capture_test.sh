#!/usr/bin/env bash
# statusline_capture_test.sh — the statusLine command persists rate_limits
# atomically, never overwrites a good snapshot with a payload that lacks them,
# and always exits 0 (a statusLine command must not break the prompt). (#612)
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail
SL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/init/assets/bin/statusline_capture.sh"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
export ARSENAL_RATE_LIMITS_FILE="${tmp}/session/rate_limits.json"

line=$(printf '{"model":{"display_name":"M"},"rate_limits":{"five_hour":{"used_percentage":42},"seven_day":{"used_percentage":7}}}' | bash "${SL}") \
    || fail "statusline_capture must exit 0"
[[ "${line}" == "M | 5h 42% | 7d 7%" ]] || fail "unexpected status line: ${line}"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["five_hour"]["used_percentage"]==42' "${ARSENAL_RATE_LIMITS_FILE}" \
    || fail "snapshot not written"

printf '{"model":{"display_name":"M"}}' | bash "${SL}" >/dev/null || fail "payload without rate_limits must exit 0"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["five_hour"]["used_percentage"]==42' "${ARSENAL_RATE_LIMITS_FILE}" \
    || fail "a payload without rate_limits clobbered the good snapshot"
echo 'not json' | bash "${SL}" >/dev/null || fail "garbage input must still exit 0"
echo "PASS: statusline_capture writes atomically, keeps a good snapshot, never fails"
