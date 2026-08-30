#!/usr/bin/env bash
# bundle_refs_test.sh — every bundle script a consumer is told to run must exist.
#
# This is the failure v0.25.0 shipped: the coordination-branch scripts were
# deleted, but `AGENTS.md` still told the worker loop to run
# `claude-arsenal/bin/queue_batch.sh` at its batch step, and the handover
# template still pointed at `queue_eval.sh` and `release.sh`. Nothing failed in
# this repo, because nothing here executes the instructions — the consumer finds
# out, mid-session, that the central step of the loop names a file that does not
# exist.
#
# So this test reads the shipped prose the way a consumer follows it: every
# `claude-arsenal/bin/<name>.sh`, `claude-arsenal/scripts/<name>.py` and
# `claude-arsenal/references/<name>.md` named anywhere in the bundle or the init
# skill must be a file the bundle ships. References are checked for the same
# reason the scripts are: since AGENTS.md became a short body pointing at
# `references/`, a pointer that resolves to nothing is a step of the protocol
# that silently is not there.
#
# It also holds AGENTS.md to a line budget. That file is `@`-imported by every
# consumer's CLAUDE.md, so it is in context on every turn of every session in
# every consumer repo — the one file in the bundle whose length is paid for
# continuously. It reached 762 lines once; the split into `references/` brought
# it back, and this is what stops it drifting there again.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SKILL="${SCRIPT_DIR}/../skills/init"
ASSETS="${INIT_SKILL}/assets"
[[ -d "${ASSETS}" ]] || { echo "SKIP: ${ASSETS} not found" >&2; exit 0; }

fail=0
note() { echo "FAIL: $1" >&2; fail=1; }

# Where a reference may point, and what satisfies it.
resolve() {  # $1 = referenced path, e.g. claude-arsenal/bin/gate_run.sh
    local rel="${1#claude-arsenal/}"
    [[ -f "${ASSETS}/${rel}" ]] && return 0
    # A few scripts live in the skill's own scripts/ dir rather than assets/.
    [[ -f "${INIT_SKILL}/${rel}" ]] && return 0
    return 1
}

# Search the shipped bundle and the init skill's own files. `docs/` is excluded
# on purpose: this checks what a running session is told to execute.
mapfile -t sources < <(
    find "${ASSETS}" "${INIT_SKILL}/scripts" "${INIT_SKILL}/SKILL.md" \
        -type f \( -name '*.md' -o -name '*.py' -o -name '*.sh' -o -name '*.json' \) 2>/dev/null
)

declare -A seen=()
for src in "${sources[@]}"; do
    # Only flag a reference that names a concrete file, so prose about a
    # directory ("claude-arsenal/bin/") is left alone.
    while read -r ref; do
        [[ -z "${ref}" ]] && continue
        if ! resolve "${ref}"; then
            key="${ref}|${src}"
            [[ -n "${seen[${key}]:-}" ]] && continue
            seen[${key}]=1
            note "${src#"${SCRIPT_DIR}/../"} references ${ref}, which the bundle does not ship"
        fi
    done < <(grep -oE 'claude-arsenal/(bin|scripts|references)/[A-Za-z0-9_.-]+\.(sh|py|md)' "${src}" | sort -u)
done

# Cross-skill script paths in SKILL.md bodies. These are written as
# `${CLAUDE_SKILL_DIR}/../init/assets/bin/<name>.sh`, and the skill validator
# skips them: it treats any path containing `${` as a placeholder. That blind
# spot is why `${CLAUDE_SKILL_DIR}/../../init/…` — one level too high, resolving
# to nothing — sat in github/SKILL.md undetected, and was then copied into three
# more skills. CLAUDE_SKILL_DIR is the skill's own directory, so the path is
# resolved from there.
while read -r hit; do
    [[ -z "${hit}" ]] && continue
    src="${hit%%:*}"; ref="${hit#*:}"
    target="$(dirname "${src}")/${ref#\$\{CLAUDE_SKILL_DIR\}/}"
    if [[ ! -f "${target}" ]]; then
        note "${src#"${SCRIPT_DIR}/../"} names ${ref}, which does not resolve (tried ${target#"${SCRIPT_DIR}/../"})"
    fi
done < <(grep -rHo '\${CLAUDE_SKILL_DIR}/[A-Za-z0-9_./-]*\.\(sh\|py\)' \
             "${SCRIPT_DIR}/../skills"/*/SKILL.md 2>/dev/null | sort -u)

# Cross-skill reference cites: `claude-arsenal:<plugin>:<skill> § references/<f>.md`.
# The skill validator exempts this form from its dangling-reference check —
# that exemption is the whole reason the form exists — so nothing verified that
# the cited file was real. Three skills shipped a cite naming a directory the
# init skill does not have (its references live under `assets/`), pointing at
# the BLOCK-override rules and the no-bundle procedure. A pointer that resolves
# to nothing is a step of the protocol that silently is not there, which is the
# failure this whole file was written for.
while read -r hit; do
    [[ -z "${hit}" ]] && continue
    src="${hit%%:*}"; cite="${hit#*:}"
    skill="$(sed -E 's/^[^:]*:[^:]*:([A-Za-z0-9_-]+).*/\1/' <<<"${cite}")"
    relref="$(sed -E 's/.*§[[:space:]]*(references\/[A-Za-z0-9_.\/-]+\.md).*/\1/' <<<"${cite}")"
    base="${SCRIPT_DIR}/../skills/${skill}"
    if [[ ! -f "${base}/${relref}" && ! -f "${base}/assets/${relref}" ]]; then
        note "${src#"${SCRIPT_DIR}/../"} cites ${cite}, which resolves to no file under skills/${skill}/"
    fi
done < <(grep -rHo '`claude-arsenal:[a-z-]*:[A-Za-z0-9_-]*[[:space:]]*§[[:space:]]*references/[A-Za-z0-9_./-]*\.md`' \
             "${SCRIPT_DIR}/../skills"/*/SKILL.md 2>/dev/null | sort -u)

# AGENTS.md rides in every consumer's context window on every turn. 250 lines is
# the budget: enough for the session-start protocol, the task format, the claim
# contract and completion, and not enough for anything that belongs behind a
# reference.
AGENTS_MAX_LINES=250
agents_md="${ASSETS}/AGENTS.md"
if [[ -f "${agents_md}" ]]; then
    n=$(wc -l < "${agents_md}")
    if (( n > AGENTS_MAX_LINES )); then
        note "AGENTS.md is ${n} lines (budget ${AGENTS_MAX_LINES}). It is imported into \
every consumer's CLAUDE.md, so every line is paid on every turn of every session — \
move whatever grew into claude-arsenal/references/ and point at it."
    fi
else
    note "AGENTS.md missing from the bundle"
fi

# Every reference the bundle ships should be reachable from AGENTS.md; an
# orphan is a file no session will ever be told to open.
if [[ -d "${ASSETS}/references" ]]; then
    for ref in "${ASSETS}"/references/*.md; do
        [[ -e "${ref}" ]] || continue
        base="$(basename "${ref}")"
        grep -qF "references/${base}" "${agents_md}" \
            || note "references/${base} is not pointed at from AGENTS.md (nothing will open it)"
    done
fi

# The inverse direction is not an error — a bundle script may exist without any
# prose naming it — but a *deleted* script leaving a live caller is, and that is
# what the loop above catches.

if [[ ${fail} -eq 0 ]]; then
    echo "PASS: bundle_refs_test — every referenced bundle file exists, AGENTS.md within budget"
fi
exit "${fail}"
