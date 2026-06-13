# Specification: Loop Orchestrator Plugin

**Date**: 2026-06-12
**Source**: `loop-orchestrator_v1.8.md` (research complete, queue empty)
**Author**: imarcos@gmail.com

---

## 1. Problem statement

The research document `loop-orchestrator_v1.8.md` (v1.8, research queue exhausted) delivers a
fully validated design for a portable, quota-aware loop orchestrator: a git-backed DAG task queue,
N subscription-pool worker loops, a durable reviewer loop, and per-session memory bootstrap —
adoptable by any repo via one CLAUDE.md line. The problem now is to implement it as a proper
deliverable *inside* claude-arsenal, choosing the right packaging vehicle so that (a) consumers
can install it without friction, (b) it works identically on Claude Code CLI and Web, (c) it never
silently draws the metered Agent SDK credit, and (d) its framework files can be upgraded upstream
without touching the host repo's live queue state.

**Success criteria (measurable)**:

- [ ] `plugin_manifest_valid == true` — `plugins/loop-orchestrator/.claude-plugin/plugin.json` validates against the marketplace schema and `make audit` passes
- [ ] `adoption_line_count == 1` — a consumer adopts the orchestrator by adding exactly one line to their `CLAUDE.md`: `@.loop/core/AGENTS.md`
- [ ] `cli_web_parity == true` — the full worker+reviewer loop runs without modification on both Claude Code CLI and Claude Code Web (no bash-outer-loop, no gitignored state, no `~/.claude` user files)
- [ ] `claim_atomic == true` — two simultaneous workers on the same queue race for a task and exactly one wins, verified by a scripted two-process git-push contention test
- [ ] `billing_clean == true` — no `claude -p`, Agent SDK, or `claude-code-action` path is exercised in the default loop; all workers stay on the subscription pool (verified by code audit + CLAUDE_CODE_DISABLE_* env vars set)
- [ ] `upgrade_safe == true` — running the upgrade command overwrites `.loop/core/` and leaves `.loop/state/queue.jsonl` and per-task payloads byte-for-byte unchanged (verified by a round-trip test)
- [ ] `credit_gates_hardened == true` — `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`, `CLAUDE_CODE_DISABLE_FAST_MODE=1`, and standard-context model pinning are applied at every dispatch layer (code audit)

## 2. Systems & Impact

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `plugins/loop-orchestrator/` | Primary (new) | Plugin home: manifest, hooks, skills, scripts | Create from scratch | None until first install | Low |
| `.loop/core/` (shipped into host repos) | Primary (new) | Upstream-owned framework: AGENTS.md, worker/reviewer agent defs, scripts, REVIEW.md | Create from scratch | Loaded by host CLAUDE.md import chain; must be git-committed | High |
| `.loop/state/` (host-owned in host repos) | Shared resource (new) | `queue.jsonl`, per-task payloads, `handover.md`, `surface_profile.json` | Create skeleton on install | Live queue state — must never be overwritten by upgrade | High |
| `.claude-plugin/marketplace.json` | Infrastructure | Marketplace manifest listing all plugins | Yes — add entry | Consumers see new plugin in listing | Low |
| Host repo `CLAUDE.md` | UI (consumer-side) | One-line `@.loop/core/AGENTS.md` import | Consumer adds one line | Loads AGENTS.md at every session launch, including post-compaction re-inject | Med |
| `plugins/core/skills/*/` | Dependent | Existing core skills (execution, review, etc.) | No | Orchestrator is additive; no existing skill is modified | Low |

**Impact dimensions**:
- **Data**: `queue.jsonl` is the source of truth; upgrade must be provably non-destructive to `state/`
- **API contracts**: none (no HTTP service; shell scripts + JSONL)
- **Performance**: lean orchestrator session (script-first, R-THRIFT-1); subagent contexts destroyed on completion
- **User-facing**: consumer sees one new CLAUDE.md line; no UX regression in existing skills
- **Operational**: `make audit` must still pass; listing-budget headroom must remain ≥ 50%
- **Risk of inaction**: without this plugin the research document remains paper design, and users must hand-roll the whole `.loop/` tree

## 3. Options

### Option A: Wrap the orchestrator as a single skill in `plugins/core/` (Conservative)

- **Description**: Add an `orchestrate` skill to the existing `core` plugin. The skill's SKILL.md guides the user to set up the `.loop/` convention manually; it provides a `/orchestrate start` command that drives the subagent loop from the current session.
- **Scope**: One new `plugins/core/skills/orchestrate/SKILL.md` + references. No new plugin, no hooks, no agents directory.
- **Effort**: Small
- **Tradeoffs**: Fast to ship. But skills are stateless workflow guides — they can't ship hooks, agent definitions, or a framework directory tree into the host repo. The consumer must manually copy `.loop/core/` from somewhere, install the hook, and wire the CLAUDE.md line. The upgrade story is "re-run the skill" with no version gate or safe-overwrite guarantee. Core plugin listing budget would grow.
- **Compatibility**: Backwards compatible; only adds a skill.

