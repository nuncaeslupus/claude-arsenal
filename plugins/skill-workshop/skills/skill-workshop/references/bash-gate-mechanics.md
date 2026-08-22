# Bash gate mechanics

Load when a Bash command is blocked for touching a skill folder and the reason
is not obvious, or when changing what the gate catches.

## Why Bash is gated at all

The gate's `PreToolUse` matcher was `Edit|Write|MultiEdit` until v1.1.0. None of
those see a `sed -i`, a `tee`, a heredoc redirect or a `python3 -c` one-liner,
so the gate was bypassable by the edit style a session is often steered toward
— and was in fact bypassed throughout the work that produced v0.38.0 to v1.0.0.
A gate that the ordinary path walks around is not a gate.

## What counts as a write

`plugins/skill-workshop/hooks/gate_target.py` tokenises the command with `shlex`, splits it at `;`,
`&&`, `||`, `|` and `&`, and asks each simple command where it *writes*. Paths
merely mentioned are not targets:

| Form | Target |
|---|---|
| `> f`, `>> f`, `>| f`, `&> f`, `2> f` | `f` |
| `sed -i SCRIPT f…` | every `f` |
| `tee`, `truncate`, `touch`, `chmod`, `chown`, `patch`, `ln`, `install`, `shred` | every path argument |
| `mv`, `rm`, `rmdir` | every path argument — removing a skill file mutates the skill |
| `cp SRC… DEST` | `DEST` only; sources are reads |
| `dd of=f` | `f` |
| an interpreter argument containing `write_text(`, `.write(`, `writeFileSync`, `shutil.copy/move`, `os.replace`, `.unlink(`, `.rename(`, `rmtree(`, `makedirs(` | any skill path inside the script text |

The skill-folder **root** is a target in its own right: `rm -rf …/skills/specify`
deletes the skill as surely as editing its `SKILL.md`.

`cp …/skills/specify/SKILL.md /tmp/backup` is allowed — it reads. So is
`grep … SKILL.md > /tmp/out`. That restraint is deliberate: a gate that fires on
reads gets routed around instead of through, and then it protects nothing.

## Known limits

A path built from a shell variable (`cp "$SKILL" …`) or assembled at runtime is
opaque to this. The gate raises the cost of an accidental bypass; it is not a
sandbox, and it is not a security boundary against a session that intends to
evade it.

## Changing it

`plugins/skill-workshop/tests/gate_bash_test.sh` pins both directions — write forms that must block,
read forms that must not. Add to both lists when you touch the rules; a change
that only tests the blocking half will happily ship an over-broad matcher.
