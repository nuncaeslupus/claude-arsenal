#!/usr/bin/env bash
# budget_check.sh — pre-dispatch quota guard for the worker loop.
#
# Reads claude-arsenal/session/rate_limits.json (written by statusline_capture.sh)
# and decides whether the loop may dispatch more workers.
#
# Exit:
#   3 — either window's used_percentage is at/above ARSENAL_QUOTA_STOP_PCT
#       (default 90). Loud and distinct so the loop STOPS and writes a handover.
#   0 — under threshold, OR data is missing/unparseable/absent fields. The
#       missing-data case is a deliberate FAIL-OPEN: the loop keeps running
#       where quota is not observable (API/metered usage, non-Pro/Max plan,
#       before the first response, or older Claude Code).

set -uo pipefail

FILE="${ARSENAL_RATE_LIMITS_FILE:-claude-arsenal/session/rate_limits.json}"
STOP_PCT="${ARSENAL_QUOTA_STOP_PCT:-90}"

python3 - "${FILE}" "${STOP_PCT}" <<'PY'
import sys, json, pathlib

file = pathlib.Path(sys.argv[1])
try:
    stop = float(sys.argv[2])
except ValueError:
    stop = 90.0

if not file.exists():
    print("budget_check: no rate_limits.json — failing open", file=sys.stderr)
    sys.exit(0)

try:
    data = json.loads(file.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("not a dict")
except Exception:
    print("budget_check: rate_limits.json unparseable or invalid — failing open", file=sys.stderr)
    sys.exit(0)

worst = None
over = []
for window in ("five_hour", "seven_day"):
    w = data.get(window) or {}
    v = w.get("used_percentage")
    if isinstance(v, (int, float)):
        worst = v if worst is None else max(worst, v)
        if v >= stop:
            over.append((window, v, w.get("resets_at")))

if worst is None:
    print("budget_check: no used_percentage in rate_limits.json — failing open", file=sys.stderr)
    sys.exit(0)

if over:
    for window, v, resets in over:
        msg = f"budget_check: {window} at {v:.0f}% >= {stop:.0f}% stop threshold"
        if resets:
            msg += f" (resets_at={resets})"
        print(msg, file=sys.stderr)
    sys.exit(3)

print(f"budget_check: ok (worst window {worst:.0f}% < {stop:.0f}%)")
sys.exit(0)
PY
