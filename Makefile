.PHONY: validate-manifests help sync smoke test context-budget queue-doctor tag sync-version sync-version-check validate audit audit-rule-drift sync-dupes lint format dev new-skill update-skills clean

PLUGIN_DIRS := $(wildcard plugins/*)
PLUGIN_SKILL_LIBS := $(wildcard plugins/*/skills)
PLUGIN_SKILLS := $(wildcard plugins/*/skills/*)

SC_SCRIPTS := plugins/skill-workshop/skills/skill-workshop/scripts
VALIDATE := $(SC_SCRIPTS)/validate.py
AUDIT_LIB := $(SC_SCRIPTS)/audit_library.py
AUDIT_DRIFT := $(SC_SCRIPTS)/audit_rule_drift.py
SYNC_DUPES := $(SC_SCRIPTS)/sync_duplicates.py
SMOKE_SH := plugins/skill-workshop/skills/skill-workshop/tests/skills_smoke.sh

# The resident tier — AGENTS.md plus every skill's listing entry — is what a
# consumer pays on every turn before any work happens. See CLAUDE.md § Context budget.
RESIDENT_TOKEN_BUDGET := 5000

help:  ## list available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

sync:  ## uv sync — install/refresh dependencies
	uv sync

smoke: validate-manifests validate audit  ## run manifest + skill validation and the audit, then skills_smoke.sh
	@bash $(SMOKE_SH)

# `validate` below checks the *skills*. Nothing checked the plugin manifests
# that carry them, and v1.0.0 shipped plugins/core with `"author": "..."` — a
# bare string where the loader wants an object — so Claude Code refused to load
# the plugin while the marketplace looked healthy from the outside. It runs
# first because a manifest the loader rejects makes every skill inside it
# unreachable, whatever `validate` then says about them.
validate-manifests:  ## assert every plugin manifest matches the shapes the loader requires
	python3 scripts/validate_manifests.py

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

context-budget:  ## report what this marketplace costs a consumer's context, and cap the resident tier
	uv run python scripts/context_budget.py --fail-over $(RESIDENT_TOKEN_BUDGET)

audit-rule-drift:  ## diff rule IDs in references/skill-rules.md vs docs/research/claude-skill-system_v1.17.md
	uv run python $(AUDIT_DRIFT)

tag:  ## publish v<.bundle-version> as a remote tag from HEAD — manual fallback for tag-release.yml
	@v=$$(tr -d '[:space:]' < plugins/core/skills/init/assets/.bundle-version); t="v$$v"; \
	if [ -z "$$v" ]; then echo "make tag: .bundle-version is empty" >&2; exit 1; fi; \
	git fetch --tags --quiet 2>/dev/null || true; \
	git ls-remote --exit-code --tags origin "refs/tags/$$t" >/dev/null 2>&1; s=$$?; \
	if [ $$s -eq 0 ]; then echo "make tag: $$t already published — nothing to release"; exit 0; fi; \
	if [ $$s -ne 2 ]; then \
		echo "make tag: could not query origin (git ls-remote exit $$s) — refusing to guess" >&2; exit 1; fi; \
	latest=$$(git tag -l 'v*.*.*' --sort=v:refname | tail -1 | sed 's/^v//'); \
	if [ -n "$$latest" ] && ! python3 -c "import sys; p=lambda x: list(map(int, x.split('.'))); sys.exit(0 if p(sys.argv[1]) >= p(sys.argv[2]) else 1)" "$$v" "$$latest"; then \
		echo "make tag: $$t is lower than latest v$$latest — refusing" >&2; exit 1; fi; \
	if git rev-parse --verify --quiet "refs/tags/$$t" >/dev/null 2>&1; then \
		have=$$(git rev-parse "refs/tags/$$t^{commit}"); want=$$(git rev-parse "HEAD^{commit}"); \
		if [ "$$have" != "$$want" ]; then \
			echo "make tag: local tag $$t points at $$have, but HEAD is $$want." >&2; \
			echo "  Publishing it would ship that commit to every consumer, since they fetch the" >&2; \
			echo "  exact commit the tag names. Delete it (git tag -d $$t) and re-run from the" >&2; \
			echo "  commit you mean to release." >&2; exit 1; fi; \
		echo "make tag: reusing local $$t (a previous push did not reach origin)"; \
	else git tag -a "$$t" -m "Release $$t"; fi; \
	git push origin "refs/tags/$$t:refs/tags/$$t" && echo "make tag: published $$t"

bump:  ## bump .bundle-version (LEVEL=patch|minor|major, default patch) and sync every derived copy
	@level="$${LEVEL:-patch}"; vfile=plugins/core/skills/init/assets/.bundle-version; \
	cur=$$(tr -d '[:space:]' < $$vfile); \
	next=$$(python3 -c "import sys;M,m,p=map(int,sys.argv[1].split('.'));l=sys.argv[2];print(f'{M+1}.0.0' if l=='major' else f'{M}.{m+1}.0' if l=='minor' else f'{M}.{m}.{p+1}')" "$$cur" "$$level"); \
	printf '%s\n' "$$next" > $$vfile; \
	$(MAKE) --no-print-directory sync-version; \
	echo "bump: $$cur -> $$next ($$level). Commit this, and run 'make tag' from main after it merges."

release-check:  ## verify the released version is published as a REMOTE tag — run after merging to main
	@v=$$(tr -d '[:space:]' < plugins/core/skills/init/assets/.bundle-version); \
	git ls-remote --exit-code --tags origin "refs/tags/v$$v" >/dev/null 2>&1; s=$$?; \
	if [ $$s -eq 0 ]; then echo "release-check: v$$v is published — consumers can fetch it."; \
	elif [ $$s -eq 2 ]; then \
		echo "release-check: v$$v has NO TAG."; \
		echo "  Consumers gate updates on the newest tag, so an untagged release is invisible to them"; \
		echo "  and they keep being told the previous version is current. Run: make tag"; exit 1; \
	else \
		echo "release-check: could not query origin (git ls-remote exit $$s)." >&2; \
		echo "  This says nothing about whether v$$v is published — it is a connectivity," >&2; \
		echo "  credential, or remote-configuration problem. Fix that and re-run; do not run" >&2; \
		echo "  'make tag' on the strength of this result." >&2; exit 2; fi

sync-version:  ## write the canonical .bundle-version into both plugin manifests + AGENTS.md
	uv run python scripts/sync_version.py

sync-version-check:  ## fail if any manifest / AGENTS.md version drifts from .bundle-version
	uv run python scripts/sync_version.py --check

sync-sections:  ## regenerate the shipped capability map from the skills init vendors
	uv run python scripts/sync_sections.py

sync-sections-check:  ## fail if sections.json has drifted from the shipped skills
	uv run python scripts/sync_sections.py --check

test:  ## run every plugin's behaviour tests (plugins/*/tests/*.sh) + repo-tool tests (scripts/*_test.sh)
	@set -e; for t in plugins/*/tests/*.sh scripts/*_test.sh; do \
		[ -f "$$t" ] || continue; \
		echo "=== test: $$t ==="; bash "$$t"; \
	done

queue-doctor:  ## dogfood: audit this repo's own task files (arsenal/tasks) the way a consumer would
	@# Fetch the board's issues when a channel exists, so the handle check is a real
	@# check rather than a skipped one. Without them query_status reports what it can
	@# and says so — it cannot tell a missing handle from an unasked question.
	@set -e; issues=""; \
	if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then \
		issues="$$(mktemp)"; \
		trap 'rm -f "$$issues"' EXIT INT TERM; \
		if ! gh issue list --label arsenal:task --state all --limit 200 \
			--json number,title,state,labels,assignees > "$$issues"; then \
			echo "queue-doctor: the issue fetch failed on an authenticated channel." >&2; \
			echo "  Not treating that as 'no channel' — that would skip the handle check" >&2; \
			echo "  and let this pass on a board whose tasks have no issues at all." >&2; \
			exit 2; \
		fi; \
	fi; \
	uv run python plugins/core/skills/init/assets/scripts/query_status.py \
		--tasks-dir arsenal/tasks --detail --fail-on-problems \
		$${issues:+--issues "$$issues"}

sync-dupes:  ## sync_duplicates.py --check across plugins/*/scripts/_shared/
	uv run python $(SYNC_DUPES) --check

lint:  ## ruff + mypy on plugins/*/scripts
ifeq ($(PLUGIN_DIRS),)
	@echo "make lint: no plugins yet — skipping ruff/mypy on plugins/*/scripts." >&2
	@exit 0
else
	uv run ruff check plugins scripts
	uv run mypy plugins scripts
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
	@echo "Inside Claude Code: /skill-workshop:skill-workshop (asks for a skill to scaffold)."

update-skills:  ## update the marketplace from inside a Claude Code session
	@echo "Inside Claude Code: /plugin update claude-arsenal"

clean:  ## remove caches and __pycache__
	rm -rf .pytest_cache .mypy_cache .ruff_cache dist build *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
