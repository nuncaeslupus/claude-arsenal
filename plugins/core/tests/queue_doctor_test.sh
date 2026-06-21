#!/usr/bin/env bash
# queue_doctor_test.sh — unit test for queue_doctor.py (offline layers only).
# Verifies the structural / dependency / invariant / pr-field / payload / secret
# checks fire on a crafted bad queue, that secrets are redacted (never echoed in
# full), and that a clean queue exits 0.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR="${SCRIPT_DIR}/../skills/init/assets/scripts/queue_doctor.py"

if [[ ! -f "${DOCTOR}" ]]; then
    echo "SKIP: queue_doctor.py not found at ${DOCTOR}" >&2; exit 0
fi

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

qdir="${tmp}/claude-arsenal/queue"
mkdir -p "${qdir}"

# --- A queue seeded with one of every inconsistency the doctor detects. ---
cat > "${qdir}/tasks.jsonl" <<'QUEUE'
{"id":"lo-a1","title":"A","status":"open","deps":[],"payload":"lo-a1.md"}
{"id":"lo-a1","title":"dup","status":"open"}
{"id":"lo-b2","title":"B","status":"weird"}
{"id":"lo-c3","title":"C","status":"open","deps":[{"id":"lo-zzz","type":"blocks"}]}
{"id":"lo-d4","title":"D","status":"in_progress"}
{"id":"lo-e5","title":"E","status":"done"}
{"id":"lo-f6","title":"F","status":"done","pr":"branch:arsenal/lo-f6-x"}
{"id":"lo-g7","title":"G","status":"open","assignee":"sess-1"}
{"id":"lo-h8","title":"H","status":"open","deps":[{"id":"lo-i9","type":"blocks"}]}
{"id":"lo-i9","title":"I","status":"escalated"}
{"id":"lo-j0","title":"J","status":"open","payload":"missing.md"}
{"id":"lo-k1","title":"K1","status":"open","deps":[{"id":"lo-k2","type":"blocks"}]}
{"id":"lo-k2","title":"K2","status":"open","deps":[{"id":"lo-k1","type":"blocks"}]}
this is not json
QUEUE

