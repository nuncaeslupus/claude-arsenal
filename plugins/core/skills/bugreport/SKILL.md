---
name: bugreport
description: Reads Android bugreports (dumpstate .txt or .zip) through a byte-offset index — device summary, ranked checkup, section lookup, merged timeline, redacted output. Use when the user has a bugreport to read or diagnose. Not for live-device adb sessions or logcat-only files.
argument-hint: "--input bugreport.zip"
user-invocable: true
allowed-tools: Bash(python3 *_bugreport.py *)
metadata:
  section: android
  type: tool
---

# Android bugreport analysis

CANARY: bugreport-loaded-2026-11-04-da2adc41-b71d285c189d31db

A bugreport is one 20–300 MB dumpstate text file, often inside a zip, holding
every system service's dump, the logs and the kernel ring buffer. The answer
to a question about it is a few hundred bytes in two or three sections. These
scripts reach those bytes through an index instead of reading the file.

## Standing constraints

- **Privacy.** A bugreport holds accounts, IMEI, phone numbers, SSIDs,
  locations and notification text. Every script redacts what it prints into
  salted tokens (`<imei:3f9a01c2>`); one token means one value inside a single
  run, and nothing links two runs. Process the file locally, never paste raw
  excerpts anywhere else, and never commit a real report or an excerpt of one.
  `--no-redact` exists for the device owner reading their own report; do not
  use it on someone else's.
- **Output cap.** Stdout is a JSON envelope capped at 4096 bytes (2048 for
  `sample`, `locate` and `summary`); `truncated`, `shown`, `omitted` and
  `total` say what was cut. Narrow the query (`--grep`, `--section`, `--since`)
  before raising `--limit`. `--limit 0` or `--output FILE` gives the full
  document; write it to a file and read the part needed.
- **Fallback route.** When no command answers the question directly, go
  `locate` → `sample` → `show`: find which sections mention the term, learn the
  section's shape, then read only the matching lines. Never `cat` or `grep` the
  report itself.

## Commands

Scripts live in `${CLAUDE_SKILL_DIR}/scripts/`. Every one takes
`--input R` (`.txt`, `.zip`, UTF16 accepted) and `--output-dir DIR` for the
index cache (default: the per-user cache); the first run builds the index,
later runs reuse it. `--force` rebuilds it.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/validate_bugreport.py" --input bugreport.zip              # is it a bugreport; kind, encoding, clock
python3 "${CLAUDE_SKILL_DIR}/scripts/query_bugreport.py" summary --input bugreport.zip         # device, build, coverage, battery, storage
python3 "${CLAUDE_SKILL_DIR}/scripts/analyze_bugreport.py" --input bugreport.zip              # the checkup: ranked findings
python3 "${CLAUDE_SKILL_DIR}/scripts/analyze_bugreport.py" --input bugreport.zip --family memory  # one family, plus its tables
python3 "${CLAUDE_SKILL_DIR}/scripts/query_bugreport.py" sections --input bugreport.zip        # every section id, kind, size
python3 "${CLAUDE_SKILL_DIR}/scripts/query_bugreport.py" locate --input bugreport.zip --grep lowmemorykiller
python3 "${CLAUDE_SKILL_DIR}/scripts/query_bugreport.py" sample --input bugreport.zip --section meminfo
python3 "${CLAUDE_SKILL_DIR}/scripts/query_bugreport.py" show --input bugreport.zip --section battery --grep level --context 1
python3 "${CLAUDE_SKILL_DIR}/scripts/query_bugreport.py" timeline --input bugreport.zip --since 14:15 --window 5m
```

| Script | Gives |
|---|---|
| `validate_bugreport.py` | Whether the input is a bugreport, its container and main entry, encoding facts (CR, NUL, transcoding), header, clock source, section count, each detector input's status (`parsed`, `fallback` with its route, `absent`) |
| `query_bugreport.py summary` | Device, Android build, capture time and timezone, uptime, boot reason, per-source coverage windows, file stats, battery snapshot, storage, app counts — `unknown` where the report lacks a field |
| `analyze_bugreport.py` | Findings ranked by severity then score: `claim`, `facts`, `subjects` with a role (`cause`, `victim`, `holder`), `evidence` offsets, `advice_id`. Families so far: `memory` (F6), `anr` (F4), `thermal` (F2), `churn` (a view over F6); `--family` takes slugs or F-numbers and adds that family's `views` tables; `--severity` sets a floor. A section a detector could not read is a `not_parsed` row with the `query` command that reaches it |
| `query_bugreport.py sections` | Section ids (`name#occurrence`), kind, dumpsys block, offset and size |
| `query_bugreport.py locate` | Hit count and first offset per section for `--grep RE`, no lines |
| `query_bugreport.py sample` | The first lines of `--section ID` and its sniffed format (`kv`, `table`, `tree`, `csv`, `log`, `unknown`) |
| `query_bugreport.py show` | Lines of `--section ID`, optionally filtered by `--grep` with `--context N`, with byte offsets |
| `query_bugreport.py timeline` | System, event and kernel log rows merged on one clock from `--since T` over `--window D` (default level ≥ W plus ANR, kill, crash, boot and thermal markers; `--grep RE` replaces that filter) |

Start a diagnosis with the checkup, then open the top finding's `evidence`
with `show`. An ANR whose subjects are `victim`s was caused by the system
(read the memory finding beside it), not by the app.

`create_bugreport.py` and `compare_bugreport.py` answer `--help` but are not
implemented yet; they exit 2.

**Selectors.** `--section` takes an exact id (`meminfo#2`) or a name that
matches one section (`meminfo`, case-insensitive). An ambiguous name exits 2
and lists the candidates.

**Time.** `--since` takes `HH:MM[:SS]`, `MM-DD HH:MM`, `YYYY-MM-DD HH:MM` or a
relative `-30m` (from capture time); `--window` takes `90s`, `5m`, `1h`. A time
matching two days exits 2 with both dates; a time outside the logs exits 1 and
prints the span; an empty window exits 0 with no rows. When the report has no
wall-clock source, kernel rows are marked elapsed-only and say so.

**Exit codes.** 0 answered (possibly with no rows), 1 the input or the time is
wrong (not a bugreport, outside the span), 2 the invocation is wrong (bad
flag, ambiguous selector, bad regex).

## References

| File | Load when |
|---|---|
| [references/sections.md](references/sections.md) | Choosing which section answers a question, reading an OEM or unparsed section, or a number looks wrong (locale, unsampled PSS, timeouts, duplicate services) |
