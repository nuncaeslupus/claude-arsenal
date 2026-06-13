---
name: session-end
description: Use whenever the user signals end-of-job, invokes /session-end, or a Stop hook fires at conversation close — produces an end-of-job artifact in two steps. Step 1 writes status/handoff.md from current session state if the host repo's CLAUDE.md opts in via the session-end marker; otherwise skips. Step 2 always runs the retrospective — scans recent session transcripts under ~/.claude/projects/ for repeated tool errors, throwaway scripts in tmp/, repeated user corrections, and unexpected tool behavior — then surfaces proposed skill updates. Triggers — "wrap up", "we're done", "/session-end", "save the session", "end-of-job retrospective". Do NOT use mid-job, for cross-session memory writes (use the auto-memory directory), or to summarize someone else's session.
metadata:
  type: workflow
---

# session-end

End-of-job ritual. Two steps, both run unconditionally when this skill is invoked:

1. **Handoff** (opt-in per-project): if the host repo's `CLAUDE.md` has the marker `<!-- session-end: handoff=yes -->`, write/update `status/handoff.md` from the current session state and stage it so it lands in the next PR.
2. **Retrospective** (always): scan the last N session transcripts for pain signals (repeated errors, throwaway scripts, repeated user corrections, unexpected tool behavior), then surface concrete skill-update proposals.

CANARY: session-end-loaded-2026-05-20-4896c0a5-8ca7505c91dc34e6

## When to load

- The user types `/session-end` or says "wrap up", "we're done", "close this session".
- A Stop hook fires at conversation close (opt-in setup — see [auto-fire-setup](references/auto-fire-setup.md)).
- The github skill is about to open a PR and the handoff marker is `yes` — this skill regenerates `status/handoff.md` before the PR commit.

Do not load mid-job. The retrospective wants a complete arc to scan.

## Step 1 — handoff (opt-in)

Read the host repo's `CLAUDE.md` and look for one of:

| Marker | Behavior |
|---|---|
| `<!-- session-end: handoff=yes -->` | Generate `status/handoff.md` from the session, commit it. |
| `<!-- session-end: handoff=ticket -->` | Skip handoff write (one session = one ticket; PR description suffices). |
| `<!-- session-end: handoff=no -->` | Skip handoff write (project doesn't use the handoff flow). |
| (no marker) | Ask the user once which mode this repo uses, then write the marker. |

Handoff content + template + ticket-mode alternative live in [handoff-mode](references/handoff-mode.md).

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/create_handoff.py" --output status/handoff.md
```

The script renders the template with placeholders; Claude fills in the session-specific content (DONE / TODO / repro / no-touch lists) from conversation context, then writes the file.

## Step 2 — retrospective (always)

Scan the last N session transcripts for pain signals:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/query_session_history.py" --days 7 --limit 10
```

The script extracts mechanical signals (repeated tool errors, throwaway scripts in `tmp/`, repeated user-correction phrases, repeated failing Bash commands) and emits a JSON report. Claude reads the report, judges which signals are real improvement opportunities (most error spikes are normal; what matters is *recurring* friction), and surfaces a short list to the user.

For each accepted proposal, Claude writes a YAML+MD block to the right location:

| Where Claude is running | Target file |
|---|---|
| Inside this marketplace repo (`plugins/<plugin>/skills/<skill>/` exists) | `plugins/<plugin>/skills/<skill>/IMPROVEMENTS.md` (appended; commit later) |
| Anywhere else (consumer install, cache is volatile) | `~/.claude/proposed-skill-improvements/<YYYY-MM-DD>.md` (appended; user reviews offline) |

Format and rubric for the proposal block live in [retrospective-rubric](references/retrospective-rubric.md).

## Auto-fire (opt-in)

Stop-hook setup (so this skill fires at conversation close without an explicit `/session-end`) and the skip override (`tmp/.skip-next-session-end` sentinel file) are documented in [auto-fire-setup](references/auto-fire-setup.md). Both are user-installed via the update-config skill; this skill does not modify settings.json on its own.

## References

- [handoff-mode](references/handoff-mode.md) — CLAUDE.md marker syntax, `status/handoff.md` template, ticket-mode alternative (load when Step 1 runs).
- [retrospective-rubric](references/retrospective-rubric.md) — pain-signal catalog, judgment rubric, IMPROVEMENTS.md block format (load when Step 2 surfaces proposals).
- [auto-fire-setup](references/auto-fire-setup.md) — Stop-hook config snippet + skip-override sentinel (load when wiring auto-fire).

## Workspace-aware paths

When `claude-arsenal/project/<WORKSPACE>/` exists, write the Step 1 handoff to `claude-arsenal/project/<WORKSPACE>/handover.md` and refresh the cross-workspace `claude-arsenal/session/handover.md` instead of `status/handoff.md`. Otherwise use `status/handoff.md` as above. The handoff opt-in marker still governs whether Step 1 runs at all.
