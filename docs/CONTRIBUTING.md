# Contributing to claude-arsenal

This page is for working *on* the marketplace itself — adding plugins,
extending the rubric, or fixing the shipped skills. If you only want
to install and use the plugins, see `INSTALL.md`.

---

## Dev-mode walkthrough

```bash
git clone https://github.com/nuncaeslupus/claude-arsenal
cd claude-arsenal
uv sync
make help            # list targets
make smoke           # validate every shipped skill + audit listing budget
```

Then launch a Claude Code session with both plugins mounted from your
working tree (so edits take effect without going through `/plugin
update`):

```bash
make dev             # → claude --plugin-dir ./plugins/skill-creator --plugin-dir ./plugins/core
```

Inside the session, edit a skill, then `/reload-plugins` to pick up
the change. The pre-edit hook still gates writes — load
`/skill-creator:skill-creator` before touching anything under
`plugins/*/skills/*`.

---

## Pre-commit setup

The repo ships `.pre-commit-config.yaml`. Install once:

```bash
uv pip install pre-commit    # or: pipx install pre-commit
pre-commit install
```

What runs on commit:

- `skill-validate` — runs the validator on every skill folder touched
  by the commit. Fails fast on findings.
- `sync-duplicates-check` — fails if a `_shared/` script has drifted
  between plugins.
- `ruff-check` and `ruff-format --check` against `plugins/**/*.py`
  (matches what CI runs in `make lint`).

Do not commit with `--no-verify`. If a hook fails, fix the underlying
issue; the validator's findings live in `<skill>/findings.md` with
file:line back-references.

---

## Make targets

| Target | What it does |
|---|---|
| `make sync` | `uv sync` — install/refresh dependencies. |
| `make smoke` | `validate` + `audit` + `tests/skills_smoke.sh`. CI runs this. |
| `make validate` | Validator on every plugin's skills, fail-fast. |
| `make audit` | `audit_library.py plugins/*/skills --by-plugin`. |
| `make audit-rule-drift` | Diff rule IDs between `skill-rules.md` and the research doc. |
| `make sync-dupes` | `sync_duplicates.py --check` across `plugins/*/scripts/_shared/`. |
| `make lint` | `ruff check plugins` + `mypy plugins`. |
| `make format` | `ruff format .` + `ruff check --fix .`. |
| `make dev` | Launch Claude Code with `plugins/*` mounted. |
| `make new-skill` | Prints the slash to invoke inside Claude Code. |
| `make update-skills` | Prints the slash for `/plugin update`. |
| `make clean` | Drop caches and `__pycache__`. |

---

## Adding a new plugin

1. Scaffold the plugin manifest:

   ```bash
   mkdir -p plugins/<name>/.claude-plugin plugins/<name>/skills
   cat > plugins/<name>/.claude-plugin/plugin.json <<'JSON'
   {
     "name": "<name>",
     "version": "0.1.0",
     "description": "One sentence — what this plugin gives consumers.",
     "author": { "name": "nuncaeslupus" }
   }
   JSON
   ```

2. Register the plugin in `.claude-plugin/marketplace.json` (the
   `plugins` array). Use the same `description` as in `plugin.json` so
   marketplace listings and per-plugin listings agree.

3. Scaffold the first skill inside the plugin from a Claude Code
   session:

   ```text
   /skill-creator:skill-creator
   # then: "scaffold a new skill called <slug> under plugins/<name>"
   ```

   The scaffolder (`init_skill.py --plugin <name>`) writes the
   SKILL.md template, the canary in `evals/loading_verification.json`,
   and an empty `references/` + `scripts/` tree.

4. Run `make smoke` — validates the new skill, re-audits the listing
   budget, and confirms the new plugin appears in the per-plugin
   breakdown.

5. If the plugin ships hooks, add `plugins/<name>/hooks/hooks.json`
   pointing at scripts under `plugins/<name>/hooks/*.sh`. Hooks
   resolve `${CLAUDE_PLUGIN_ROOT}` to the plugin directory, not the
   repo root.

---

## Extending the rubric

The author-checkable rubric is
`plugins/skill-creator/skills/skill-creator/references/skill-rules.md`.
Adding a rule:

1. Pick (or create) the right numbered section (`1. Frontmatter`,
   `7. Scripts and CLI conventions`, etc.).
2. Add a row with a stable ID. Format:
   `R-<group>-<n>` for must/should rules, `Q-<group>-<n>` for
   content-quality scanner rules. Cite the source —
   `docs/research/claude-skill-system_v1.17.md` § <section>.
3. Run `make audit-rule-drift`. The auditor walks every `R-*` ID in
   the rubric and confirms it is grounded in the research doc; rubric
   rows pointing at a non-existent section fail the build.
4. If the rule needs a mechanical check, extend `scripts/validate.py`
   and wire the ID into the finding output. Keep `Q-EVER-1` happy —
   `R-*` and `Q-*` IDs must never appear in SKILL.md *body prose*;
   they live in rubric rows and validator findings only.

Meta-only governance IDs (the `R-META-*`, `R-LLMJ-*` family) live one
line each in `references/research-coverage.md` with a `§` anchor back
to the research doc. They are not author-checkable, so the rubric does
not enforce them — they document deferred coverage.

---

## Repo layout

```
.claude-plugin/marketplace.json     # marketplace manifest
docs/
  INSTALL.md  UPDATE.md  CONTRIBUTING.md
  research/claude-skill-system_v1.17.md   # the upstream research archive
plugins/
  skill-creator/                    # the meta-skill plugin
    .claude-plugin/plugin.json
    hooks/                          # three shell scripts + hooks.json
    skills/skill-creator/
      SKILL.md
      assets/                       # SKILL.md template + scaffold templates
      evals/                        # canary + loading verification
      references/                   # 12 topical references
      scripts/                      # validate, audit_library, init_skill, ...
      tests/skills_smoke.sh
  core/
    .claude-plugin/plugin.json
    skills/{specify,design,execution,review,ship,github,
            session-end,mutmut-report}/
Makefile  pyproject.toml  .pre-commit-config.yaml
.github/workflows/ci.yml            # `uv sync && make smoke`
```

CLAUDE.md at the repo root is *internal-only* — it describes how
Claude operates inside this repo during development and is not shipped
to consumers.

---

## Branch + commit policy

- Feature work goes on short-lived `feat/*` branches off `main`. Open
  a PR for review; let CI run `make smoke` before merging.
- Commit messages follow Conventional Commits. The `github` skill
  under `core` documents the format in detail; the gist:
  `<type>(<scope>): <subject>` with `feat | fix | docs | refactor |
  test | chore | ...` as the type.
- Co-author trailer is dynamic — use the *active* model's name (the
  `core:github` skill explains why; no hard-coding).
- Never `--no-verify`. If a pre-commit hook complains, fix the
  underlying issue.

---

## Where to ask questions

- Bugs and feature requests:
  https://github.com/nuncaeslupus/claude-arsenal/issues
- The research source-of-truth is in-repo at
  `docs/research/claude-skill-system_v1.17.md`. Any rubric rule should
  trace back to a `§` section there; if it does not, the rule should
  not exist.
