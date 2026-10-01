# Model upgrade

The repeatable process for aligning the marketplace's prompts with a new model
generation. `skill-workshop` owns it, because it holds the rules and the
validator that every skill passes through. Run it when a new generation's
prompting guides are published, or when the maintainer asks.

The process changes prompt text, rules and checks only. It never adds a runtime
model check or an "unsupported model" message: a consumer on any model gets the
same bundle, and `docs/MODELS.md` records which generation the prompts were
last aligned with for maintainers.

## Contents

- [Steps](#steps)
- [Audit findings format](#audit-findings-format)
- [Worked example](#worked-example)

## Steps

1. **Fetch the current guides.** Open the prompt-engineering index at
   `https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/`
   and take every model-specific page for the new generation
   (`.../prompting-claude-<model>-<version>`) plus the general best-practices
   page (`.../claude-prompting-best-practices`). Also read the Claude Code docs
   at `https://code.claude.com/docs/en/` for skills, sub-agents and hooks. Take
   the URLs from the index rather than from the previous run or memory, since
   pages are renamed between generations. If a page cannot be fetched, record
   which one and continue with the rest.
2. **Diff against the rules.** Compare each guide's recommendations with
   `references/model-prompting.md`. Write the changed and new G-rules
   into that file, update its Sources list, and note each rule that no longer
   holds so its check can go.
3. **Update the checks.** For each rule with a mechanical signal, add or edit
   its row in the `ContentRule` table in `validate.py`, add the rubric row to
   `references/skill-rules.md`, and record the finding and its source in `docs/research/addendum-YYYY-MM.md`. The v1.17 archive stays
   frozen. `make audit-rule-drift` confirms every new rule ID is documented.
4. **Audit the tree in three parallel parts**, each a subagent with the new
   rules and the findings format below:
   - resident tier: the vendored `AGENTS.md` and every skill description;
   - agent definitions and `SKILL.md` bodies with their references;
   - `skill-workshop` itself and the consumer docs.
   Run `make context-budget` first and give each part its baseline numbers.
5. **Write the spec and plan.** Turn the merged findings into a spec through
   `claude-arsenal:core:specify` and a plan through `claude-arsenal:core:design`,
   each with its annotatable reader, so the maintainer can annotate both before
   work starts.
6. **Execute and release.** Work the plan's tasks; validate every changed skill
   with `validate.py`; compare `make context-budget` with the baseline from
   step 4 and record both in the plan. Release through the normal version bump
   and CHANGELOG entry.
7. **Log the run.** Append a row to `docs/MODELS.md`: generation, date aligned,
   arsenal version, guides used, spec path.

## Audit findings format

Every audit part returns one table, so the three can be merged and sorted
without rewriting:

| # | file:line | rule | severity | confidence | finding | fix | est. tokens saved |
|---|-----------|------|----------|------------|---------|-----|-------------------|

`rule` is a G-rule ID; `severity` is `must` or `should`; `confidence` is
`high`, `medium` or `low`. Report every finding and filter when merging.

## Worked example

The first run is recorded in `arsenal/project/model-5-5-alignment/`: `spec.md`
(revision 2, with the maintainer's annotation export beside it), `plan.md` and
`plan-v5.md` with their readers, and the addendum
`docs/research/addendum-2026-10.md`. Its G-rules are the current
`references/model-prompting.md`; its row is the first in
`docs/MODELS.md`.
