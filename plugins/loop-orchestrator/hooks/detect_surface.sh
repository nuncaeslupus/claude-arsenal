#!/usr/bin/env bash
# detect_surface.sh — SessionStart hook: writes .loop/state/surface_profile.json.
# Detects surface (cli/web) via CLAUDE_CODE_REMOTE and probes available services.
# Exits 0 always; writes a conservative (minimal) profile on any error.

STATE_DIR=".loop/state"
PROFILE="${STATE_DIR}/surface_profile.json"

main() {
    # No-op if repo has not been initialised with loop-init yet.
    [[ -d "${STATE_DIR}" ]] || return 0

    # Surface detection.
    if [[ "${CLAUDE_CODE_REMOTE:-}" == "true" ]]; then
        surface="web"
    else
        surface="cli"
    fi

    # Capability probes — each capped at 2 s; failure is silent.
    caps=("\"surface:${surface}\"")

    if command -v pg_isready &>/dev/null 2>&1; then
        if timeout 2 pg_isready -q 2>/dev/null; then
            caps+=("\"services:postgres\"")
        fi
    fi

    if command -v redis-cli &>/dev/null 2>&1; then
        if timeout 2 redis-cli ping 2>/dev/null | grep -q PONG; then
            caps+=("\"services:redis\"")
        fi
    fi

    # Build JSON capabilities array.
    local caps_json
    caps_json=$(IFS=', '; echo "${caps[*]}")
    caps_json="[${caps_json}]"

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

    printf '{\n  "surface": "%s",\n  "capabilities": %s,\n  "detected_at": "%s"\n}\n' \
        "${surface}" "${caps_json}" "${ts}" > "${PROFILE}"
}

main "$@" || true
exit 0
