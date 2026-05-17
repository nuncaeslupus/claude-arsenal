.PHONY: sync lint format test validate validate-strict new-skill update-skills clean

sync:
	uv sync

lint:
	uv run ruff check .
	uv run mypy skills/skill-validator/scripts

format:
	uv run ruff format .
	uv run ruff check --fix .

test:
	uv run pytest

validate:
	uv run python skills/skill-validator/scripts/validate.py check .

validate-strict:
	uv run python skills/skill-validator/scripts/validate.py check . --strict --include-proposed

new-skill:
	@echo "Inside Claude Code, type: /skill-creator"

update-skills:
	git subtree pull --prefix .claude/skills https://github.com/nuncaeslupus/my-skills.git main --squash

clean:
	rm -rf .pytest_cache .mypy_cache .ruff_cache dist build *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
