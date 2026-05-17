# Migration baseline — pre-S0 snapshot

Captured **2026-05-17** on branch `feat/claude-arsenal-migration`, commit prior
to S0. Frozen state of `my-skills` before the marketplace migration begins.

This file is a working artifact: it is **deleted at S6** once the merge of
`github/` and `session-end/` lands inside `plugins/core/skills/`. Treat it as
a checklist, not a permanent record.

---

## 1. Flanks-isms in the source-of-port clone

Source: `tmp/external-skills/` (read-only reference clone, gitignored).
Every item below is dropped or rewritten during S2–S6 per the plan's
"Explicitly dropped" section.

### 1.1 Top-level directories to drop entirely

| Path | Disposition |
|---|---|
| `tmp/external-skills/plugins/flanks-frontends/` | Drop. Not ported. |
| `tmp/external-skills/plugins/flanks-aworkers/` | Drop. Not ported. |
| `tmp/external-skills/plugins/flanks-core/` | **Partial port** at S5 — only the generic workflow skills (`discovery`, `design`, `execution`, `review`, `release-readiness`, `engineering-core`, `session-summary`, `github`) are kept; the per-tool skills (`tramoia`, `honeycomb`, `sentry`, `gcloud`, `jira`, `har`, `docs`, `flenkins`) are surfaced one-by-one and default-dropped. |
| `tmp/external-skills/.claude/aworkers-templates/` | Drop. Not ported. |
| `tmp/external-skills/.claude/aworkers-scripts/` | Drop. Not ported. |

### 1.2 Token frequency across markdown / python / shell / json

Generated with `grep -rlE "<tok>" tmp/external-skills --include="*.md|*.py|*.sh|*.json"`:

| Token | File count | Disposition |
|---|---:|---|
| `flanks` | 114 | Strip everywhere. Replace `flanks-core` slug with `claude-arsenal:core`. |
| `aworkers` | 88 | Strip. `aworkers-` filename prefix convention deleted. Repo-anchor logic in `validate.py::_check_script_paths` removed. |
| `PD-` | 71 | Strip. `PD-XXXXX` branch-naming policy replaced with a generic equivalent example in rule rows. |
| `tramoia` | 55 | Strip. Skill default-dropped at S5; vocabulary purged from `frontmatter-and-naming.md` and `scripts-and-cli-conventions.md`. |
| `flenkins` | 35 | Strip. Skill default-dropped at S5. |
| `FlanksAPI` | 27 | Strip. Service-reference doctrine (`docs/services/<svc>.md`) dropped. |
| `jira` | 25 | Strip. Skill default-dropped at S5. |
| `honeycomb` | 19 | Strip. Skill default-dropped at S5. |
| `sentry` | 18 | Strip. Skill default-dropped at S5. |
| `gcloud` | 18 | Strip. Skill default-dropped at S5. |

Additional brand tokens to scrub (from grep): `Estoig` (243 hits), `Nuxt`
(84 hits), `SearchEngine` (48 hits), `wealth-frontend` (9), `pmt-frontend`
(8), `agents-frontend` (9), `jobs-admin` (7). All sit inside frontends
plugins that are wholly dropped.

### 1.3 Files with Flanks branding in the path

| Path | Disposition |
|---|---|
| `tmp/external-skills/.claude/agents/flanks-memory.md` | Rename to `agents/memory.md`, port-and-strip at S4. |

### 1.4 Policy items to drop or generalise

- Second-approver-on-master branch policy → replace with generic equivalent in `plugins/core/skills/release-readiness/`.
- Bank-driver vocabulary (`_get_products_data`, etc.) → drop, no replacement.
- `tramoia.flanks.ts.net` hostname examples → replace with neutral example.
- `PD-12726` PR reference → replace with a synthetic illustrative number.

---

## 2. Rule-coverage gap audit

Inputs:
- **Ours**: `skills/skill-validator/references/rule-catalog.md` (1188 lines, derived from the v1.17 research doc).
- **Theirs**: `tmp/external-skills/.claude/skills/skill-creator/references/skill-rules.md` + `content-quality-rules.md` (the active rubric we are porting).

### 2.1 Headline counts

| Bucket | Count |
|---:|---|
| `R-*` rule IDs in our catalog | **189** |
| `R-*` rule IDs in their rubric | **58** |
| `R-*` shared (intersection) | **58** |
| `R-*` only-in-ours (gap to close) | **131** |
| `R-*` only-in-theirs | **0** |
| `Q-*` rule IDs in our catalog | 0 |
| `Q-*` rule IDs in their rubric | 23 |

**Net gap to close at S2: 131 `R-*` IDs** missing from the rubric we are
porting. The plan estimates ~40 of these are author-checkable (land in
`skill-rules.md`) and ~91 are meta-only governance (land one-line-each in
`research-coverage.md` with `§` anchors back to the research doc).

> Note: the original handoff prompt cited "185 / 55 / gap = 130" rounded
> figures. The exact figures above were re-measured at S0 with `grep -ohE`
> + `LC_ALL=C sort -u`. The order-of-magnitude is unchanged — this is the
> precise input the rubric extension at S2 must consume.

### 2.2 Author-checkable rule families to port at S2

Per the plan's Stage 2 table (Section "Rule additions to `skill-rules.md`"),
the portable subset spans:

