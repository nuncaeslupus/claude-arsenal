# Auto-fire setup — Stop hook + skip override

By default, session-end is a manual / on-request skill. To make it fire automatically at conversation close, install a Stop hook. To suppress it for the next conversation only, drop a sentinel file.

## Stop hook installation

Use the update-config skill to add a Stop hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "test -f \"${CLAUDE_PROJECT_DIR}/tmp/.skip-next-session-end\" && rm -f \"${CLAUDE_PROJECT_DIR}/tmp/.skip-next-session-end\" || /usr/bin/env claude --print '/session-end'"
          }
        ]
      }
    ]
  }
}
```

What this does:

1. Check for the skip sentinel `${CLAUDE_PROJECT_DIR}/tmp/.skip-next-session-end`.
2. If present: delete it and exit 0 — session-end is skipped this once.
3. Otherwise: launch a non-interactive Claude session that invokes `/session-end` against the same project directory.

The non-interactive invocation runs the skill in a fresh sub-session; it does not pollute the just-ended conversation. The retrospective + handoff write happen in the sub-session and commit (if handoff mode is on) before exiting.

## Skip override — `tmp/.skip-next-session-end`

Drop this file to suppress the next auto-fire:

```bash
touch tmp/.skip-next-session-end
```

The sentinel is one-shot: it's deleted on the first hook invocation, whether or not session-end ran. Useful when:

- You're closing the terminal mid-investigation, not at a clean stopping point.
- You already ran `/session-end` manually and don't want it to fire again on Stop.
- The session was an experiment you don't want to retrospectively scan.

The skip file lives under `tmp/` (gitignored). It is NOT honored when session-end is invoked manually — only when the Stop hook would have fired it.

## Sanity checks before enabling auto-fire

- Confirm `claude --print '/session-end'` works in your environment from outside an active session. Some shells lose env vars between the Stop event and the spawned subprocess.
- Confirm the github skill is also installed (or you have `handoff=no` / `handoff=ticket` set), otherwise session-end may try to write `status/handoff.md` in a repo that doesn't expect it.
- Confirm `${CLAUDE_PROJECT_DIR}` resolves correctly inside the hook — some hook versions only expose `${CLAUDE_TRANSCRIPT_PATH}` or similar; consult the harness's Stop-hook env-var contract.

## Disabling auto-fire

Remove the Stop hook entry from `~/.claude/settings.json` (via update-config or by hand). The skill itself is unaffected — manual `/session-end` keeps working.