### Option B: New dedicated plugin `loop-orchestrator` (Recommended)

- **Description**: Create `plugins/loop-orchestrator/` with its own `plugin.json`, a `hooks/hooks.json` (SessionStart → `detect_surface.sh`), skills for user-facing commands (`/start-loop`, `/add-task`, `/queue-status`, `/upgrade-loop`), and a bundled `.loop/core/` tree that is installed into the host repo on first use. The `core/state` split follows R-PORTABLE-2 exactly; the upgrade command's semver gate follows the research-buddy pattern. The plugin registers in `marketplace.json`.
- **Scope**: New plugin directory, new marketplace entry, no changes to existing plugins.
- **Effort**: Large
- **Tradeoffs**: Full fidelity to the v1.8 design. Ships the complete `.loop/core/` framework, AGENTS.md, scripts, and upgrade machinery as first-class plugin artifacts. Upgrade story is clean (overwrite `core/`, skip `state/`). Listing-budget impact is isolated to the new plugin entry. Requires the most new code, but every piece maps 1:1 to a validated research rule (R-PORTABLE-1 through R-CREDITS-4).
- **Compatibility**: Purely additive; no existing plugin or skill is touched.

### Option C: Ship only the `.loop/` convention (no plugin wrapper)

- **Description**: Commit `.loop/core/` directly to the claude-arsenal repo as a reference implementation consumers `git subtree` or copy manually. No plugin manifest, no marketplace entry, no skill commands.
- **Scope**: New top-level `.loop/` directory in claude-arsenal (or a separate repo).
- **Effort**: Medium
- **Tradeoffs**: Removes the plugin layer entirely, but also removes discoverability, the `make audit` listing check, the SessionStart hook wiring, and the upgrade command. Consumers must read a doc and perform manual steps. No integration with the marketplace install flow. The research doc explicitly models the orchestrator as having a "one-line adoption" story that this option cannot fulfill without the plugin machinery.
- **Compatibility**: No conflicts, but leaves the adoption story incomplete.

### Comparison

| | Option A (skill in core) | Option B (new plugin) | Option C (bare convention) |
|---|---|---|---|
| Effort | Small | Large | Medium |
| Adoption friction | High (manual setup) | Low (plugin install + 1 CLAUDE.md line) | High (manual copy) |
| Upgrade story | None / manual | Clean semver-gated overwrite of `core/` | None |
| CLI+Web parity | Partial (skill only; no hook) | Full (hooks + AGENTS.md in git) | Partial (no hook wiring) |
| Listing-budget impact | Grows `core` entry | Isolated new entry | None |
| Fidelity to v1.8 design | Low (skill ≠ system) | High (1:1 mapping) | Medium (convention without tooling) |
| Maintenance | Low (one SKILL.md) | High (plugin + scripts + upgrade logic) | Low |

## 4. Recommendation

**Recommended option**: Option B — new dedicated plugin `loop-orchestrator`.

The v1.8 research document is not a workflow guide but a *system* specification: it ships hooks, agent definitions, shell scripts, a state directory convention, and an upgrade mechanism. Skills are workflow guides for a single Claude session; they cannot ship hooks or framework directories into a host repo. Option B is the only vehicle that maps all twelve validated rules (R-SUBSTRATE-1 through R-CREDITS-4) to runnable artifacts.

**Immediate next action**: scaffold `plugins/loop-orchestrator/` with `plugin.json`, `hooks/hooks.json`, and the skills index — then run `make audit` to verify listing budget before implementing the `.loop/core/` tree.

**Open questions**:
- [ ] Does the claude-arsenal install flow support "run script on plugin install" to copy `.loop/core/` into the host repo, or must the consumer do it manually via a skill command (`/start-loop init`)?
- [ ] Should `plugins/loop-orchestrator/` bundle a canonical `.loop/core/` tree (so upgrades pull from upstream), or should it generate `core/` on demand from templates embedded in the skill references?
- [ ] Listing-budget impact: how many characters does the new plugin entry consume? Run `make audit` with a stub entry first.
- [ ] Monorepo case: does the master-spec + per-subproject layout (R-SPEC-1) need a separate `monorepo-loop` skill, or does the core AGENTS.md handle it via task-payload conventions alone?

---

> Sections 5–6 (contracts, risks) appended by `design`.

## 5. Contracts

### Plugin manifest contract

The `plugin.json` must conform to the existing marketplace schema (see `.claude-plugin/marketplace.json` for peer examples). Required fields: `name`, `version` (semver), `description`, `skills[]`, `hooks` pointer.

### File-system contracts between `core/` and `state/`