| Section in rubric | New rule families |
|---|---|
| 3. Body length and style | `R-BODY-4`, `R-BODY-6`, `R-BODY-7` |
| 4. References | `R-CHUNK-1..5`, `R-LAZYLOAD-1` |
| 5. Skill-vs-reference boundary | `R-CONDUCT-1..4`, `R-CTX-2` |
| 6. Workspace topology | `R-MONO-1..2`, `R-WORKSPACE-2/6`, `R-IDX-1` |
| 7. Scripts and CLI | `R-SR-6..7`, `R-REFLOC-2..4`, `R-HELP-1` |
| 8. Cross-skill hygiene | `R-XPOLL-1..3`, `R-XPOLL-6..10` |
| 9. Multi-task composition | `R-DEL-2`, `R-PAR-2/4`, `R-FAIL-3..5` |
| 11. Inter-document boundary | `R-MEM-7..9` |
| 14. Hardening (new) | `R-CONTAM-1` |

### 2.3 Meta-only families (deferred to `research-coverage.md`)

`R-META-*`, `R-LLMJ-*`, `R-CADENCE-*`, `R-AUTODREAM-*`, `R-LOAD-*`,
`R-DRIFT-*`, `R-RETRO-*`, `R-ROLLBACK-*`, `R-SELF-*`, `R-DESTRUCT-*`,
`R-EXTRACT-*`, `R-VC-*`, `R-SYS-*`, `R-CHUNK-6`, `R-LAZYLOAD-2..3`,
`R-MEM-1/10`. Each lands as one line with a `§` anchor citing
`docs/research/claude-skill-system_v1.17.md`.

### 2.4 Q-rule import

All 23 `Q-*` content-quality rules from `tmp/external-skills/.claude/skills/skill-creator/references/content-quality-rules.md`
are absent from our catalog — they ship through the port verbatim (the file
is **PORT-AND-STRIP**, only Flanks-flavoured examples touched).

---

## 3. Listing-budget snapshot (today's repo)

Listing-budget cap is **8000 chars** (per the plan). Today the repo
contains three SKILL.md files at the wrong nesting depth. Frontmatter
contributions (name + description, the listing-relevant fields):

| Skill | SKILL.md bytes | Listing-budget contribution (est.) | Notes |
|---|---:|---:|---|
| `skills/skill-validator/SKILL.md` | 687 | **~273 chars** | Placeholder. Deleted at S2; rule-catalog content moves to research doc + rubric. |
| `github/SKILL.md` | 1267 | **~76 chars** | At wrong nesting depth (repo root, not under a plugin). Merged into `plugins/core/skills/github/` at S6. |
| `session-end/SKILL.md` | 1240 | **~69 chars** | At wrong nesting depth. Merge candidate with external `session-summary/` at S6. |
| **Total today** |  | **~418 chars** | 5.2 % of cap, 94.8 % headroom. |

> Listing budget is conventionally measured as `name + description` since
> those are the fields that load when Claude walks the skill index. Exact
> figures will be re-measured by `audit_library.py --by-plugin` after
> S2 — this is a pre-port baseline only.

---

## 4. Source-of-truth chain (post-S2 target)

| Layer | File | Role |
|---|---|---|
| Source archive | `docs/research/claude-skill-system_v1.17.md` (842 KB, moved verbatim from `tmp/claude-skill-system_v1.17.md` at S2) | The full research doc; every rubric ID cites back to a `§` anchor here. |
| Active rubric | `plugins/skill-creator/skills/skill-creator/references/skill-rules.md` | The 58 inherited rows plus the ~40 author-checkable rows added from our gap. |
| Active rubric (content) | `plugins/skill-creator/skills/skill-creator/references/content-quality-rules.md` | The 23 `Q-*` rows from external, Flanks-flavour stripped. |
| Deferred catalog | `plugins/skill-creator/skills/skill-creator/references/research-coverage.md` | One-liner per meta-only ID (~91 rows) with `§` anchor. |

**Dropped at S2**: `skills/skill-validator/references/rule-catalog.md` (1188 lines, redundant intermediate). `docs/rules-extracted.md` (631 lines, same fate).

---

## 5. Outstanding observation — reference count

The plan's Stage 2 table lists **12** reference files to port. Today
`tmp/external-skills/.claude/skills/skill-creator/references/` contains
**10**:

```
body-and-style.md
content-quality-rules.md
frontmatter-and-naming.md
improvements-log.md
inter-document-boundary.md
refactor-cookbook.md
references-and-chunking.md
research-coverage.md
scripts-and-cli-conventions.md
skill-rules.md
```

Missing from the disk vs the plan table: `validation-and-evals.md` and
`workspace-and-composition.md`. Either the plan's count is stale or those
two files live elsewhere in the external clone. **Resolve at the start of
S2** by `find tmp/external-skills -name 'validation-and-evals.md' -o -name 'workspace-and-composition.md'`
before opening the port checklist.

---

## 6. Verification commands for this snapshot

Re-run any of these to confirm the baseline:

```bash
# Flanks-isms file counts
for tok in flanks aworkers tramoia honeycomb sentry gcloud jira flenkins FlanksAPI 'PD-'; do
  count=$(grep -rlE "$tok" tmp/external-skills --include="*.md" --include="*.py" --include="*.sh" --include="*.json" 2>/dev/null | wc -l)
  echo "  $tok: $count files"
done

# Rule gap recount
grep -ohE "R-[A-Z]+(-[A-Z]+)?-[0-9]+" skills/skill-validator/references/rule-catalog.md | LC_ALL=C sort -u > /tmp/ours-R.txt
grep -ohE "R-[A-Z]+(-[A-Z]+)?-[0-9]+" tmp/external-skills/.claude/skills/skill-creator/references/skill-rules.md tmp/external-skills/.claude/skills/skill-creator/references/content-quality-rules.md | LC_ALL=C sort -u > /tmp/theirs-R.txt
LC_ALL=C comm -23 /tmp/ours-R.txt /tmp/theirs-R.txt | wc -l   # expect 131

# SKILL.md byte counts
wc -c skills/skill-validator/SKILL.md github/SKILL.md session-end/SKILL.md
```
