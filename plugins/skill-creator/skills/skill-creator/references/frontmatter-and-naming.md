# Frontmatter and naming

Load when writing the YAML header of a new skill, fixing a validator
failure on `name`/`description`, or pruning an overlapping description.

## Frontmatter shape

```yaml
---
name: my-skill
description: Use when ...
---
```

Allowed keys (validator-allow-listed):

- `name` — required.
- `description` — required.
- `when_to_use` — optional. Joined with `description` for length budget.

Anything else fails validation. Keep it minimal.

## Name rules

- Regex: `^[a-z0-9]+(-[a-z0-9]+)*$`. Kebab-case, no underscores, no
  uppercase, no leading/trailing dashes.
- ≤64 characters.
- **Must equal the folder name.** `plugins/<plugin>/skills/foo-bar/` ⇒
  `name: foo-bar`. Mismatch fails fast.
- Capability skills use the data-source or surface noun: `github`,
  `release-readiness`, `mutmut-report`. One word when possible.
- Workflow skills use a verb-noun job name: `triage-issues`,
  `solve-tickets`. A `<scope>-` prefix is only used when the plugin
  slug does not already encode the scope.

## Description rules

- ≤1024 characters. Combined with `when_to_use` (if present) ≤1536.
- Third person, present tense. "Use when …" / "Triggered when …".
  Never "I will" / "we should".
- Must contain at least one trigger phrase. The validator looks for
  one of: `Use when`, `When the user`, `Triggered`, `Trigger`,
  `For when`. Case-insensitive.
- No `<` or `>` characters (HTML safety; some clients drop them).
- Distinct from siblings. Pairwise cosine ≥0.85 warns; ≥0.95 fails.
  If two skills' descriptions collide, **the skills should merge or be
  re-scoped**, not just rephrased.

### Capability description shape

> Use when *fetching / querying / extracting / running* X. Triggers — *concrete
> URL shape* / *exact CLI form* / *user phrase*. Owns scripts: `verb_noun.py`,
> `verb_noun.py`.

### Workflow description shape

> Use when the user wants to *triage / solve / verify / onboard* Y.
> Triggers — *user phrase* / *ticket-id pattern* / *file path shape*.
> Routes to the `<cap1>`, `<cap2>` capability skills.

## Distinctness — quick checks

- Two capability skills should never share the same data source noun.
- A capability description should not contain workflow verbs (triage,
  fix, solve). A workflow description should not say "owns scripts:".
- If two descriptions both fit because the surface vocabulary
  overlaps, fold the routing prose into a single workflow and have it
  call both capabilities.

## When to widen a description

Almost never. The right move when a trigger isn't firing is usually:

1. Add a *concrete* trigger phrase the user actually says.
2. Add a URL pattern, CLI form, or ID format.
3. Verify the user request is in scope — not "make the skill broader
   so it always wins."

If routing is genuinely ambiguous, fold the two skills (capability +
workflow) into a single workflow that routes to both.
