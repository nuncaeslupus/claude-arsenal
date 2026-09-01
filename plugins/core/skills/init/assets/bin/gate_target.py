#!/usr/bin/env python3
#
# DUPLICATED ACROSS SKILLS:
# - plugins/skill-workshop/hooks/gate_target.py (canonical)
# - plugins/core/skills/init/assets/bin/gate_target.py
# Shipped in the core bundle because plugin hooks do not travel with vendored
# skills, and vendoring is the only path a cloud session can use. Keep both
# copies in sync. Update via skill-workshop's sync_duplicates.py.
"""gate_target.py — decide what a tool call is about to write inside a skill folder.

Reads a PreToolUse payload on stdin, prints the skill-folder path the call would
modify, or nothing when it would not modify one.

Edit / Write / MultiEdit name their target outright. Bash does not: `sed -i`,
`tee`, a heredoc redirect and a Python one-liner all reach a SKILL.md without
ever appearing as a `file_path`, which is how the gate came to be bypassable by
the edit style the harness encourages.

For Bash the command is tokenised and each simple command is asked where it
*writes*, which is not the same as which paths it mentions. `cp SKILL /tmp/bak`
only reads the skill; `cp /tmp/x SKILL` overwrites it. Getting that distinction
wrong is costly in both directions — a gate that misses a write is no gate, and
one that blocks reads gets routed around instead of through.

Known limits: a path built from a shell variable (`cp "$SKILL" …`) is opaque
here, and so is one assembled at runtime. This raises the cost of an accidental
bypass; it is not a sandbox.
"""
from __future__ import annotations

import json
import re
import shlex
import sys

# A skill folder — `.claude/skills/<name>` or `plugins/<plugin>/skills/<name>` —
# or anything beneath it. The root itself counts: `rm -rf …/skills/specify`
# deletes the skill as surely as editing its SKILL.md does.
# `(?:.*/)?` rather than a character class: shlex has already resolved quoting,
# so the prefix is a real directory path and may contain anything a filesystem
# allows — spaces included. Ending it at `/` keeps the match on a path
# boundary, so `notplugins/core/skills/x` is not mistaken for a skill.
SKILL_PATH = re.compile(
    r"^(?:.*/)?(?:\.claude/skills|plugins/[^/]+/skills)/[^/]+(?:/.*)?$"
)

# The same shape, found anywhere inside a larger string (an interpreter script).
# Inside an interpreter argument the prefix is unknowable, so only the marker
# onward is matched — enough for the decision. `(?:^|[\s'"/])` keeps it on a
# path boundary so `notplugins/core/skills/x` does not trip the gate.
EMBEDDED_PATH = re.compile(
    r"(?:^|(?<=[\s'\"/]))(?:\.claude/skills|plugins/[^/\s'\"]+/skills)/[^/\s'\"]+(?:/[^\s'\"]*)?"
)

REDIRECTS = {">", ">>", ">|", "&>", "&>>", "1>", "2>", "1>>", "2>>"}
# `(` and `)` are deliberately absent — they are handled in `_simple_commands`,
# where the difference between a subshell and a function call can be told.
SEPARATORS = {";", "&&", "||", "|", "&", "\n"}

# Where each utility writes, given its file arguments.
#   "all"  — every path argument is a destination
#   "last" — only the final path argument (cp: sources are reads)
ALL, LAST = "all", "last"
UTILITIES = {
    "tee": ALL, "truncate": ALL, "touch": ALL, "chmod": ALL, "chown": ALL,
    "patch": ALL, "ln": ALL, "install": ALL, "shred": ALL,
    # mv and rm remove their sources, which mutates the skill just as much.
    "mv": ALL, "rm": ALL, "rmdir": ALL,
    "cp": LAST,
}

# Interpreter write calls, for the heredoc-into-python route.
#
# The `open(...)` alternative matches on the MODE, not on a later `.write`:
# `open(path, "w").close()` truncates the file to nothing and never calls
# `write`, so a pattern keyed on the write itself missed the one form that
# destroys a skill without writing a byte. `w`, `a`, `x` and `+` are the modes
# that can mutate; `r`, `rb`, `rt` and a bare `open(path)` are reads and must
# not match, because a gate that blocks reads gets routed around rather than
# through.
WRITERS = re.compile(
    r"write_text\s*\(|\.write\s*\(|writeFileSync|shutil\.(?:copy|move)"
    r"|os\.replace|\.unlink\s*\(|\.rename\s*\(|rmtree\s*\(|makedirs\s*\("
    r"""|open\s*\([^)]*?,\s*(?:mode\s*=\s*)?['"][rwaxbt+]*[wax+][rwaxbt+]*['"]"""
)

# `git` subcommands that overwrite or delete a path they are given. `git` was
# absent from UTILITIES entirely, so `git restore SKILL.md` and
# `git checkout -- SKILL.md` — the two commands a session reaches for to undo an
# edit — sailed past the gate. Read-only plumbing (`diff`, `log`, `show`,
# `status`, `add`) is deliberately not here.
#
# Known limit: `git apply patch.diff` names the patch, not what it rewrites, so
# the destination is not visible from the command line at all.
GIT_WRITE_SUBCOMMANDS = frozenset({"restore", "checkout", "rm", "clean", "mv", "stash"})

# `git` options that consume the argument after them, so the subcommand is not
# mistaken for their value in `git -C /repo restore …`.
GIT_GLOBAL_OPTS_WITH_VALUE = frozenset(
    {"-C", "-c", "--git-dir", "--work-tree", "--exec-path", "--namespace"}
)


