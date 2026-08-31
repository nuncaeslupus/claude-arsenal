# References and chunking

Load when splitting an oversized SKILL.md into reference docs, or when
a reference itself has grown too large to scan.

## When to split

Promote a section to a reference when any of:

- The body has exceeded the 400-line warning.
- A section exceeds 100 lines and is loaded only for a subset of tasks.
- A topic has its own jargon, command set, or worked examples.
- The section is rules-heavy (validator output, refactor patterns) and
  the agent rarely needs all of it at once.

Do NOT pre-emptively split when the section is short and load-on-demand
buys nothing. References add link bookkeeping.

## Reference layout

```text
.claude/skills/<skill>/
└── references/
    ├── topic-a.md
    ├── topic-b.md
    └── ...
```

- File name is the topic slug, kebab-case, ≤40 chars.
- One topic per file. Don't bundle "misc.md" / "notes.md".
- A reference is a leaf — it does not link to another reference.

## ToC requirement

Any reference >100 lines starts with a `## Contents` section listing
its `##` headings. Format:

```markdown
# Topic

## Contents

- [Section A](#section-a)
- [Section B](#section-b)
- [Section C](#section-c)

## Section A
...
```

Validator detects: line count >100 AND no `## Contents` heading in the
first 30 lines ⇒ fail.

## Linking from SKILL.md

- Every reference must be linked from the parent SKILL.md.
- Each link carries a "load this when…" trigger phrase so the agent
  knows when to open it.

Example:

```markdown
- [Scripts and CLI conventions](references/scripts-and-cli-conventions.md) — load before adding a script or reviewing one.
```

## One-hop link graph

References do not link to other references. If a reference needs
content from a sibling, copy the relevant fragment in or restructure
the SKILL.md so the agent loads both.

This avoids the agent following a chain of references and burning
context on intermediate hops.

## Path safety

- Use repo-relative paths: `references/x.md` from `SKILL.md`.
- Never use `..` to leave the skill folder.
- Never link to another skill's references.

The validator flags any `..` and any `.claude/skills/<other>/...`
reference inside SKILL.md or its references.
