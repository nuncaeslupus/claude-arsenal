# Installing claude-arsenal

> **Status: stub.** Full content lands at S7 (consumer docs + cutover).
> The skeleton below tracks the agreed outline so reviewers know what
> sections to expect.

---

## 1. Prerequisites

- Claude Code v2.x or later. (Verify: `claude --version`.)
- Optional: `uv` if you want to run scripts locally outside a Claude
  Code session.

## 2. Add the marketplace

```text
/plugin marketplace add github:nuncaeslupus/claude-arsenal
```

## 3. Install plugins in order

Install `skill-creator` first — it carries the pre-edit hook that gates
every other plugin's `skills/` folder. Then install `core` for the
engineering workflows.

```text
/plugin install skill-creator@claude-arsenal
/plugin install core@claude-arsenal
```

## 4. Verify

| Check | Expected |
|---|---|
| `/skill-creator:skill-creator` | Loads. The canary phrase from `evals/loading_verification.json` appears in the body. |
| `/core:discovery` | Skill is listed and loads on prompt. |
| `make audit` (local checkout) | Listing budget under cap; per-plugin breakdown printed. |

## 5. Optional `/sc` alias

If you want to call the meta-skill with a shorter slash, bind `/sc` →
`/skill-creator:skill-creator` via your keybindings file (see the
`keybindings-help` skill for the exact JSON shape).

## 6. Updating

```text
/plugin update claude-arsenal
```

What `/plugin update` rewrites vs preserves is documented in
`docs/UPDATE.md`.

## 7. Uninstall

```text
/plugin uninstall skill-creator@claude-arsenal
/plugin uninstall core@claude-arsenal
/plugin marketplace remove claude-arsenal
```

## 8. Troubleshooting hook order

If a consumer-side `PreToolUse` hook fires before this marketplace's
gate, run `claude --debug-hooks` to inspect the firing order. The gate
script writes to `stderr` on block, so you'll see both messages. Final
text lands at S7.

---

## Outstanding sections (TODO at S7)

- Cold-clone walkthrough (`git clone … && uv sync && make smoke`).
- `audit_library.py` invocation against the local cache.
- Worked examples of finding-driven authoring loops.
