# Specification: Android bugreport analysis toolkit (`bugreport` skill)

**Date**: 2026-11-04
**Ticket / PR**: none yet (opened with this spec)
**Author**: Claude, for the maintainer
**Revision**: 1
**Status**: draft
**Revision log**:
- r1 — first draft

> Review record. Each round of reviewer notes makes a new revision: bump
> **Revision**, add a log line naming the export it applied, and commit that
> export beside this file in the same commit. On approval set **Status** to
> `approved (YYYY-MM-DD, revision N)`.

> **Why this exists.** An Android bugreport already holds the full answer to
> "why did my phone freeze / drain / reboot / kill my app": logs, event tags,
> memory and process stats, ANR traces, tombstones, battery history. It is also
> a 100–250 MB text file with 800+ sections in a dozen formats, so the one thing
> nobody can do with it is read it. This document specifies a script set that
> turns it into a short, evidenced list of findings — the same move the `har`
> skill (design 0002) made for browser captures.

---

## 1. Problem statement

Diagnosing a bugreport today means grepping a huge flat file by hand, learning
each section's ad-hoc format on the way, and re-deriving the same parsers every
time. The provenance case: one real Pixel bugreport (Android 16, 156 MB text,
234 MB zip) asked "what happened?" took a session ~15 tool calls to reach a
diagnosis that is fully deterministic — memory thrashing (swap 97 % full,
`kswapd` 58 % CPU, I/O PSI `some avg10=89`) causing two input-dispatch ANRs —
and two of those calls were lost to format traps (embedded `\r` bytes shifting
line numbers; locale decimal commas `1,9GB` in procstats). The tools that used to
interpret bugreports are gone: Battery Historian (archived 2022, battery only)
and ChkBugReport (archived 2026, pre-2016 parsers). Perfetto ingests a
bugreport zip but stores dumpstate as raw lines and interprets nothing. No
official or community Claude skill analyses offline bugreports (Google's
`android/skills` covers Perfetto traces only). Forum demand is dominated by
battery drain, then overheating, random reboots, and lag/ANR/crashes — all of
which a bugreport answers if something reads it.

The goal: a session (or a human at a terminal) gets a ranked, evidenced
diagnosis from **one command**, and every follow-up question costs one more
command whose output is a few hundred bytes — never a section pasted into
context.

### Requirements (from the maintainer)

1. **Scripts, not reading.** Ultra-fast deterministic scripts return only the
   result; the session judges, it never pays tokens for the search.
2. **Find problems, not just expose data.** A detector catalogue turns raw
   sections into findings with severity and evidence.
3. **Helps more people than its author.** End users (battery, heat, freezes,
   reboots) and app developers (ANR root cause, native crashes, why the app is
   killed) are both first-class.
4. **Efficient reading.** Decide, with measurements, whether to index or convert
   the file rather than re-scanning it per question.
5. **Lives in arsenal as a tool**, alongside `har`, following its conventions.

**Success criteria (measurable)**

- [ ] `index_build_s <= 3` for a 160 MB bugreport text on the CI runner (measured today: one `mmap` + regex pass over 156 MB finds 842 sections in 0.96 s); `peak_rss_mb <= 300`.
- [ ] `query_s <= 1` for any single-section command once the index exists (seek to byte range, parse only that slice).
- [ ] `triage_output_bytes <= 4096` by default, enforced by truncation; every finding carries an evidence pointer (`section` + byte offset or file path) so the full text is one `show` command away.
- [ ] `commands_to_diagnosis <= 1`: `triage` on the provenance bugreport reports memory thrashing as the top finding, names the ANR'd processes as victims, and lists the top memory holders — judged against the manual diagnosis recorded above.
- [ ] Detector coverage: each of the six problem families in § 2.2 has ≥ 1 detector with a fixture that fires it and one that does not (`make test` asserts both).
- [ ] Android version coverage: fixtures for at least Android 12, 14 and 16 layouts parse with zero unhandled exceptions; unknown sections degrade to "not parsed", never a crash.
- [ ] `pii_in_default_output == 0`: emails, IMEI/IMSI/ICCID, phone numbers, MAC addresses and SSIDs never appear in default output (asserted by a test over a seeded fixture); `--no-redact` is the explicit opt-out.
- [ ] Zero third-party runtime dependencies for the core scripts (stdlib only, `uv run python`), including tombstone `.pb` decoding.
- [ ] Resident listing cost `<= 130` tokens for installs with the skill's section enabled and `0` for installs without it (`make context-budget`).