```
.loop/
  core/           ← upstream-owned; upgrade overwrites this entire tree
    AGENTS.md     ← imported by host CLAUDE.md; re-read after /compact via R-COMPACT-1 directive
    agents/       ← worker + reviewer agent definitions (Task-tool subagents)
    scripts/
      detect_surface.sh   ← SessionStart hook; writes .loop/state/surface_profile.json
      claim.sh            ← claim(task_id) → won|lost via git-push optimistic concurrency
      release.sh          ← release(task_id, status)
      queue_eval.sh       ← emit next unblocked task for this worker's capabilities
    REVIEW.md     ← reviewer rubric (security, performance, test coverage, docs completeness)
  state/          ← host-owned; upgrade NEVER touches this tree
    queue.jsonl   ← one JSON object per line; hash IDs, DAG edges, priority, status, requires[]
    tasks/        ← per-task Markdown payload files (REASONS Canvas per R-PAYLOAD-1)
    handover.md   ← volatile session state (R-MEMORY-1); one writer per session
    surface_profile.json  ← written by detect_surface.sh on every SessionStart
```

### `queue.jsonl` row schema

```json
{
  "id": "lo-a3f8",
  "title": "...",
  "status": "open|in_progress|done|blocked",
  "priority": 0,
  "requires": ["surface:cli", "services:postgres"],
  "deps": [{"id": "lo-b2c1", "type": "blocks"}],
  "assignee": null,
  "payload": "tasks/lo-a3f8.md"
}
```

Atomic claim: commit `status → in_progress, assignee → session_id` + push. Push rejected → lost, re-pick.

### Upgrade contract

```
loop-upgrade [--apply] [--dry-run]
  1. Read .loop/core/VERSION → current_version
  2. Fetch upstream plugin version → upstream_version
  3. MAJOR mismatch → hard stop with message
  4. Minor behind → prompt user
  5. PATCH/newer → silent
  6. --dry-run: diff core/ only, no writes
  7. --apply: rsync upstream core/ → .loop/core/ ; never touch state/
```

### Inter-component contracts

| Caller | Callee | Protocol | Contract | Failure handling |
|--------|--------|----------|----------|-----------------|
| Orchestrator session | `claim.sh` | Shell | Returns `won\|lost` + task JSON on stdout | `lost` → re-pick next unblocked task |
| `claim.sh` | `git push` | git | Push to shared queue branch; non-zero exit = lost | Pull, rebase, re-pick |
| SessionStart hook | `detect_surface.sh` | Shell | Writes `surface_profile.json`; exit 0 always | Degraded capabilities → conservative profile |
| Worker subagent | `release.sh` | Shell | Updates `queue.jsonl` row; commits + pushes | On push failure: retry with exponential backoff × 3 |
| Cloud Routine | GitHub PR event | GitHub webhook | Triggers `/code-review --comment` on PR opened/synchronize | Routine retries on transient failure; Max 15/day cap |

### Database / state migrations

None (no relational DB). `queue.jsonl` schema evolves via append-compatible JSON — new optional fields are ignored by older readers.

## 6. Risks & Validation

| Risk | Likelihood | Impact | Mitigation | Validation |
|------|-----------|--------|------------|------------|
| Claude Code Web `git push` proxy rejects push to shared queue branch if session not started on it | Med | High | R-CLAIM-1: start Web session on queue branch; document in AGENTS.md | Manual test: open Web session on queue branch, run claim, verify push succeeds |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` or `CLAUDE_CODE_DISABLE_FAST_MODE` not propagated to subagents | Med | High | Set at orchestrator env level + `CLAUDE_CODE_SUBAGENT_MODEL` pin per R-CREDITS-3 | Code audit; add integration test that reads worker env dump |
| Upgrade script `rsync` overwrites a user file mistakenly placed in `core/` | Low | High | Validate: no file under `core/` is owned by the host; README warns; upgrade shows diff first | Round-trip test: plant dummy file in `core/`, run upgrade, verify it is replaced; `state/` unchanged |
| SessionStart `detect_surface.sh` times out on Web (5-min hard cap) | Low | Med | Keep script fast (< 30s); service probes are async fire-and-forget; defer heavy init | Time the script on a cold Web VM via setup-script instrumentation |
| Listing-budget cap exceeded after adding new plugin | Low | Med | Stub entry first; run `make audit`; trim description if needed | `make audit` in CI |
| `queue.jsonl` merge conflict when two workers claim simultaneously and both push | Low | Med | Optimistic concurrency: exactly one push wins at scale ≤ 2 workers (R-SUBSTRATE-3 VALIDATED) | Two-process contention test script |
| Post-compaction import loss (AGENTS.md import not re-expanded after `/compact`) | Low | Med | R-COMPACT-1 self-rehydration directive in root CLAUDE.md (PROPOSED SHOULD) | Long-session test: trigger compaction, verify loop continues without manual re-load |