# A backslash-newline is a line continuation: bash removes it and the command
# carries on. Removed here too, before the lexer is told to treat a newline as a
# separator, or `cp SKILL \<newline> /tmp/bak` would split into `cp SKILL` and
# report a *read* of the skill as a write. Inside a quoted heredoc body bash
# would keep the backslash; joining two lines of an interpreter script costs
# nothing, because that text is scanned by regex for paths and write calls
# rather than parsed.
_LINE_CONTINUATION = re.compile(r"\\\n")


def _tokenise(command: str) -> list[str]:
    # `\n` is punctuation rather than whitespace: bash separates commands on an
    # unquoted newline, and dropping it merged
    #     echo starting
    #     rm -rf .claude/skills/specify
    # into one token stream whose first word is `echo` — so the gate looked at
    # `echo`, found no destination, and let the `rm` through. A newline inside
    # quotes still belongs to its token, which is what keeps a heredoc whole.
    lexer = shlex.shlex(
        _LINE_CONTINUATION.sub("", command), posix=True, punctuation_chars="();<>|&\n"
    )
    lexer.whitespace_split = True
    lexer.whitespace = " \t\r"
    try:
        return list(lexer)
    except ValueError:
        # Unbalanced quotes — fall back to a whitespace split rather than
        # letting a malformed command sail past unexamined.
        return command.split()


def _simple_commands(tokens: list[str]) -> list[list[str]]:
    """Split on what bash treats as a command boundary — and only on that.

    `(` opens a subshell only in **command position**; anywhere else it is the
    paren of a call. Splitting on every one of them tore
    `p.write_text(".claude/skills/x/SKILL.md")` into a fragment ending in
    `p.write_text` — which `WRITERS` cannot match, because the regex needs the
    paren adjacent — and a fragment holding only the path, with no write signal
    beside it. The result was not a partial miss: the whole heredoc-into-python
    route, the one the module docstring names as the reason this file exists,
    returned nothing at all.
    """
    out: list[list[str]] = [[]]
    depth = 0
    for tok in tokens:
        if tok == "(" and not out[-1]:
            # Command position: a real subshell.
            depth += 1
            out.append([])
        elif tok == ")" and depth:
            depth -= 1
            out.append([])
        elif tok in SEPARATORS:
            out.append([])
        else:
            # Including a `(` mid-command and its `)`, so the joined text still
            # reads as `write_text ( … )` for the regexes below.
            out[-1].append(tok)
    return [c for c in out if c]


def _git_destinations(rest: list[str]) -> list[str]:
    """Paths a `git` invocation overwrites, or none when the subcommand only reads."""
    i = 0
    while i < len(rest):
        tok = rest[i]
        if tok in GIT_GLOBAL_OPTS_WITH_VALUE:
            i += 2
            continue
        if tok.startswith("-"):
            i += 1
            continue
        break
    if i >= len(rest) or rest[i] not in GIT_WRITE_SUBCOMMANDS:
        return []
    # Everything after the subcommand that is not a flag or the `--` separator.
    # A tree-ish (`git checkout HEAD~1 -- path`) or a branch name lands here too
    # and is harmless: it is not shaped like a skill path, so it never matches.
    return [a for a in rest[i + 1:] if a != "--" and not a.startswith("-")]


def _destinations(cmd: list[str]) -> list[str]:
    """Paths this simple command writes to."""
    dests: list[str] = []
    args: list[str] = []
    i = 0
    while i < len(cmd):
        tok = cmd[i]
        if tok in REDIRECTS:
            if i + 1 < len(cmd):
                dests.append(cmd[i + 1])
            i += 2
            continue
        args.append(tok)
        i += 1

    if not args:
        return dests
    # Skip leading VAR=value assignments and `sudo`/`command` wrappers.
    pos = 0
    wrappers = ("sudo", "command", "env")
    while pos < len(args) and (re.match(r"^\w+=", args[pos]) or args[pos] in wrappers):
        pos += 1
    if pos >= len(args):
        return dests
    util = args[pos].rsplit("/", 1)[-1]
    rest = args[pos + 1:]
    files = [a for a in rest if not a.startswith("-")]

    if util == "git":
        dests.extend(_git_destinations(rest))
    elif util == "sed":
        if any(a.startswith("-i") for a in rest):
            # sed -i 's/…/…/' FILE… — the script is the first non-flag arg.
            dests.extend(files[1:] if len(files) > 1 else files)
    elif util == "dd":
        dests.extend(a.split("=", 1)[1] for a in rest if a.startswith("of="))
    elif util in UTILITIES:
        mode = UTILITIES[util]
        if mode == ALL:
            dests.extend(files)
        elif files:
            dests.append(files[-1])
    elif WRITERS.search(" ".join(cmd)):
        # An interpreter gets its script as one argument, so the path is inside
        # a token rather than being one. Scan the text for skill-shaped paths.
        dests.extend(EMBEDDED_PATH.findall(" ".join(cmd)))
    return dests


def bash_target(command: str) -> str:
    for cmd in _simple_commands(_tokenise(command)):
        for dest in _destinations(cmd):
            if SKILL_PATH.match(dest.strip("'\"")):
                return dest
    return ""


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        return 0  # unparseable payload is not this hook's problem — allow
    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    if tool == "Bash":
        print(bash_target(ti.get("command", "") or ""))
    else:
        print(ti.get("file_path", "") or "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