## 2. Systems & Impact

### 2.1 What a bugreport contains (parser facts)

- **Zip layout**: `main_entry.txt` names the main text (`bugreport-<build>-<date>.txt`); `version.txt` gives the format (`2.0` since Android P); `FS/` mirrors device paths — `FS/data/anr/` (ANR traces, one file per ANR), `FS/data/tombstones/tombstone_NN` + `.pb` (native crashes; protobuf since Android 12), `FS/data/misc/logd/` (persistent logcat, when enabled), `FS/data/misc/recovery/` and `update_engine_log/` (OTA); `proto/*.proto` (binary dumps of some services, build-dependent — 12 files in the provenance report); `dumpstate_board.txt` (vendor HAL); `visible_windows.zip`.
- **Delimiters**: `------ SECTION TITLE (command) ------` for top-level sections, `DUMP OF SERVICE [CRITICAL|HIGH ]<name>:` inside the three DUMPSYS priority blocks (a service can appear more than once), `------ 0.123s was the duration of 'SECTION TITLE' ------` closers, `*** command '…' timed out` for truncated sections.
- **Where the size is** (provenance report): Wi-Fi HAL dump 16.5 MB, `CHECKIN BATTERYSTATS` 15.3 MB, `batterystats` 11.2 MB, `activity` 9.3 MB, `package` 7.4 MB, VM traces 5.9 MB, system log 5.1 MB. Logcat is not the bulk; a section index makes almost every question a slice read.
- **Traps** (each one has already cost a real session a step): bare `\r` bytes inside lines (10 757 in the provenance file — text-mode readers shift line numbers); locale-formatted numbers (`0,00`, `1,9GB`); UTF-16 text when a `.txt` was captured through PowerShell redirection; NUL/invalid UTF-8 in logcat; logcat in local time vs batterystats/kernel in UTC/elapsed (offset from the alarm dump's `nowRTC`/`nowELAPSED`, as Perfetto does, or `persist.sys.timezone`); procstats PSS triples reading `0,00` when unsampled (use RSS as fallback).

### 2.2 Problem families the detectors target (ranked by forum demand)

| # | Family | Key signals |
|---|---|---|
| F1 | Battery drain / standby drain | batterystats checkin CSV: per-uid and kernel wakelocks, wakeup reasons, screen-off drain, mobile-radio active time, doze (`deviceidle`), standby buckets, alarms, jobs |
| F2 | Overheating / throttling | `thermalservice` status + throttling history, `am_cpu … thermal_pressure`, vendor board dump |
| F3 | Reboots / bootloops | `ro.boot.bootreason` / `sys.boot.reason(.last)`, last kmsg / pstore tail (panic), `WATCHDOG KILLING SYSTEM PROCESS`, `boot_progress_*`, uptime |
| F4 | Lag / freezes / ANR | ANR files + `ANR in` blocks (reason, load, PSI, CPU usage), main-thread stack state, `kswapd` CPU, PSI memory/io, swap fill, lmkd kills, `am_proc_died`/`am_proc_start` churn |
| F5 | App crashes / app keeps dying | tombstones (signal, abort message, crashing frame), `FATAL EXCEPTION`, `dumpsys activity exit-info` (ApplicationExitInfo reasons), repeat-crash counts |
| F6 | Memory hogs / background abuse | procstats 24 h aggregates (memory × time per process and state, incl. **foreground while screen off**), meminfo totals, persistent foreground services |

Network/modem, Bluetooth and storage are out of v1 detectors but reachable through the generic `section`/`grep` commands.

### 2.3 Systems touched

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `plugins/core/skills/bugreport/` | Primary | New skill: SKILL.md, references, stdlib scripts, evals | Yes | New code only | Med |
| Skill sections (`init.py` profiles) | Dependent | Decides who installs it; `har` lives in default-off `extract` | Yes (one entry, maybe a new section) | Listing cost only where enabled | Low |
| `.bundle-version` + `CHANGELOG.md` | Dependent | Minor bump (new skill) | Yes | Consumer-visible release note | Low |
| `plugins/core/tests/` + fixtures | Dependent | Synthetic, PII-free fixtures; detector fire/no-fire tests | Yes | CI time + a few MB of fixtures | Low |
| `har` skill | Reference only | Source of shared conventions: output cap, index sidecar, redaction stance | No | None | Low |
| User's device data | Shared resource (read-only) | Bugreports hold accounts, IMEI, SSIDs, locations, notification text | No (never written back) | Privacy: local-only processing, redacted output | High |

Impact summary: **Data** — read-only on the input, sidecar index beside it; **API** — new CLI surface, no existing contract changes; **Performance** — bounded by the criteria above; **User** — opt-in skill; **Operational** — fixtures must never contain a real report; **Risk of inaction** — every bugreport question keeps costing ~15 calls and re-learned traps.

## 3. Options

### Option A: Recipe reference + a handful of grep scripts (Conservative)

- **Description**: A SKILL.md plus a `references/sections.md` cheat-sheet of section names, patterns and traps, and 3–4 small scripts (`summary`, `anr`, `memory`) that each scan the whole file.
- **Scope**: New skill folder only.
- **Effort**: Small
- **Tradeoffs**: Fast to ship and already cuts most wasted calls. No problem detection — the session still diagnoses; each script re-scans the file (~1 s each, fine); format knowledge is spread across scripts and drifts.
- **Compatibility**: Additive.

### Option B: Indexed, detector-driven toolkit, stdlib only (Recommended)

- **Description**:
  - `index` — one pass builds a sidecar `<report>.brindex.json` (section/service → byte range, build, Android version, timezone offset, uptime) keyed by the input's size+mtime+sha256 of the first MB; reads `.zip` in place (no full extraction) or a `.txt`; normalises encoding (BOM/UTF-16) once. Every other command builds it on demand.
  - `triage` — runs the detector catalogue and prints ranked findings (`severity · family · one-line claim · evidence pointer`), plus a three-line device header. This is the default entry point.
  - Family commands, each a slice reader with a fixed compact output: `memory` (procstats 24 h memory×time ranking with state, meminfo totals, swap, PSI, lmkd kills), `anr` (per ANR: reason, victim vs pressure, main-thread state, top CPU), `crashes` (tombstones via a ~100-line stdlib protobuf varint decoder, Java fatal exceptions, exit-info reasons), `battery` (from the checkin CSV, not the text form), `reboots`, `thermal`, `churn` (kill → restart loops and what restarted them).
  - Generic access, so nothing in the report is unreachable: `sections` (list with sizes), `show <section> [--grep re] [--around HH:MM:SS --window 2m]`, `timeline --at HH:MM --window 5m` (merged event log + system log + ANR/kill markers).
  - `redact` — writes a scrubbed copy (emails, IMEI by Luhn, phone numbers, MACs, SSIDs, account names, coordinates) for sharing; the same filter is on by default for all stdout.
  - `compare A B` — before/after diff of findings and memory/battery rankings (e.g. "did the restriction help?").
  - Output discipline copied from `har`: ≤ 4096 bytes by default, `--json` for full machine output to a file, `--help` on every script.
- **Scope**: New skill folder, section entry, tests + synthetic fixtures, changelog.
- **Effort**: Large (deliverable in 3–4 stacked PRs: index + generic access → memory/anr/churn + triage → crashes/battery/reboots/thermal → redact/compare).
- **Tradeoffs**: The detectors are the value and also the maintenance cost: formats shift between Android releases and OEMs, so every detector must fail soft ("section not parsed") and be fixture-tested. Byte-range index over SQLite: one JSON file, no conversion step; SQLite only earns its keep for repeated time-window logcat queries, which `timeline` can add later behind the same interface.
- **Compatibility**: Additive; no dependency on Perfetto or protobuf libraries.

### Option C: Build on Perfetto `trace_processor` as the substrate

- **Description**: Load the zip into Perfetto's SQL tables (`android_logs`, `android_dumpstate`, `battery_stats`) and write the detectors as SQL queries over them.
- **Scope**: New skill + a pip dependency (`perfetto`) that downloads a native binary.
- **Effort**: Medium
- **Tradeoffs**: Free logcat parsing and SQL joins, and alignment with Google's own trace skill. But dumpstate is stored as raw lines (detectors still parse text, now inside SQL), batterystats import is partial (~30–40 % of events per Perfetto issue #934), load time and RAM are far above a byte-range index, and the binary download fails in network-restricted environments (cloud sessions, CI behind proxies).
- **Compatibility**: Additive, but adds a heavy runtime dependency to a stdlib-only bundle.

### Option D: MCP server instead of a skill

- **Description**: Expose the same analyses as MCP tools.
- **Tradeoffs**: MCP earns its place for remote systems, auth, live state or non-Claude clients. For a local file it adds a server process and up-front tool-definition tokens while doing exactly what `uv run python script.py` already does; the skill's resident cost is one listing line, and script output is already bounded before it reaches context. Google's Perfetto skill made the same call (bundled CLI, not MCP). A thin MCP wrapper over Option B's CLI stays possible later if non-Claude agents need it; live device capture over adb is already covered by existing MCP servers.
- **Effort / Compatibility**: Medium; separate install path outside the marketplace model.

### Comparison

| | Option A | Option B | Option C | Option D |
|---|---|---|---|---|
| Effort | Small | Large | Medium | Medium |
| Risk | Low | Medium (format drift, mitigated by fail-soft + fixtures) | Medium–High (binary download, partial import) | Medium |
| Finds problems by itself | No | Yes | Yes | Same as B |
| Dependencies | stdlib | stdlib | `perfetto` + native binary | MCP runtime |
| Follow-up query cost | ~1 s re-scan | ≤ 1 s slice | SQL, after slow load | as B + tool tokens |
| Fits arsenal conventions | Partly | Yes (mirrors `har`) | Partly | No |

## 4. Recommendation

**Recommended option**: **B** — it is the only option that meets "find problems,
not just expose data" without a native dependency, and it reuses the decisions
`har` already proved (index sidecar, bounded output, redaction by default,
`--json` escape hatch). A is a strict subset and becomes B's first PR; C stays
an optional backend idea for logcat-heavy questions; D is rejected for v1.

**Immediate next action**: after approval, run `design` to turn this into
contracts and a stacked PR plan; first PR = `index` + `sections` + `show` +
`timeline` + synthetic-fixture generator, so every later detector has a fast,
tested substrate.

**Gates check**: objective (§ 1), scope (§ 2.3), impacted systems (§ 2.3),
compatibility (additive, minor bump), risk (format drift, PII — § 2.1/§ 2.3),
validation (success criteria), release readiness (changelog entry + `make
context-budget` row).

**Open questions**:
1. Section: put `bugreport` in the existing default-off `extract` section next to `har`, or create a new default-off `diagnostics` (or `android`) section? Draft assumes a new `diagnostics` section — "extract" describes scraping, not device diagnosis.
2. Fixtures: synthetic only (generated by a script, zero PII), or also redacted excerpts from real reports the maintainer is willing to contribute?
3. Should `triage` also emit end-user advice ("restrict app X: Settings → Apps → X → Battery → Restricted"), or stay at diagnosis and leave advice to the session? Draft: short, optional `--advice` hints for the six families, off by default.
4. Should `compare` be in v1 or deferred?

**Decisions log**:
- D-1 — Lives inside `claude-arsenal` (not a separate repo), as a tool skill like `har` (maintainer, 2026-11-04).
- D-2 — Skill + stdlib scripts, not an MCP server (this spec, Option D rationale; open to a thin MCP wrapper later).
