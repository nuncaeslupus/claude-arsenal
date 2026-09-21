---
id: t-d2ee8e49
title: "Sync check_skill_workshop_loaded.sh \u2014 the two copies have drifted"
priority: 10
tags: [tooling, hooks]
---

SECURITY REGRESSION IN SHIPPED CODE. This was originally filed as hash drift
between two copies of a file; an audit established what the drift actually is,
and it is materially worse than that.

The skill-edit gate refuses an Edit/Write/Bash call that would write inside a
skill folder unless skill-workshop has been loaded. It decides what a call
writes by running gate_target.py. The two copies disagree about what to do when
gate_target.py itself crashes:

  plugins/skill-workshop/hooks/check_skill_workshop_loaded.sh   (canonical, line 41)
      if ! file_path="$(... gate_target.py 2>"${gate_err}")"; then ... exit 2
      -> fails CLOSED: a crashing analyser refuses the edit, loudly.

  plugins/core/skills/init/assets/bin/check_skill_workshop_loaded.sh  (vendored, line 32)
      file_path="$(... gate_target.py 2>/dev/null || true)"
      -> fails OPEN: a crashing analyser yields an empty target, which the next
         line reads as "nothing to gate" and ALLOWS. 2>/dev/null also discards
         the error, so nothing in the transcript says the gate stopped running.

The fail-closed behaviour was added in d5588b3 (#364, fixing #347) and never
propagated to the vendored copy. The vendored copy is the one /init installs
into every consumer repo, and per its own header comment vendoring is the only
path a cloud session can use — so the copy that actually runs for consumers is
the unfixed one.

Why CI never caught it: plugins/skill-workshop/tests/gate_failclosed_test.sh:15
sets HOOKS="${SCRIPT_DIR}/../hooks" and therefore exercises the canonical copy
only. The regression test written for #347 does not test the shipped file.
Separately, audit_library.py's duplicate-script scan never looks at
plugins/*/hooks/ at all, and sync_duplicates.py — the only tool that does see
this drift — is wired into no CI workflow (see t-b7ac72fe, the root cause of
which this is the symptom).

Done means all three of:
  1. The vendored copy carries the fail-closed behaviour (sync_duplicates.py
     --apply the canonical path, or copy by hand).
  2. gate_failclosed_test.sh exercises BOTH copies, so the next divergence
     fails CI instead of shipping. Note its current early-exit
     (`[[ -f "${HOOK}" ]] || { echo "SKIP..."; exit 0; }`) passes when the
     subject is missing — a both-copies loop must not inherit that.
  3. The acceptance gate below passes.


## Acceptance gate

```bash
diff -q plugins/core/skills/init/assets/bin/check_skill_workshop_loaded.sh \
        plugins/skill-workshop/hooks/check_skill_workshop_loaded.sh
```
