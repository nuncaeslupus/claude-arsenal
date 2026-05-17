.PHONY: help sync smoke validate audit audit-rule-drift sync-dupes lint format dev new-skill update-skills clean

PLUGIN_DIRS := $(wildcard plugins/*)

help:  ## list available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

sync:  ## uv sync — install/refresh dependencies
	uv sync

smoke:  ## validate every plugin's skills, audit library, run skills_smoke.sh
ifeq ($(PLUGIN_DIRS),)
	@echo "make smoke: no plugins yet (waiting on S2 — see docs/migration-baseline.md)." >&2
	@exit 1
else
	@echo "make smoke: target unstubbed — implementation lands at S2." >&2
	@exit 2
endif

validate:  ## validate every plugin's skills, fail-fast
ifeq ($(PLUGIN_DIRS),)
	@echo "make validate: no plugins yet (waiting on S2)." >&2
	@exit 1
else
	@echo "make validate: target unstubbed — implementation lands at S2." >&2
	@exit 2
endif

audit:  ## audit_library.py plugins/*/skills --by-plugin
	@echo "make audit: target unstubbed — implementation lands at S2." >&2
	@exit 2

audit-rule-drift:  ## diff rule IDs in references/skill-rules.md vs docs/research/claude-skill-system_v1.17.md
	@echo "make audit-rule-drift: target unstubbed — implementation lands at S2." >&2
	@exit 2

sync-dupes:  ## sync_duplicates.py --check across plugins/*/scripts/_shared/
	@echo "make sync-dupes: target unstubbed — implementation lands at S2." >&2
	@exit 2

lint:  ## ruff + mypy on plugins/*/scripts
ifeq ($(PLUGIN_DIRS),)
	@echo "make lint: no plugins yet — skipping ruff/mypy on plugins/*/scripts." >&2
	@exit 0
else
	uv run ruff check plugins
	uv run mypy plugins
endif

format:  ## ruff format + ruff check --fix
	uv run ruff format .
	uv run ruff check --fix .

dev:  ## launch a Claude Code session with plugins/* mounted
ifeq ($(PLUGIN_DIRS),)
	@echo "make dev: no plugins yet — nothing to mount." >&2
	@exit 1
else
	claude $(addprefix --plugin-dir ./,$(PLUGIN_DIRS))
endif

new-skill:  ## scaffold a new skill (inside a Claude Code session)
	@echo "Inside Claude Code: /skill-creator:skill-creator (asks for a skill to scaffold)."

update-skills:  ## update the marketplace from inside a Claude Code session
	@echo "Inside Claude Code: /plugin update claude-arsenal"

clean:  ## remove caches and __pycache__
	rm -rf .pytest_cache .mypy_cache .ruff_cache dist build *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
