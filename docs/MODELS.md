# Model alignment log

Which model generation the shipped prompts were last aligned with, when, and
from which guides. Maintainers append a row at the end of each run of the
`skill-workshop` model-upgrade process
(`plugins/skill-workshop/skills/skill-workshop/references/model-upgrade.md`).
Nothing reads this file at runtime, and the bundle carries no model check.

| Generation | Aligned on | Arsenal version | Guides used | Spec |
|------------|------------|-----------------|-------------|------|
| Claude 5.5 generation (Opus 5.5, Sonnet 5.5, Fable 5.1) | 2026-10-01 | 5.0.0 | [Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5), [Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5), [Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5), [Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1), [best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices); Claude Code [skills](https://code.claude.com/docs/en/skills), [sub-agents](https://code.claude.com/docs/en/sub-agents), [hooks](https://code.claude.com/docs/en/hooks) | `arsenal/project/model-5-5-alignment/` |
