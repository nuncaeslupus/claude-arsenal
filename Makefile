.PHONY: help sync smoke test queue-doctor validate audit audit-rule-drift sync-dupes lint format dev new-skill update-skills clean

PLUGIN_DIRS := $(wildcard plugins/*)
PLUGIN_SKILL_LIBS := $(wildcard plugins/*/skills)
PLUGIN_SKILLS := $(wildcard plugins/*/skills/*)

SC_SCRIPTS := plugins/skill-creator/skills/skill-creator/scripts
VALIDATE := $(SC_SCRIPTS)/validate.py
AUDIT_LIB := $(SC_SCRIPTS)/audit_library.py
AUDIT_DRIFT := $(SC_SCRIPTS)/audit_rule_drift.py
SYNC_DUPES := $(SC_SCRIPTS)/sync_duplicates.py
SMOKE_SH := plugins/skill-creator/skills/skill-creator/tests/skills_smoke.sh

help:  ## list available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

sync:  ## uv sync — install/refresh dependencies
	uv sync

smoke: validate audit  ## run validate + audit on every plugin's skills, then skills_smoke.sh
	@bash $(SMOKE_SH)

validate:  ## validate every plugin's skills, fail-fast
ifeq ($(PLUGIN_SKILLS),)
	@echo "make validate: no plugin skills discovered." >&2
	@exit 1
else
	@set -e; for skill in $(PLUGIN_SKILLS); do \
		echo "=== validate: $$skill ==="; \
		uv run python $(VALIDATE) $$skill; \
	done
endif

audit:  ## audit_library.py plugins/*/skills --by-plugin
ifeq ($(PLUGIN_SKILL_LIBS),)
	@echo "make audit: no plugin skill libraries discovered." >&2
	@exit 1
else
	uv run python $(AUDIT_LIB) $(PLUGIN_SKILL_LIBS) --by-plugin
endif

audit-rule-drift:  ## diff rule IDs in references/skill-rules.md vs docs/research/claude-skill-system_v1.17.md
	uv run python $(AUDIT_DRIFT)

test:  ## run the core plugin behaviour tests (plugins/core/tests/*.sh)
	@set -e; for t in plugins/core/tests/*.sh; do \
		[ -f "$$t" ] || continue; \
		echo "=== test: $$t ==="; bash "$$t"; \
	done

queue-doctor:  ## dogfood: run the queue consistency check on this repo's own backlog (status/queue)
	uv run python plugins/core/skills/init/assets/scripts/queue_doctor.py \
		--queue status/queue/tasks.jsonl --fail-on warn

sync-dupes:  ## sync_duplicates.py --check across plugins/*/scripts/_shared/
	uv run python $(SYNC_DUPES) --check

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
