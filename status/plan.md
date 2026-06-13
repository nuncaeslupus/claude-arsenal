# Plan: Loop Orchestrator Plugin

**Date**: 2026-06-12
**Specification**: `status/specification.md`
**Author**: imarcos@gmail.com

---

## Technical solution

### Architecture overview

A new `plugins/loop-orchestrator/` plugin is added to claude-arsenal. It ships:

1. **Plugin manifest** — `plugin.json` + marketplace entry.
2. **SessionStart hook** — wires `detect_surface.sh` into every host session.
3. **User-facing skills** — `/loop-init`, `/loop-start`, `/loop-add`, `/loop-status`, `/loop-upgrade` — thin wrappers that guide the user and delegate to shell scripts.
4. **Bundled `.loop/core/` tree** — the portable framework files copied into the host repo on `/loop-init`. The upgrade mechanism overwrites only `core/`, never `state/`.

On the host repo side, after `/loop-init`:

```
.loop/
  core/      ← plugin-owned; overwritten by /loop-upgrade
  state/     ← host-owned; never touched by upgrade
CLAUDE.md    ← host adds: @.loop/core/AGENTS.md
```

Workers are **in-session Task-tool subagents** (R-WORKER-1). Isolation is **`isolation: worktree`** on CLI and per-session VM on Web (R-WORKER-2). Quota is governed by the **statusLine `rate_limits`** payload (R-WORKER-3, subscription pool only). The reviewer is a **cloud Routine** on GitHub PR events (R-REVIEW-1).

### Data flow

```
SessionStart
  └─> detect_surface.sh → .loop/state/surface_profile.json

User: /loop-start
  └─> orchestrator session
        ├─> queue_eval.sh (read queue.jsonl, emit next unblocked task)
        ├─> statusLine rate_limits check (throttle if > 90%)
        └─> Task tool → worker subagent (isolation: worktree)
              ├─> reads task payload (tasks/<id>.md)
              ├─> does implementation work
              └─> release.sh → commit + push queue.jsonl status=done

PR opened
  └─> Cloud Routine → /code-review --comment (reads REVIEW.md rubric)
```

### State changes

| Component | Location | Change | Description |
|-----------|----------|--------|-------------|
| Plugin | `plugins/loop-orchestrator/` | CREATE | Manifest, hooks, skills, scripts |
| Marketplace | `.claude-plugin/marketplace.json` | UPDATE | Add `loop-orchestrator` entry |
| Framework tree | `.loop/core/` (in host repo) | CREATE on init | AGENTS.md, agent defs, scripts, REVIEW.md |
| Queue state | `.loop/state/` (in host repo) | CREATE on init | `queue.jsonl` (empty), `tasks/`, `handover.md` placeholder |

### Technology choices