# Payload for lo-a1 carries two planted secrets; orphan.md has no queue row.
SECRET_AWS="AKIAIOSFODNN7EXAMPLE"
cat > "${qdir}/lo-a1.md" <<EOF
# A
## Acceptance gate
prose only
\`\`\`bash
curl -H "api_key = sk-abcdef0123456789ABCDEF" https://example.com
export AWS_ACCESS_KEY_ID=${SECRET_AWS}
\`\`\`
EOF
echo "# orphan" > "${qdir}/orphan.md"

out="$(python3 "${DOCTOR}" --queue "${qdir}/tasks.jsonl" 2>&1)"; rc=$?

fail() { echo "FAIL: $1" >&2; echo "--- doctor output ---" >&2; echo "${out}" >&2; exit 1; }

[[ "${rc}" -eq 1 ]] || fail "bad queue should exit 1 (fail-on=warn), got ${rc}"

for code in duplicate-id bad-status dangling-dep stranded-in-progress \
            terminal-without-pr done-from-branch stale-assignee blocked-on-escalated \
            missing-payload orphan-payload bad-json dep-cycle secret-in-payload; do
    printf '%s' "${out}" | grep -q "\[${code}\]" || fail "expected finding [${code}] not reported"
done
echo "PASS: all expected finding codes reported on the bad queue"

# Secrets must be redacted — the full value must never appear in output.
if printf '%s' "${out}" | grep -q "${SECRET_AWS}"; then
    fail "secret value was printed in full (must be redacted)"
fi
echo "PASS: planted secret is redacted in output"

# --- A clean queue exits 0 with no findings. ---
cdir="${tmp}/clean/claude-arsenal/queue"
mkdir -p "${cdir}"
cat > "${cdir}/tasks.jsonl" <<'QUEUE'
{"id":"lo-ok1","title":"ok","status":"open","deps":[],"payload":"lo-ok1.md"}
{"id":"lo-ok2","title":"done ok","status":"merged","pr":"https://example.com/pr/9","deps":[{"id":"lo-ok1","type":"blocks"}]}
QUEUE
echo "# ok" > "${cdir}/lo-ok1.md"

cout="$(python3 "${DOCTOR}" --queue "${cdir}/tasks.jsonl" 2>&1)"; crc=$?
if [[ "${crc}" -ne 0 ]]; then
    echo "FAIL: clean queue should exit 0, got ${crc}" >&2
    echo "${cout}" >&2; exit 1
fi
printf '%s' "${cout}" | grep -q "0 error, 0 warn" || { echo "FAIL: clean queue had findings: ${cout}" >&2; exit 1; }
echo "PASS: clean queue exits 0 with no findings"

# --- --closed-issues: a task whose linked issue is closed is flagged. ---
# Stub `gh` on PATH so the check is hermetic (no network / real issues).
stub="${tmp}/stub"; mkdir -p "${stub}"
cat > "${stub}/gh" <<'GH'
#!/usr/bin/env bash
echo '{"state":"CLOSED"}'
GH
chmod +x "${stub}/gh"
idir="${tmp}/iss/claude-arsenal/queue"; mkdir -p "${idir}"
printf '%s\n' '{"id":"iss-9","title":"linked","status":"open","deps":[],"payload":"iss-9.md","issue":9}' > "${idir}/tasks.jsonl"
echo "# linked" > "${idir}/iss-9.md"
iout="$(PATH="${stub}:${PATH}" python3 "${DOCTOR}" --queue "${idir}/tasks.jsonl" --closed-issues 2>&1)"
printf '%s' "${iout}" | grep -q "\[closed-issue\]" || { echo "FAIL: closed linked issue not flagged: ${iout}" >&2; exit 1; }
echo "PASS: --closed-issues flags a task whose linked issue is closed"

# Without the issue field, --closed-issues makes no gh calls and finds nothing.
nout="$(PATH="${stub}:${PATH}" python3 "${DOCTOR}" --queue "${cdir}/tasks.jsonl" --closed-issues 2>&1)"
printf '%s' "${nout}" | grep -q "\[closed-issue\]" && { echo "FAIL: closed-issue fired with no issue field" >&2; exit 1; }
echo "PASS: --closed-issues is a no-op for tasks without an issue field"

# --- --lease-ttl: stale in_progress lease (crashed claim) is flagged (#72). ---
ldir="${tmp}/lease/claude-arsenal/queue"; mkdir -p "${ldir}"
OLD_TS=$(python3 -c "from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(hours=2)).replace(microsecond=0).isoformat())")
NEW_TS=$(python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).replace(microsecond=0).isoformat())")
cat > "${ldir}/tasks.jsonl" <<QUEUE
{"id":"lo-stale","title":"stale","status":"in_progress","assignee":"sess-x","claimed_at":"${OLD_TS}","deps":[],"payload":"lo-stale.md"}
{"id":"lo-fresh","title":"fresh","status":"in_progress","assignee":"sess-y","claimed_at":"${NEW_TS}","deps":[],"payload":"lo-fresh.md"}
{"id":"lo-nolease","title":"nolease","status":"in_progress","assignee":"sess-z","deps":[],"payload":"lo-nolease.md"}
{"id":"lo-badlease","title":"badlease","status":"in_progress","assignee":"sess-w","claimed_at":"not-a-date","deps":[],"payload":"lo-badlease.md"}
QUEUE
echo "# x" > "${ldir}/lo-stale.md"; echo "# y" > "${ldir}/lo-fresh.md"
echo "# z" > "${ldir}/lo-nolease.md"; echo "# w" > "${ldir}/lo-badlease.md"

# ttl=0 (default) → no lease findings at all.
zout="$(python3 "${DOCTOR}" --queue "${ldir}/tasks.jsonl" --fail-on error 2>&1)"
printf '%s' "${zout}" | grep -qE "\[(stale-lease|no-lease|bad-lease)\]" \
    && { echo "FAIL: lease checks fired with --lease-ttl 0 (should be disabled): ${zout}" >&2; exit 1; }
echo "PASS: lease age check is disabled by default (--lease-ttl 0)"

# ttl=3600 → stale (2h old) flagged, fresh (just now) not; missing/invalid noted.
lout="$(python3 "${DOCTOR}" --queue "${ldir}/tasks.jsonl" --lease-ttl 3600 --fail-on error 2>&1)"
printf '%s' "${lout}" | grep -q "\[stale-lease\] lo-stale" \
    || { echo "FAIL: stale lease lo-stale not flagged: ${lout}" >&2; exit 1; }
printf '%s' "${lout}" | grep -q "\[stale-lease\] lo-fresh" \
    && { echo "FAIL: fresh lease lo-fresh wrongly flagged stale: ${lout}" >&2; exit 1; }
printf '%s' "${lout}" | grep -q "\[no-lease\] lo-nolease" \
    || { echo "FAIL: lo-nolease not flagged no-lease: ${lout}" >&2; exit 1; }
printf '%s' "${lout}" | grep -q "\[bad-lease\] lo-badlease" \
    || { echo "FAIL: lo-badlease not flagged bad-lease: ${lout}" >&2; exit 1; }
echo "PASS: --lease-ttl flags stale leases, spares fresh ones, notes missing/invalid"

echo "PASS: queue_doctor_test — all gates passed"
exit 0