| Choice | Justification |
|--------|--------------|
| JSONL state file (not SQLite, not Dolt) | R-SUBSTRATE-1: readable with nothing beyond text editor + git; works in Web VM |
| Hash-based task IDs | R-SUBSTRATE-2: prevents cross-branch collision at concurrent-worker scale |
| Git-push optimistic concurrency | R-SUBSTRATE-3 VALIDATED at ≤ 2-worker scale; no lock daemon required |
| Task-tool subagents (not `claude -p`) | R-WORKER-1 VALIDATED: CLI+Web parity; metered pool avoided |
| `isolation: worktree` + prompt-injected relative-path directive | R-SCOPING-1 VALIDATED: worktree alone leaks absolute paths (Issue #56137) |
| Cloud Routine for reviewer | R-REVIEW-1: durable, subscription pool, CLI+Web parity |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` + `CLAUDE_CODE_DISABLE_FAST_MODE=1` | R-CREDITS-3: blocks both credit gates before any worker launches |
| `CLAUDE_CODE_REMOTE` as surface discriminator | R-ROUTING-2 VALIDATED: best-available Tier-2 evidence |

### Out of scope

- Agent Teams / `/workflows` (opt-in accelerator, not the default — DA-Q002-3)
- `claude -p` headless paths (metered post-2026-06-15 — DA-Q002-4, R-BILLING-3)
- `anthropics/claude-code-action` as default reviewer (metered, OAuth unreliable in CI — DA-Q003-3)
- GitHub Issues / Dolt / Backlog.md as queue substrate (DA-Q001-1, DA-Q001-2)
- Threshold expressions in `requires` array (DA-Q006-2)
- Per-surface queue partitioning (DA-Q006-1)
- `open-spdd` CLI as infrastructure dependency (DA-Q005-2)

---

## Implementation tasks

| T# | Description | Location | Size | Depends | Gate | Tests |
|----|-------------|----------|------|---------|------|-------|
| T1 | Scaffold plugin: `plugin.json`, `hooks/hooks.json`, empty skills index, marketplace entry | `plugins/loop-orchestrator/`, `.claude-plugin/marketplace.json` | S | — | `make audit` exits 0 and listing-budget headroom ≥ 50% | `make audit` output; verify entry appears in marketplace |
| T2 | Write `detect_surface.sh` + SessionStart hook wiring | `plugins/loop-orchestrator/hooks/`, `.loop/core/scripts/` | M | T1 | Script exits 0 on both CLI (CLAUDE_CODE_REMOTE unset) and simulated Web (CLAUDE_CODE_REMOTE=true); `surface_profile.json` contains `surface:cli` or `surface:web` and correct capability tags | Run script locally with and without CLAUDE_CODE_REMOTE; diff output |
| T3 | Write `claim.sh`, `release.sh`, `queue_eval.sh` shell scripts | `.loop/core/scripts/` | M | T1 | Two-process contention test: exactly one process wins the claim push; `lost` path re-picks cleanly | `tests/claim_contention.sh` — two parallel git-push racers on a temp repo |
| T4 | Write `AGENTS.md` + worker/reviewer agent definition files | `.loop/core/`, `.loop/core/agents/` | M | T2, T3 | Worker agent loads in a test session (`claude --list-agents` shows it); AGENTS.md import resolves from host root CLAUDE.md at depth ≤ 4 | Manual session test; `grep -r` for import chain depth |
| T5 | Write `REVIEW.md` rubric (4 pillars: security, performance, test coverage, docs) | `.loop/core/` | S | T4 | File present, four pillar sections exist, passes a Routine dry-run | File structure lint |
| T6 | Write `/loop-init` skill: copies `.loop/core/` into host repo, creates empty `state/`, adds CLAUDE.md import line | `plugins/loop-orchestrator/skills/loop-init/` | M | T4, T5 | After running skill, host repo has `.loop/core/AGENTS.md`, `.loop/state/queue.jsonl` (empty), and exactly one new line in `CLAUDE.md` | Manual test in a scratch repo |
| T7 | Write `/loop-start` skill: checks capabilities, reads quota, spawns worker subagent loop | `plugins/loop-orchestrator/skills/loop-start/` | L | T3, T4 | Worker picks first unblocked task, executes it in a worktree, closes with `status=done` in queue.jsonl | End-to-end test: seed one task in queue, run loop, verify done status |
| T8 | Write `/loop-add` and `/loop-status` skills | `plugins/loop-orchestrator/skills/` | S | T3 | `/loop-add` appends a valid JSONL row; `/loop-status` prints open/done/blocked counts | Inspect queue.jsonl after `/loop-add`; count matches |
| T9 | Write `/loop-upgrade` skill + upgrade script with semver gate | `plugins/loop-orchestrator/skills/loop-upgrade/`, `.loop/core/scripts/upgrade.sh` | M | T1 | Round-trip test: plant sentinel file in `state/`, run upgrade, verify `core/` refreshed and sentinel intact | `tests/upgrade_roundtrip.sh` |
| T10 | Write `handover.md` template + cold-start directive in AGENTS.md | `.loop/core/` | S | T4 | A session started from `handover.md` alone can resume the last known task without additional context | Manual session test |
| T11 | Validate spec and plan | `status/` | S | T1 | `validate_spec.py` exits 0; `validate_plan.py` exits 0 | Run scripts |
| T12 | Register env-hardening in AGENTS.md launch block: `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`, `CLAUDE_CODE_DISABLE_FAST_MODE=1`, `CLAUDE_CODE_SUBAGENT_MODEL` pin, v2.1.172+ version check | `.loop/core/AGENTS.md` | S | T4 | Code audit: all three env vars + model pin present in worker launch stanza | `grep` audit + integration env dump test |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1 → T2/T3 (parallel) → T4/T5 (parallel) → T6/T7/T8/T9/T10 (parallel) → T11/T12
**Branch pattern**: `loop-orch-T<N>-<slug>` from default branch

## Evidence log

`execution` appends one row per task as it lands.

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | make audit exits 0 | PASS — 7948/8000 chars (52 remaining, 0% headroom); 0 FAILs across 20 skills | `make audit && make validate` | (see commit) | linux/uv | 2026-06-13 |
| T1 | listing-budget headroom ≥ 50% | DEVIATION — budget is 0% headroom. Core grew to 14 skills (7155 chars) before T1; impossible to meet 50% target without trimming existing descriptions. make audit exits 0 (under hard cap). | n/a | n/a | n/a | 2026-06-13 |
| T2 | detect_surface.sh exits 0 on CLI and Web; surface_profile.json correct | PASS — CLI: surface=cli caps=["surface:cli"]; Web (CLAUDE_CODE_REMOTE=true): surface=web caps=["surface:web"]; no-op when .loop/state absent | bash detect_surface.sh (with/without CLAUDE_CODE_REMOTE=true) | (see commit) | linux | 2026-06-13 |
| T3 | Two-process contention: exactly one won, one lost | PASS — tests/claim_contention.sh: session-b won, session-a lost | bash tests/claim_contention.sh | (see commit) | linux | 2026-06-13 |

### Dependency graph

```
T1 ──┬─> T2 ──┐
     │         └─> T4 ──┬─> T5 ──> T6 (T4,T5→T6)
     ├─> T3 ─────────> T4 ├─> T7 (T3,T4→T7)
     │    ├─> T7           ├─> T10
     │    └─> T8           └─> T12
     ├─> T9
     └─> T11
```

---

## Sign-off

- [ ] Design reviewed by second engineer
- [ ] Contracts agreed: `queue.jsonl` schema frozen before T3
- [ ] `make audit` run with stub manifest to confirm listing-budget headroom (before T1 merges)
- [ ] Ready for execution
