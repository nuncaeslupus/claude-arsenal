# Claude Arsenal — Specification (annotated edition)

> Generated 2026-11-04. This is the document with a **note slot** after every section that has text of its own. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# 0005 Bugreport Analysis Toolkit

## Preamble & scope

**Date**: 2026-11-04
**Ticket / PR**: none yet (opened with this spec)
**Author**: Claude, for the maintainer
**Revision**: 3
**Status**: approved (2026-11-04, revision 3) — without annotations
**Revision log**:
- r1 — first draft
- r2 — applied `0005-bugreport-analysis-toolkit-spec-notes-2026-11-04.md` (7 notes): full-checkup mode with advice, security & hygiene family, extra families (network, Bluetooth/GPS, storage/OTA, battery health), fallback primitives for unparsed sections, `android` section, Perfetto as ideas only, `compare` reduced to a JSON diff, skill-workshop conventions, public multi-OEM samples; then, from conversation: public corpus findings (§ 2.1.1) and D-9 (real reports as study material only); then review fixes from the adversarial round and CodeRabbit (selectors, redaction ids, capped-JSON envelope, index location, fixture size)
- r3 — maintainer additions in conversation (2026-11-04): file summary command (`query_bugreport.py summary`, requirement 12) and a single version bump for the whole stack (D-10); §§ 5–6 appended by `design`

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

<!-- -->

> **✎ Notes** · `SPEC · intro`
> _(your notes here — replace this line)_

## §1 Problem statement

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

<!-- -->

> **✎ Notes** · `SPEC §1`
> _(your notes here — replace this line)_

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
6. **An auto-diagnostic, not a parser.** "How is my phone doing?" runs every
   detector and answers with problems *and* remedies (close or restrict an app,
   cut battery use, avoid heat, free storage…), including problems the user
   has not noticed yet.
7. **Security and hygiene are in scope**: apps installed outside an app store,
   risky permissions and app configurations, device-level security settings.
8. **Nothing is unreachable.** When a section cannot be parsed (a new Android
   release, an OEM format), cheap generic primitives still let the session
   locate, sample and interpret it without reading it whole.
9. **Built to skill-workshop rules** (§ 2.4) — the rubric gates every file in
   the skill folder.
10. **No Perfetto dependency**; its ideas may be borrowed.
11. **Broad coverage**: test material from several Android versions and OEMs,
    not only the maintainer's phone.
12. **A summary of the file** — device model and OEM, Android build and patch level, which time span each data source covers, and basic statistics — so the first question "what is in here?" costs one command.

**Success criteria (measurable)**

- [ ] `index_build_s <= 3` for a 160 MB bugreport text on the CI runner (measured today: one `mmap` + regex pass over 156 MB finds 842 sections in 0.96 s); `peak_rss_mb <= 300`.
- [ ] `query_s <= 1` for any single-section command once the index exists (seek to byte range, parse only that slice).
- [ ] `checkup_output_bytes <= 4096` by default, enforced by truncation; every finding carries an evidence pointer (`section` + byte offset or file path) so the full text is one `show` command away.
- [ ] `commands_to_diagnosis <= 1`: `analyze_bugreport.py` (full checkup) on the provenance bugreport reports memory thrashing as the top finding, names the ANR'd processes as victims, and lists the top memory holders — judged against the manual diagnosis recorded above. In CI this runs on a synthetic fixture reproducing that report's signals (swap ≥ 95 %, `kswapd` CPU, PSI, two input ANRs); the real report is re-checked locally before release (D-9).
- [ ] Detector coverage: each problem family F1–F11 in § 2.2 has ≥ 1 detector with a fixture that fires it and one that does not (`make test` asserts both).
- [ ] Advice coverage: every finding id has an entry in `references/advice.md` (a test diffs the two id sets; missing entry = build failure).
- [ ] Android version / OEM coverage: synthetic fixtures reproduce the layouts seen in the corpus (§ 2.1.1) — pre-P (no priority blocks), 9–17 with CRITICAL/HIGH, Samsung `DUMPSYS NORMAL` + OEM sections, Xiaomi/OnePlus/Huawei sections, zips without `main_entry.txt` — and all parse in CI with zero unhandled exceptions; before each release the real corpus is re-run locally (not in CI) with the same zero-exception bar. Unknown sections degrade to "not parsed", never a crash.
- [ ] `summary_output_bytes <= 2048` and every summary field present (value or `unknown`) on every layout fixture; on the provenance report the coverage windows match the hand-read values within one minute.
- [ ] Fallback cost: for a section with no parser, `commands_to_first_fields <= 2` (`query … locate`, then `query … sample`), each `output_bytes <= 2048`.
- [ ] `validate.py` (skill-workshop) reports 0 `must` findings on the skill folder.
- [ ] `pii_in_default_output == 0`: emails, IMEI/IMSI/ICCID, phone numbers, MAC addresses and SSIDs never appear in default output (asserted by a test over a seeded fixture); `--no-redact` is the explicit opt-out.
- [ ] Zero third-party runtime dependencies for the core scripts (stdlib only, `uv run python`), including tombstone `.pb` decoding.
- [ ] Resident listing cost `<= 130` tokens for installs with the skill's section enabled and `0` for installs without it (`make context-budget`).

<!-- -->

> **✎ Notes** · `SPEC › Requirements (from the maintainer)`
> _(your notes here — replace this line)_

## §2 Systems & Impact

### §2.1 What a bugreport contains (parser facts)

- **Zip layout**: `main_entry.txt` names the main text (`bugreport-<build>-<date>.txt`); `version.txt` gives the format (`2.0` since Android P); `FS/` mirrors device paths — `FS/data/anr/` (ANR traces, one file per ANR), `FS/data/tombstones/tombstone_NN` + `.pb` (native crashes; protobuf since Android 12), `FS/data/misc/logd/` (persistent logcat, when enabled), `FS/data/misc/recovery/` and `update_engine_log/` (OTA); `proto/*.proto` (binary dumps of some services, build-dependent — 12 files in the provenance report); `dumpstate_board.txt` (vendor HAL); `visible_windows.zip`.
- **Delimiters**: `------ SECTION TITLE (command) ------` for top-level sections, `DUMP OF SERVICE [CRITICAL|HIGH ]<name>:` inside the three DUMPSYS priority blocks (a service can appear more than once), `------ 0.123s was the duration of 'SECTION TITLE' ------` closers, `*** command '…' timed out` for truncated sections.
- **Where the size is** (provenance report): Wi-Fi HAL dump 16.5 MB, `CHECKIN BATTERYSTATS` 15.3 MB, `batterystats` 11.2 MB, `activity` 9.3 MB, `package` 7.4 MB, VM traces 5.9 MB, system log 5.1 MB. Logcat is not the bulk; a section index makes almost every question a slice read.
- **Traps** (each one has already cost a real session a step): bare `\r` bytes inside lines (10 757 in the provenance file — text-mode readers shift line numbers); locale-formatted numbers (`0,00`, `1,9GB`); UTF-16 text when a `.txt` was captured through PowerShell redirection; NUL/invalid UTF-8 in logcat; logcat in local time vs batterystats/kernel in UTC/elapsed (offset from the alarm dump's `nowRTC`/`nowELAPSED`, as Perfetto does, or `persist.sys.timezone`); procstats PSS triples reading `0,00` when unsampled (use RSS as fallback).

<!-- -->

> **✎ Notes** · `SPEC §2.1`
> _(your notes here — replace this line)_

### §2.1.1 Public sample corpus (collected for r2)

29 public sample sets (527 MB) were gathered from GitHub: 15 full reports and partial files (legacy 4.x/6.0 dumpstate fragments, MVT/ALEAPP fixtures, text and `.pb` tombstones, ANR traces, `batterystats --checkin` at vers 15 and 36, procstats, Android TV meminfo).

| Android | OEM / device (full reports) |
|---|---|
| 9 | Huawei, LG, Samsung |
| 10 | LG |
| 11 | OnePlus, BLU (Android Go), emulator |
| 12 | Samsung (zip with full `FS/`) |
| 13 | Samsung, Sky (Android Go, `.pb` tombstones) |
| 14 | Xiaomi (zip with only the text) |
| 16 | Samsung (229 MB), emulator ×2 |
| 17 | emulator, 16 KB pages |

Plus the maintainer's own five Pixel 8 / Android 16 reports (local only, real PII), which carry known outcomes: memory thrashing + ANRs, battery exhaustion to `shutdown,battery` driven by one app in the foreground with the screen off.

Gaps: no full Android 8 or 15, Motorola, Wear OS, Automotive or TV report; two Pixel reports exist but sit on hosts the build environment cannot reach. Almost no sample carries a licence, and nearly every real-device report contains PII, so none is committed (D-9).

Format differences the parser must absorb (found in the corpus):
- 4.x/6.0: no `DUMPSYS CRITICAL/HIGH` blocks and no format-version line. From Android 9 onward, every report has both.
- Samsung: an extra `DUMPSYS NORMAL` block and many OEM sections (`AP RESET INFO EXTEND`, `SEC_MEDIA`, `End of OLOG`).
- Other OEM sections: Xiaomi (`POWERUP_REASON`, `qsee_log`, `PERFLOCK HISTORY`), OnePlus (`OMMSERVICE`), Huawei (kernel live-patch).
- Android 9: legacy `QTAGUID` sections.
- The header grows: on 16 the format-version line sits near line 43, so detect by pattern, not a fixed prefix.
- Some zips have no `main_entry.txt`; the main file may be `dumpstate-<date>.txt`, an arbitrary name (`example.txt`), or a bare `dumpstate.txt`. Pick the largest text entry with a dumpstate header.

<!-- -->

> **✎ Notes** · `SPEC §2.1.1`
> _(your notes here — replace this line)_

### §2.2 Problem families the detectors target (ranked by forum demand)

| # | Family | Key signals |
|---|---|---|
| F1 | Battery drain / standby drain | batterystats checkin CSV: per-uid and kernel wakelocks, wakeup reasons, screen-off drain, mobile-radio active time, doze (`deviceidle`), standby buckets, alarms, jobs |
| F2 | Overheating / throttling | `thermalservice` status + throttling history, `am_cpu … thermal_pressure`, vendor board dump |
| F3 | Reboots / bootloops | `ro.boot.bootreason` / `sys.boot.reason(.last)`, last kmsg / pstore tail (panic), `WATCHDOG KILLING SYSTEM PROCESS`, `boot_progress_*`, uptime |
| F4 | Lag / freezes / ANR | ANR files + `ANR in` blocks (reason, load, PSI, CPU usage), main-thread stack state, `kswapd` CPU, PSI memory/io, swap fill, lmkd kills, `am_proc_died`/`am_proc_start` churn |
| F5 | App crashes / app keeps dying | tombstones (signal, abort message, crashing frame), `FATAL EXCEPTION`, `dumpsys activity exit-info` (ApplicationExitInfo reasons), repeat-crash counts |
| F6 | Memory hogs / background abuse | procstats 24 h aggregates (memory × time per process and state, incl. **foreground while screen off**), meminfo totals, persistent foreground services |
| F7 | Network / modem | signal strength history and radio-active time (batterystats), mobile/Wi-Fi drops and scan storms (`connectivity`, `wifi`, `telephony.registry`), `netstats` per-app data |
| F8 | Bluetooth / GPS / sensors | Bluetooth HAL crashes and HCI timeouts (tombstones, `bluetooth_manager`), `location` request holders and GPS on-time, sensor wakeups |
| F9 | Storage / updates | free space (`diskstats`), app cache sizes, OTA / `update_engine` failures, `dex2oat` storms after updates |
| F10 | Security & hygiene | apps whose installer is not an app store (`dumpsys package` installer fields); `REQUEST_INSTALL_PACKAGES` granted; enabled accessibility services, device admins, notification listeners, overlay and usage-access holders; user-installed CA certificates; always-on VPN; ADB / developer options on; bootloader unlocked or verified-boot not green; security patch age; Play Protect status where exposed |
| F11 | Battery health & charging | `dumpsys battery` health, capacity vs design, cycle count, charge-rate limits, temperature while charging |

**Full checkup.** A question as broad as "how is my phone doing?" runs every
detector of F1–F11 in one command and returns findings ranked by severity,
each with a remedy id (§ Option B). It surfaces latent problems too — a
background app holding 2 GB with the screen off, a sideloaded app with
accessibility access, swap at 97 % — not only the one the user came with.

<!-- -->

> **✎ Notes** · `SPEC §2.2`
> _(your notes here — replace this line)_

### §2.3 Systems touched

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `plugins/core/skills/bugreport/` | Primary | New skill: SKILL.md, references, stdlib scripts, evals. `plugins/core/` is the folder every vendored skill lives in (`har` included) — **not** the always-installed tier; who installs it is decided by the section below | Yes | New code only | Med |
| Skill sections (`init.py`, `assets/sections.json`) | Dependent | New default-off section **`android`** (frontmatter `metadata.section: android`); `har` stays in `extract`. Room for future Android tools (logcat, ANR/tombstone-only inputs) | Yes (one section entry, regenerated manifest) | Listing cost only where enabled; 0 for everyone else | Low |
| `.bundle-version` + `CHANGELOG.md` | Dependent | Minor bump (new skill) | Yes | Consumer-visible release note | Low |
| `plugins/core/tests/` + fixtures | Dependent | Synthetic, PII-free fixtures; detector fire/no-fire tests | Yes | CI time; fixtures are generated at test time by the fixture generator, committed seeds stay ≤ 200 KB (the `har` skill's fixtures are 136 KB) | Low |
| `har` skill | Reference only | Source of shared conventions: output cap, index sidecar, redaction stance | No | None | Low |
| User's device data | Shared resource (read-only) | Bugreports hold accounts, IMEI, SSIDs, locations, notification text | No (never written back) | Privacy: local-only processing, redacted output | High |

<!-- -->

> **✎ Notes** · `SPEC §2.3`
> _(your notes here — replace this line)_

### §2.4 Skill-workshop constraints the design must meet

- Authoring runs under `/skill-workshop:skill-workshop`; its validator must report 0 `must` findings.
- Frontmatter: `name: bugreport` (folder name, kebab-case), third-person `description` stating what + when with a negative trigger ("Not for live-device adb sessions or logcat-only files" — or whatever scope v1 ends with), no angle brackets, `metadata.section: android`, `metadata.type: tool`, `allowed-tools` pre-approving the script invocations.
- Body ≤ 500 lines, imperative voice, no second person; standing constraints (privacy, output cap, fallback route) front-loaded; detail in `references/` with "load when…" triggers; `references/_index.md` if the body passes 300 lines; each reference ≤ 10K tokens; no PII in references.
- Scripts: `verb_noun.py` naming, canonical flags (`--input`, `--output`, `--output-dir`, `--json`, `--limit`, `--since`), domain flags `--family`, `--advice`, `--no-redact`, `--window` registered in the validator's canon list rather than invented ad hoc, stdout = payload only, progress and errors on stderr via `_console.py`, exit codes 0/1/2, `main()` + guard, no top-level work, `--help` on every script.
- Evals: loading-verification + trigger evals in `evals/`, like `har`.

Impact summary: **Data** — read-only on the input, sidecar index in `--output-dir` (default: a per-user cache dir keyed by the input hash, so read-only inputs and zips work); **API** — new CLI surface, no existing contract changes; **Performance** — bounded by the criteria above; **User** — opt-in skill; **Operational** — fixtures must never contain a real report; **Risk of inaction** — every bugreport question keeps costing ~15 calls and re-learned traps.

<!-- -->

> **✎ Notes** · `SPEC §2.4`
> _(your notes here — replace this line)_

## §3 Options

### Option A: Recipe reference + a handful of grep scripts (Conservative)

- **Description**: A SKILL.md plus a `references/sections.md` cheat-sheet of section names, patterns and traps, and 3–4 small scripts (`summary`, `anr`, `memory`) that each scan the whole file.
- **Scope**: New skill folder only.
- **Effort**: Small
- **Tradeoffs**: Fast to ship and already cuts most wasted calls. No problem detection — the session still diagnoses; each script re-scans the file (~1 s each, fine); format knowledge is spread across scripts and drifts.
- **Compatibility**: Additive.

<!-- -->

> **✎ Notes** · `SPEC › Option A: Recipe reference + a handful of grep scripts (Conservative)`
> _(your notes here — replace this line)_

### Option B: Indexed, detector-driven toolkit, stdlib only (Recommended)

- **Description** — five scripts sharing one library (`_brlib.py`: index, slice reader, tolerant number parsing, redaction filter, `_console.py`):
  - **`analyze_bugreport.py`** — the entry point. Builds or reuses the index, then runs detectors and emits findings. Default mode is the **full checkup** (all families F1–F11); `--family memory,anr,…` narrows it. Each finding: `id`, `severity`, `family`, one-line `claim`, key `facts` (numbers), `evidence` pointer (section + byte offset, or `FS/` path), `advice_id`. Family views give the fixed compact tables a follow-up needs: memory (procstats 24 h memory × time by process and state, meminfo, swap, PSI, lmkd kills), ANR (reason, victim vs pressure, main-thread state, top CPU), crashes (tombstones via a ~100-line stdlib protobuf varint decoder, Java fatal exceptions, exit-info reasons), battery (from the checkin CSV, not the text form), reboots, thermal, churn (kill → restart loops and what restarted them), security & hygiene.
  - **`query_bugreport.py`** — generic primitives, so a section with no parser (new Android release, OEM format) is still cheap to interpret: `sections` (stable id `name#occurrence` — a service dumped in several priority blocks gets `#1`, `#2`… in file order — plus service, size, parse status; every other command takes that id), `locate --grep RE` (hit counts per section, no lines), `sample SECTION` (first lines, plus a format sniff — key=value, table, indented tree, CSV — and the shape of its repeated records), `show SECTION --grep RE --context N --limit N`, `timeline --since HH:MM --window 5m` (event log + system log + ANR/kill markers merged). All output capped; full text goes to `--output FILE`.
  - **`validate_bugreport.py`** — is the input a bugreport, which format version, Android version, OEM, encoding fixed, which detector inputs parsed and which fell back. A falling-back detector names the `query` command to use instead, so drift shows up as a route, not a silent gap.
  - **`create_bugreport.py --redact`** — writes a scrubbed copy for sharing (emails, IMEI/MEID by Luhn, IMSI and ICCID by prefix + length, phone numbers, MACs, SSIDs, account names, coordinates); the same filter is on by default for all stdout.
- **Advice split** (D-6): scripts stay deterministic and only emit `advice_id` plus the facts; `references/advice.md` maps each id to a remedy template (what to do, Settings path per Android version, when to escalate to repair/support), loaded only when advice is needed; the session phrases it for the user's situation. `--advice` adds the one-line canned remedy to each finding for terminal use.
- **Comparison** (D-7): no analysis of its own. `analyze --json` has a versioned, stable schema, so "before vs after" means running it on two reports; `compare_bugreport.py` is a small diff of two such JSON files (new / gone / changed findings, memory and battery ranking deltas), last in the plan and droppable.
- **Ideas borrowed from Perfetto, no dependency**: the section/service two-level model, the logcat-local vs UTC offset taken from the alarm dump's `nowRTC`/`nowELAPSED`, scanning `FS/` for embedded traces and logs.
- **Output discipline** from `har` and skill-workshop: compact JSON on stdout ≤ 4096 bytes by default (when capped, the payload stays valid JSON: `{"truncated": true, "omitted": N, …}` envelope, asserted by a test that parses every capped output), progress on stderr, `--output` for full fidelity, `--help` everywhere.
- **Scope**: New skill folder, section entry, tests + synthetic fixtures, changelog.
- **Effort**: Large (4 stacked PRs: P1 library + index + `query` + `validate` + fixture generator; P2 memory/ANR/churn/thermal detectors + checkup; P3 crashes/battery/reboots/network/Bluetooth/storage/battery-health; P4 security & hygiene + advice reference + redaction + `compare`).
- **Tradeoffs**: The detectors are the value and also the maintenance cost: formats shift between Android releases and OEMs, so every detector must fail soft ("section not parsed") and be fixture-tested. Byte-range index over SQLite: one JSON file, no conversion step; SQLite only earns its keep for repeated time-window logcat queries, which `timeline` can add later behind the same interface.
- **Compatibility**: Additive; no dependency on Perfetto or protobuf libraries.

<!-- -->

> **✎ Notes** · `SPEC › Option B: Indexed, detector-driven toolkit, stdlib only (Recommended)`
> _(your notes here — replace this line)_

### Option C: Build on Perfetto trace_processor as the substrate (rejected by the maintainer — ideas only)

- **Description**: Load the zip into Perfetto's SQL tables (`android_logs`, `android_dumpstate`, `battery_stats`) and write the detectors as SQL queries over them.
- **Scope**: New skill + a pip dependency (`perfetto`) that downloads a native binary.
- **Effort**: Medium
- **Tradeoffs**: Free logcat parsing and SQL joins, and alignment with Google's own trace skill. But dumpstate is stored as raw lines (detectors still parse text, now inside SQL), batterystats import is partial (~30–40 % of events per Perfetto issue #934), load time and RAM are far above a byte-range index, and the binary download fails in network-restricted environments (cloud sessions, CI behind proxies).
- **Compatibility**: Additive, but adds a heavy runtime dependency to a stdlib-only bundle.

<!-- -->

> **✎ Notes** · `SPEC › Option C: Build on Perfetto trace_processor as the substrate (rejected by the maintainer — ideas only)`
> _(your notes here — replace this line)_

### Option D: MCP server instead of a skill

- **Description**: Expose the same analyses as MCP tools.
- **Tradeoffs**: MCP earns its place for remote systems, auth, live state or non-Claude clients. For a local file it adds a server process and up-front tool-definition tokens while doing exactly what `uv run python script.py` already does; the skill's resident cost is one listing line, and script output is already bounded before it reaches context. Google's Perfetto skill made the same call (bundled CLI, not MCP). A thin MCP wrapper over Option B's CLI stays possible later if non-Claude agents need it; live device capture over adb is already covered by existing MCP servers.
- **Effort / Compatibility**: Medium; separate install path outside the marketplace model.

<!-- -->

> **✎ Notes** · `SPEC › Option D: MCP server instead of a skill`
> _(your notes here — replace this line)_

### Comparison

| | Option A | Option B | Option C | Option D |
|---|---|---|---|---|
| Effort | Small | Large | Medium | Medium |
| Risk | Low | Medium (format drift, mitigated by fail-soft + fixtures) | Medium–High (binary download, partial import) | Medium |
| Finds problems by itself | No | Yes | Yes | Same as B |
| Dependencies | stdlib | stdlib | `perfetto` + native binary | MCP runtime |
| Follow-up query cost | ~1 s re-scan | ≤ 1 s slice | SQL, after slow load | as B + tool tokens |
| Fits arsenal conventions | Partly | Yes (mirrors `har`) | Partly | No |

<!-- -->

> **✎ Notes** · `SPEC › Comparison`
> _(your notes here — replace this line)_

## §4 Recommendation

**Recommended option**: **B** — it is the only option that meets "find problems,
not just expose data" without a native dependency, and it reuses the decisions
`har` already proved (index sidecar, bounded output, redaction by default,
`--json` escape hatch). A's scope (a sections reference plus grep-level access) is covered by B's P1 (`query` + `validate`); C stays
an optional backend idea for logcat-heavy questions; D is rejected for v1.

**Immediate next action**: after approval, run `design` to turn this into
contracts and a stacked PR plan; first PR = P1 (library, index, `query`, `validate`,
synthetic-fixture generator), so every later detector has a fast, tested
substrate and the fallback route exists from day one.

**Gates check**: objective (§ 1), scope (§ 2.3), impacted systems (§ 2.3),
compatibility (additive, minor bump), risk (format drift, PII — § 2.1/§ 2.3),
validation (success criteria), release readiness (changelog entry + `make
context-budget` row).

**Open questions**: none — all resolved in the decisions log.

**Decisions log**:
- D-1 — Lives inside `claude-arsenal` (not a separate repo), as a tool skill like `har` (maintainer, 2026-11-04).
- D-2 — Skill + stdlib scripts, not an MCP server (this spec, Option D rationale; open to a thin MCP wrapper later).
- D-3 — Option B approved; Perfetto not used, ideas may be borrowed (maintainer, r2 notes).
- D-4 — Section `android`, default-off, skill folder under `plugins/core/skills/` like every vendored skill (maintainer: "an Android section or inside diagnostics"; `android` chosen as the narrower, self-describing name).
- D-5 — Full checkup with remedies, security & hygiene in scope, all families F1–F11 in v1 (maintainer, r2 notes).
- D-6 — Advice: deterministic `advice_id` from scripts, remedy text in a reference the session interprets (maintainer: "a part of it could be from the skill for the LLM to interpret").
- D-7 — No comparison analysis; stable JSON plus a small `compare_bugreport.py` diff, last and droppable (maintainer, r2 notes).
- D-8 — Built and validated under skill-workshop rules (maintainer, r2 notes).
- D-9 — Real reports (public corpus and the maintainer's own) are study material only: they inform which data to read and keep, how to preserve privacy, and which concrete cases detectors must catch. They are never committed, not even as excerpts. CI runs on synthetic fixtures built from what the real reports taught (maintainer, 2026-11-04).
- D-10 — One version bump for the whole stack: P4 → P3 → P2 → P1 merge top-down, then P1 → `main` with the single minor bump (maintainer, 2026-11-04). The four extra domain flags of § 5.7 are accepted (maintainer, 2026-11-04).

<!-- -->

> **✎ Notes** · `SPEC §4`
> _(your notes here — replace this line)_

## §5 Contracts

Sections 5–6 are appended by `design` (2026-11-04). They settle the items the
spec's reviewers left for design — the index/cache, zip input, the clock behind
`timeline --since`, the output schema, the CLI surface, detectors, advice,
redaction and the fixture generator — so the plan
(`0005-bugreport-analysis-toolkit-plan.md`) can gate each task against a
written contract, not against intent. Nothing here changes §§ 1–4.

<!-- -->

> **✎ Notes** · `SPEC §5`
> _(your notes here — replace this line)_

### §5.1 Module layout

```text
plugins/core/skills/bugreport/        metadata.section: android   (default OFF)
  SKILL.md
  references/
    advice.md                         advice_id -> remedy template (§ 5.9)
    sections.md                       section map, format traps, fallback recipe
    detectors.md                      the detector catalogue, one row per finding id
  scripts/
    _brlib.py                         input resolution, scanner, index/cache, slice reader,
                                      tolerant numbers, clock, output budget — no CLI
    _redact.py                        the redaction filter (§ 5.10) — no CLI
    _detectors.py                     registry, Finding, NotParsed, run loop — no CLI
    _det_<family>.py                  one module per family slug (§ 5.8) — no CLI
    _pbwire.py                        stdlib protobuf wire-format reader (tombstone .pb)
    _console.py                       ▶ ✓ ✗ ⚠ ℹ on stderr (skill-workshop copy, duplication header)
    analyze_bugreport.py  query_bugreport.py  validate_bugreport.py
    create_bugreport.py   compare_bugreport.py
  evals/
plugins/core/tests/
  bugreport_test.sh                   CLI layer, bare python3, `--stage N`
  bugreport/test_*.py                 pytest unit layer
  bugreport/make_fixture.py           the synthetic fixture generator (§ 5.11)
  bugreport/seeds/                    committed seed templates, ≤ 200 KB total
  bugreport/benchmark.py              full-size timing run (SC index_build_s)
```

No module imports from `har`: the two skills sit in different sections and must
install apart. The few shared helpers (`apply_budget`, `_console.py`) are
copied with a `DUPLICATED ACROSS SKILLS:` header, which `sync_duplicates.py`
already polices.

<!-- -->

> **✎ Notes** · `SPEC §5.1`
> _(your notes here — replace this line)_

### §5.2 Input resolution

`--input` takes a `.txt` or a `.zip`. Detection is by content (zip magic
`PK\x03\x04`), not extension.

**Text input.** Read in binary mode throughout — never text mode, which is what
shifts line numbers at bare `\r` bytes. Encoding is sniffed from the first
4 KiB: a UTF-16 BOM (or ≥ 30 % NUL bytes in even/odd positions without one) means
UTF-16 and the file is **transcoded once** into the cache as UTF-8 (§ 5.3);
otherwise the input is used in place via `mmap`. Invalid UTF-8 and NUL bytes
inside logcat are decoded `errors="replace"` per slice, never fatal.

**Zip input — finding the main entry**, in order:

1. `main_entry.txt` exists and names a member that exists → that member.
2. Otherwise, every `.txt` member outside `FS/` and `proto/`, other than
   `version.txt`, `main_entry.txt`, `dumpstate_board.txt` and `dumpstate_log.txt`,
   whose first 64 KiB holds a dumpstate header (`^== dumpstate: \d{4}-\d{2}-\d{2}`
   or `^Bugreport format version:`) → the **largest** of them. This covers
   `dumpstate-<date>.txt`, `dumpstate.txt` and arbitrary names (`example.txt`).
3. None → exit 1, listing up to five largest text members, so the session can
   point `--input` at one by hand.

**Streaming vs extracting.** The main entry is **extracted once** into the cache,
streamed in 1 MiB chunks through the same scanner that builds the index (one
decompression pass; never held whole in memory). Deflate has no random access,
so a streaming-only design would re-decompress up to a section's offset on every
`show` — ~0.5 s per 100 MB, which breaks `query_s <= 1` for sections near the
end of a 156 MB entry. The cost is disk: the cache holds a copy the size of the
main entry. `FS/` members (ANR traces, tombstones, `.pb`, persistent logd,
recovery logs) are **not** extracted; they are read on demand by member name,
streamed, since each is small or read once.

**Build-time criterion covering the zip.** Alongside the spec's text criterion
(`index_build_s <= 3`, `peak_rss_mb <= 300` for 160 MB text), the zip path is
gated as `index_build_zip_s <= 6` and `peak_rss_mb <= 300` for a 234 MB zip whose
main entry is 156 MB (extract + scan, cold cache), and `index_reuse_s <= 0.5` for
any later command on the same input (warm cache). Both are measured on the CI
runner against a generated report of that shape (§ 5.11, scale mode).

<!-- -->

> **✎ Notes** · `SPEC §5.2`
> _(your notes here — replace this line)_

### §5.3 Index and cache

**Location.** Unlike `har`, which writes `<file>.har.index.jsonl` beside its
input, this skill never writes beside the input: bugreports often sit on
read-only media or in a download folder, a zip has nowhere sensible to put a
sidecar, and the extracted main entry is a full-PII copy that must not land in a
working tree where it can be committed. The default root is the standard
per-user cache directory:

| Platform | Default root |
|---|---|
| Linux / BSD | `$XDG_CACHE_HOME/claude-arsenal/bugreport/`, else `~/.cache/claude-arsenal/bugreport/` |
| macOS | `~/Library/Caches/claude-arsenal/bugreport/` |
| Windows | `%LOCALAPPDATA%\claude-arsenal\bugreport\Cache\` |

`--output-dir DIR` **always** overrides the root (the cache lands at
`DIR/<key>/`). Directories are created `0700`, files `0600`. Each input gets
`<root>/<key>/` holding `index.json` and, for zip or UTF-16 input, `main.txt`.
Builds write to a temp file in the same directory and `os.replace` it, so an
interrupted build leaves the previous index intact. On each build the root is
pruned to the five most recently used keys (a module constant, stated as a
starting value); the cache is otherwise disposable and documented as such.

**Key.** `key = sha256(f"{size}:{mtime_ns}:" + sha256(first 1 MiB ‖ last 1 MiB))[:16]`
— about 3 ms on a 160 MB file, against ~1 s for a full hash. **Stale-index
trade-off:** an in-place edit that keeps size and mtime and touches only the
middle of the file is not detected by the key. Bugreports are not edited in
place, so the residual case is deliberate tampering; it is covered cheaply by a
**delimiter check on every slice read** — the bytes at a section's `start` must
be that section's opening line (`------ TITLE` or `DUMP OF SERVICE …`). A
mismatch rebuilds the index once, then fails with exit 1 if it recurs.
`--force` rebuilds unconditionally.

**Contents — offsets and metadata only, never section text** (asserted by a test
that greps every `index.json` for each fixture's canary strings):

```json
{
  "schema": "bugreport.index/1",
  "key": {"size": 163577856, "mtime_ns": 1762263725000000000, "head_tail_sha256": "9c1f…"},
  "input": {"kind": "zip", "main_entry": "bugreport-<build>-2026-11-03-14-22-05.txt",
            "reading_target": "main.txt", "encoding": "utf-8", "transcoded": false,
            "cr_bytes": 10757, "nul_bytes": 0},
  "header": {"format_version": "2.0", "android_release": "16", "sdk": 36,
             "oem": "Google", "model": "Pixel 8", "build_id": "BP2A.250605.031",
             "captured_local": "2026-11-03 14:22:05", "uptime_s": 312455},
  "clock": {"utc_offset_s": 3600, "source": "alarm", "boot_rtc_ms": 1761951270000},
  "sections": [
    {"id": "meminfo#1", "name": "meminfo", "kind": "service", "block": "HIGH",
     "start": 81234567, "end": 81519000, "size": 284433, "duration_s": 0.41,
     "timed_out": false}
  ],
  "fs": [{"path": "FS/data/anr/anr_2026-11-03-14-18-02-117", "size": 401233}]
}
```

No serial number, account, IMEI or path inside the device user's data is
stored; `header` fields are the ones `validate_bugreport.py` reports.

<!-- -->

> **✎ Notes** · `SPEC §5.3`
> _(your notes here — replace this line)_

### §5.4 Section ids and selectors

- A section's **name** is the title between `------ ` and ` (` for top-level
  sections (`SYSTEM LOG`, `KERNEL LOG (dmesg)` keeps its own parentheses —
  the scanner splits on the last ` (` before ` ------`), and the service name
  for `DUMP OF SERVICE` blocks (`meminfo`, `batterystats`).
- **id = `name#occurrence`**, occurrence 1-based in file order. Every id carries
  its occurrence (`meminfo#1`), so ids are stable across runs on the same file.
- `--section` accepts an exact id; a bare name when it has exactly one
  occurrence; and a case-insensitive match when that is unique. Anything
  ambiguous is exit 2 with the candidate ids on stderr — never a silent pick.
- Ids are not stable **across** reports (a service can gain a priority block
  between releases), which is why `compare_bugreport.py` never keys on them
  (§ 5.7).

<!-- -->

> **✎ Notes** · `SPEC §5.4`
> _(your notes here — replace this line)_

### §5.5 Clock and timeline --since

**Clock domain: device local wall-clock time.** Every timestamp the scripts emit
is normalised to `YYYY-MM-DD HH:MM:SS.mmm` in device local time, because that is
what logcat prints and what the user remembers ("it froze at about 14:15").

| Source | Native form | Conversion to local |
|---|---|---|
| logcat (`SYSTEM`, `EVENT`, `RADIO`, `LAST LOGCAT`, `FS/…/logd`) | `MM-DD HH:MM:SS.mmm`, local, no year | Year from `captured_local`; a month later than the capture month belongs to the previous year (December logs in a January report) |
| ANR trace files | `----- pid N at YYYY-MM-DD HH:MM:SS -----`, local | none |
| kernel log | `[  12345.678901]` seconds since boot | `boot_rtc_ms + s×1000` → UTC → `+ utc_offset_s` |
| batterystats history | offsets from `RESET:TIME:` (UTC ms) | → UTC → `+ utc_offset_s` |

**Offset derivation**, in order (recorded in `index.clock.source`):

1. `alarm` — `dumpsys alarm` prints `nowRTC=<UTC ms>` and `nowELAPSED=<ms>`
   together. `boot_rtc_ms = nowRTC − nowELAPSED`; `utc_offset_s` = the
   difference between the dumpstate header's local timestamp and the UTC time
   of the same instant (header time ≈ alarm dump time within the report's
   capture window), rounded to the nearest 15 minutes.
2. `timezone` — `persist.sys.timezone` from the properties section, resolved
   with stdlib `zoneinfo` at `captured_local`. Where `zoneinfo` has no data
   (some Windows Pythons lack `tzdata`), the step is skipped.
3. `none` — kernel and batterystats events keep elapsed time only and carry
   `"clock": "elapsed"` in their row; `timeline` says so on stderr. Nothing is
   guessed.

**`--since` grammar.** `HH:MM[:SS]`, `MM-DD HH:MM[:SS]`, `YYYY-MM-DD HH:MM[:SS]`,
or relative `-30m` / `-2h` (back from `captured_local`). `--window` is a duration
`90s` / `5m` / `1h`, default `5m`; the window is `[since, since + window)`.

**Date selection on multi-day reports.** A time with no date resolves against the
span the report's logs actually cover (earliest to latest normalised timestamp
across the merged sources). If that clock time falls on exactly one date in the
span, that date is used. If it falls on **more than one** (persistent logd, long
`LAST LOGCAT`), the command exits 2 and lists the candidates:

```text
✗ --since 14:15 is ambiguous: the logs cover 2026-11-01 09:02 … 2026-11-03 14:22
  candidates: 2026-11-01 14:15, 2026-11-02 14:15, 2026-11-03 14:15
  pass a date, e.g. --since "2026-11-03 14:15"
```

A `--since` time outside every source's span is exit 1 ("time outside report span"), with the span
printed. A time inside the span whose window simply holds no matching event is exit 0 with an empty `events` list. A local time inside a DST fold resolves to its first occurrence and the
output says so.

<!-- -->

> **✎ Notes** · `SPEC §5.5`
> _(your notes here — replace this line)_

### §5.6 Output, JSON schema and exit codes

**Envelope.** Every command writes **one JSON document** to stdout; progress
and errors go to stderr via `_console.py`. `--json` is accepted on every script
for canon parity and silences stderr progress. Default output is capped at
**4096 bytes** (2048 for `query … sample` and `locate`, per the fallback
criterion); when the cap bites, whole rows are dropped from the end of the
ranked list — never bytes — and the document stays valid JSON:

```json
{"schema": "bugreport.query.sections/1", "truncated": true, "shown": 61, "omitted": 781,
 "total": 842, "full": "rerun with --limit 0 or --output FILE", "rows": [ … ]}
```

`truncated` is always present (`false` when nothing was dropped), so callers
branch on one key. `--limit N` caps rows; `--limit 0` removes both the row and
the byte cap; `--output FILE` writes the full, uncapped document to a file and
prints only a one-line summary envelope to stdout. Redaction (§ 5.10) applies to
every one of those paths unless `--no-redact` is given.

**`analyze_bugreport.py` schema** (`bugreport.analyze/1`; a major bump on any
removed or renamed field, a minor `1.x` never needed since additions are
backward compatible and the string carries only the major):

```json
{
  "schema": "bugreport.analyze/1",
  "truncated": false,
  "report": {"android_release": "16", "sdk": 36, "oem": "Google", "model": "Pixel 8",
             "build_id": "BP2A.250605.031", "captured_local": "2026-11-03 14:22:05",
             "uptime_s": 312455, "clock_source": "alarm"},
  "summary": {"findings": 7, "by_severity": {"critical": 1, "high": 2, "medium": 3, "low": 1},
              "detectors_run": 58, "not_parsed": 2},
  "findings": [
    {
      "id": "memory.swap_thrashing",
      "family": "F6",
      "severity": "critical",
      "score": 0.97,
      "claim": "Memory thrashing: swap 97% full, kswapd at 58% CPU, I/O pressure some avg10=89",
      "facts": {"swap_used_pct": 97.1, "kswapd_cpu_pct": 58.0, "psi_io_some_avg10": 89.0},
      "subjects": [
        {"package": "com.example.app", "uid": 10234, "role": "victim"},
        {"package": "com.example.heavy", "uid": 10211, "role": "holder", "pss_mb": 2048}
      ],
      "evidence": [
        {"section": "meminfo#1", "offset": 81240112},
        {"path": "FS/data/anr/anr_2026-11-03-14-18-02-117"}
      ],
      "advice_id": "memory.free-ram",
      "detector": "memory.pressure"
    }
  ],
  "not_parsed": [
    {"detector": "network.wifi_drops", "family": "F7", "section": "wifi#1",
     "reason": "unrecognised layout", "route": "query_bugreport.py sample --input R --section wifi#1"}
  ]
}
```

Finding fields: `id` (stable, `<family-slug>.<problem>`), `family` (`F1`–`F11`),
`severity` (`critical` · `high` · `medium` · `low` · `info`), `score` (0–1,
orders findings within a severity), `claim` (one line, ≤ 160 chars, redacted),
`facts` (numbers and short strings — the measured values the claim rests on),
`subjects` (packages/processes with a `role` of `cause` · `victim` · `holder`),
`evidence` (≥ 1 pointer: `section` + byte `offset`, or an `FS/` `path`),
`advice_id`, `detector`. `--advice` adds `advice` (the canned one-line remedy).
Ranking: severity, then score, then id. Family views (`--family memory` etc.)
add a `views.<slug>` table capped the same way. `report` never carries the
serial number or any account.

**Exit codes** (all five scripts):

| Code | Meaning |
|---|---|
| 0 | Ran and produced its document — including "no findings" and "no matches" |
| 1 | The data is unusable for the request: not a bugreport, no main entry in the zip, a `--since` time outside the report span, schema mismatch in `compare` |
| 2 | Usage or internal error: bad flag, ambiguous `--section` or `--since`, unwritable `--output`, unexpected exception |

<!-- -->

> **✎ Notes** · `SPEC §5.6`
> _(your notes here — replace this line)_

### §5.7 CLI surface

Canonical flags from skill-workshop (`--input`, `--output`, `--output-dir`,
`--json`, `--limit`, `--since`, `--severity`, `--force`, `--against`) are used
wherever the concept applies. Domain flags, registered in `validate.py`'s
`CANONICAL_ARGS` with a comment, rather than left to warn: `--family`, `--advice`,
`--no-redact`, `--window`, plus four this contract adds because §§ 3–4 already use
them — `--section`, `--grep`, `--context`, `--redact`.

| Script | Synopsis | Default output |
|---|---|---|
| `analyze_bugreport.py` | `--input R [--family LIST] [--severity MIN] [--advice] [--limit N] [--output FILE] [--output-dir DIR] [--force] [--no-redact] [--json]` | `bugreport.analyze/1`, ≤ 4096 B. `--family` takes slugs or `F`-numbers, comma-separated; default all |
| `query_bugreport.py sections` | `--input R [--grep RE] [--limit N] [--output FILE]` | id, kind, block, size, parse status per section |
| `query_bugreport.py locate` | `--input R --grep RE [--limit N]` | hit count + first offset per section, no lines; ≤ 2048 B |
| `query_bugreport.py sample` | `--input R --section ID [--limit N]` | first lines (default 20, each ≤ 200 chars), format sniff (`kv` · `table` · `tree` · `csv` · `log` · `unknown`) and the repeated-record shape; ≤ 2048 B |
| `query_bugreport.py show` | `--input R --section ID [--grep RE] [--context N] [--limit N] [--output FILE]` | matching lines with byte offsets |
| `query_bugreport.py summary` | `--input R [--json]` | ≤ 2048 B: device (manufacturer, model, codename), Android release/SDK/build/security patch, capture time + timezone, uptime + last boot reason, **data coverage per source** (system/event/kernel log first–last timestamps, batterystats since-charge window, procstats windows, ANR and tombstone date ranges), file stats (input and text size, section count, five largest sections, ANR/tombstone/proto counts), battery snapshot (level, status, health, temperature), storage free, installed / user app counts. A field the report lacks reads `unknown`, never omitted. Redacted like all stdout. |
| `query_bugreport.py timeline` | `--input R --since T [--window D] [--grep RE] [--limit N]` | merged events (§ 5.5): `t`, `src`, `tag`, `level`, excerpt; default level ≥ W plus every ANR/kill/crash/boot/thermal marker |
| `validate_bugreport.py` | `--input R [--json]` | is-bugreport, input kind, main entry, format/Android/SDK/OEM, encoding facts, section count, each detector input `parsed` · `fallback` (+ route) · `absent` |
| `create_bugreport.py` | `--redact --input R --output FILE [--force]` | Writes a scrubbed copy; stdout = counts per redaction kind. `--redact` is required (the only v1 mode, named so later modes do not change its meaning). Text input → text; zip input with a `.zip` output → main entry and text `FS/` members redacted, binary members (`.pb`, `proto/`, `visible_windows.zip`) **dropped** and listed, because binary cannot be scrubbed reliably. Refuses an output that resolves to the input or exists without `--force` |
| `compare_bugreport.py` | `--input A.json --against B.json [--limit N] [--output FILE]` | `new` / `gone` / `changed` findings (paired on `id` + primary subject package — never on section ids or redacted tokens, which differ across reports and runs), memory and battery ranking deltas. Exit 1 when the two schema majors differ |

Every script: `main()` + `__main__` guard, no top-level work, `--help`.

<!-- -->

> **✎ Notes** · `SPEC §5.7`
> _(your notes here — replace this line)_

### §5.8 Detector contract

```python
@detector(
    id="memory.pressure",                  # unique; prefix = family slug
    family="F6",
    inputs=("meminfo", "procstats", "SYSTEM LOG", "PSI"),  # section names it reads
    findings={"memory.swap_thrashing": "memory.free-ram",  # finding id -> advice_id
              "memory.background_hog": "memory.restrict-app"},
)
def detect(ctx: Context) -> Iterable[Finding]: ...
```

- **Family slugs** (for `--family` and id prefixes): F1 `battery`, F2 `thermal`,
  F3 `reboots`, F4 `anr`, F5 `crashes`, F6 `memory` (also `churn`, a view whose
  detectors are F6), F7 `network`, F8 `peripherals` (Bluetooth, GPS, sensors),
  F9 `storage`, F10 `security`, F11 `battery-health`.
- **Inputs** are read only through `ctx.section(name) -> Slice | None` and
  `ctx.fs(glob) -> Iterator[Member]`; a detector never opens the file itself, so
  every read is a bounded slice.
- **Fail soft.** A missing input returns no findings and records `absent`; an
  input whose layout the detector does not recognise raises
  `NotParsed(section, reason)`; any other exception is caught by the run loop.
  Both land in `not_parsed` with a `route` naming the `query` command to use
  instead. The run never dies on one detector. Unexpected exceptions carry
  `reason: "error: <ExceptionType>"`, and the fixture suite asserts that count is
  zero — that is how "zero unhandled exceptions" stays testable while the run
  stays fail-soft.
- **Deterministic.** Same input → same findings, same order, byte-identical
  JSON (apart from redaction tokens, which are salted per run).
- **Tested both ways.** Each detector has one fixture scenario that fires it
  and one that does not (spec success criterion, family coverage).
- The registry is the single source of finding ids and their `advice_id`s;
  `references/detectors.md` is generated from it.

<!-- -->

> **✎ Notes** · `SPEC §5.8`
> _(your notes here — replace this line)_

### §5.9 Advice reference

`references/advice.md` holds one entry per `advice_id`, headed `### <advice_id>`.
Each entry: a first line that is the canned one-sentence remedy (`--advice`
reads exactly that line, so there is one source), then what to do, the Settings
path per Android version where it differs (≤ 3 variants), and when to escalate
to repair/support. Several finding ids may share one `advice_id`. A test diffs
the registry's `advice_id` set against the headings: a missing entry or an
orphan heading fails the build. If the file passes the 10K-token reference cap,
it splits by family into `advice-<slug>.md` behind `references/_index.md`, with
the same test reading all of them.

<!-- -->

> **✎ Notes** · `SPEC §5.9`
> _(your notes here — replace this line)_

### §5.10 Redaction

One filter (`_redact.py`), on by default for every string a script emits —
claims, excerpts, `show`/`sample`/`timeline` lines, `create_bugreport.py`
output. Numeric `facts` are computed before redaction and are not identifiers.
Each match becomes `<kind:xxxxxxxx>`, eight hex characters of an HMAC-SHA256 of
the value under a **per-run salt that is never stored** — the `har` rule: equal
values stay equal within one output, nothing links across two.

| Kind | Rule |
|---|---|
| `email` | `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}` |
| `imei` | 15 digits passing Luhn, bare or keyed (`imei`, `mImei`, `deviceId`); MEID: 14 hex digits when keyed (`meid`) |
| `imsi` | 14–15 digits with an MCC prefix (2xx–7xx) when keyed (`imsi`, `subscriberId`) |
| `iccid` | 19–20 digits starting `89`, Luhn-valid, bare or keyed (`iccid`, `mIccId`) |
| `phone` | E.164 `\+[1-9]\d{7,14}`; keyed national forms (`mLine1Number`, `phoneNumber`, `number=`) |
| `mac` | `([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}`, except all-zero, broadcast and Android's masked `02:00:00:00:00:00` |
| `ssid` | quoted or keyed values in Wi-Fi contexts (`SSID: "…"`, `SSID=…`, `ssid=…`, `WifiConfiguration … SSID`) |
| `account` | `Account {name=…, type=…}` and `name=…` in `account` sections — name redacted, type kept |
| `coord` | latitude/longitude pairs with ≥ 3 decimals in `location` contexts (`Location[gps 41.381,2.173 …]`, `lat=…, lon=…`) |
| `serial` | `ro.serialno`, `ro.boot.serialno` values (added: same class of identifier) |

**Known-value harvest.** Before output, the filter reads a fixed short list of
sections (`iphonesubinfo`, `telephony.registry`, `account`, the properties
section) for this device's own IMEI, IMSI, ICCID, line number, serial and
account names, and adds them as exact-match terms — catching an unkeyed
national phone number or IMSI the patterns alone would miss. The harvested set
lives in memory only; it is never written to the cache or any output.

Bare Luhn-valid 15-digit runs may over-redact an unrelated number in an excerpt;
that is accepted — an over-redacted excerpt costs a `--no-redact` rerun, an
under-redacted one leaks.

<!-- -->

> **✎ Notes** · `SPEC §5.10`
> _(your notes here — replace this line)_

### §5.11 Synthetic fixture generator

D-9 is the rule: **no real report, and no excerpt of one, is ever committed.**

- `plugins/core/tests/bugreport/make_fixture.py`, stdlib only:
  `build(layout, scenarios, *, seed, target_mb=None, container="txt") -> Path`,
  also a CLI for the benchmark. Output is **byte-identical for the same
  arguments** (asserted by hashing two builds).
- Committed **seeds ≤ 200 KB total** (`seeds/*.tmpl`): synthetic section bodies
  written from what the corpus taught (field names, layouts, number formats),
  never copied text.
- **Layouts** reproduced from spec § 2.1.1: `pre-p` (no priority blocks, no
  format-version line), `modern` (9–17, CRITICAL/HIGH, header ~43 lines before
  the format line), `samsung` (+ `DUMPSYS NORMAL`, `AP RESET INFO EXTEND`,
  `SEC_MEDIA`, `End of OLOG`), `xiaomi` (`POWERUP_REASON`, `qsee_log`,
  `PERFLOCK HISTORY`), `oneplus` (`OMMSERVICE`), `huawei` (kernel live-patch),
  `android9` (`QTAGUID`). **Containers**: `txt`; `zip` with `main_entry.txt` and
  `FS/`; `zip` without `main_entry.txt` with the main file named
  `dumpstate-<date>.txt`, `dumpstate.txt` or `example.txt`; text-only zip.
- **Traps** as switches on any layout: bare `\r`, UTF-16LE with BOM, NUL and
  invalid UTF-8 in logcat, locale decimal commas (`1,9GB`, `0,00`), unsampled
  PSS triples, a timed-out section, a service dumped in two priority blocks.
- **Scenarios** are composable signal blocks, one per detector branch (fire and
  no-fire), including the provenance scenario `thrashing` (swap ≥ 95 %,
  `kswapd` CPU, PSI io, two input-dispatch ANRs) and `battery-exhaustion`
  (`shutdown,battery`, one app foreground with the screen off).
- **PII canaries** from reserved ranges only (`example.com` addresses,
  `+1-555-01xx` numbers, RFC 7042 documentation MACs `00:00:5e:00:53:xx`,
  test-TAC IMEIs, invented SSIDs), one of each § 5.10 kind, so
  `pii_in_default_output == 0` has something to find.
- **Scale mode** (`target_mb`) pads with synthetic sections in the provenance
  size distribution (Wi-Fi HAL, checkin batterystats, `activity`, `package`…)
  for the benchmark; never committed.

<!-- -->

> **✎ Notes** · `SPEC §5.11`
> _(your notes here — replace this line)_

### §5.12 Section registration and packaging

- `metadata.section: android` in the SKILL.md frontmatter; a blurb added to
  `SECTION_BLURBS` in `scripts/sync_sections.py`; `make sync-sections`
  regenerates `assets/sections.json` (CI's `sync-sections-check` fails on drift).
  No entry in `init.py`'s `_SECTION_DEFAULTS` is needed for default-off — an
  unlisted shipped section is off — but `--profile all` must be checked to
  include it, as `extract` is.
- Release: one minor bump of `.bundle-version`, a `CHANGELOG.md` entry, and
  `make sync-version`, in the last PR of the stack (see the plan for how that
  meets CI's `version bump` job).

<!-- -->

> **✎ Notes** · `SPEC §5.12`
> _(your notes here — replace this line)_

### Inter-component contracts

| Caller | Callee | Contract | Failure handling |
|---|---|---|---|
| every script | `_brlib.open_report` | returns a `Report` (reading target, index, clock) or raises `NotABugreport` | exit 1 with the reason |
| `analyze` | detector registry | `detect(ctx) -> Iterable[Finding]` | `NotParsed`/exception → `not_parsed` row, run continues |
| every script | `_redact.filter(text, salt, harvested)` | pure function, no I/O | none — cannot fail open: an exception inside it is exit 2, never unredacted output |
| `compare` | two `bugreport.analyze/N` documents | same major `N` | exit 1 naming both versions |
| `--advice` | `references/advice.md` | first line under `### <advice_id>` | missing entry → finding keeps `advice_id`, `advice` omitted, ⚠ on stderr (the coverage test keeps this from shipping) |

<!-- -->

> **✎ Notes** · `SPEC › Inter-component contracts`
> _(your notes here — replace this line)_

### Database migrations

None. The only persistent state is the per-user cache (§ 5.3), versioned by
`index.schema`; an index with an unknown schema is rebuilt, never migrated.

<!-- -->

> **✎ Notes** · `SPEC › Database migrations`
> _(your notes here — replace this line)_

## §6 Risks & Validation

| Risk | Likelihood | Impact | Mitigation | Validation |
|------|-----------|--------|------------|------------|
| Format drift: a new Android release or OEM changes a section layout and a detector misreads it | High | Medium | Fail-soft `NotParsed` with a `query` route; `validate_bugreport.py` reports per-input parse status; delimiter scan is pattern-based, not positional | unit: every layout fixture parses with `error:` count 0; manual: corpus re-run before release (D-9) |
| A detector reports a confident wrong diagnosis (e.g. blames the ANR victim, not the memory holder) | Medium | High | `subjects[].role` separates victim from cause/holder; every finding carries evidence pointers; fire/no-fire fixtures per detector | unit: provenance scenario ranks `memory.swap_thrashing` first with the ANR'd processes as `victim`; manual: real-report check before release |
| PII leaks into stdout, the cache, a shared redacted copy, or a committed fixture | Medium | High | Redaction on by default, known-value harvest, cache `0700`/`0600` outside the working tree, index holds no text, fixtures generated from reserved-range canaries; `create_bugreport` drops binary members | security: `pii_in_default_output == 0` over every command × fixture; `index.json` canary grep; `generic_examples_test.sh`-style check that seeds hold no real identifiers |
| Stale index after an in-place edit that keeps size and mtime | Low | Medium | Head/tail hash in the key; delimiter check on every slice read with one automatic rebuild; `--force` | unit: mutate a middle section keeping size + mtime → read rebuilds, result correct |
| Zip extraction fills the disk or leaves full-PII copies behind | Medium | Medium | Cache pruned to five keys; documented as disposable; `--output-dir` to place it elsewhere | unit: prune keeps exactly five; manual: cache size equals main entry + index |
| Wrong clock offset puts `timeline` events in the wrong minute | Medium | Medium | Ordered derivation (alarm → timezone → none), source recorded; elapsed-only rows marked instead of guessed; ambiguous `--since` is an error | unit: fixture with a known offset → `timeline_offset_error_s == 0`; multi-day fixture → exit 2 with candidates |
| Performance regresses past the build/query criteria as detectors are added | Medium | Low | Detectors read slices only; the index is built once; benchmark at full size on CI dispatch, 1/10 scale on every push | perf: `index_build_s`, `index_build_zip_s`, `query_s` gates |
| Hand-rolled protobuf reader misdecodes a newer tombstone schema | Medium | Low | Wire-format only (varint, length-delimited), unknown fields skipped; falls back to the text tombstone beside the `.pb` | unit: synthetic `.pb` round-trip; unknown-field fixture still yields signal + abort message |
| Resident listing cost grows past the criterion | Low | Low | One-line description; section default-off | perf: `make context-budget` row with `android` ≤ 130 tokens, 0 without |
| Advice goes stale or gives wrong Settings paths for an OEM | Medium | Low | Advice is a template the session adapts; per-version variants capped at three; escalation path in every entry | unit: advice coverage diff; manual: review of `advice.md` in P4 |

**Rollback.** Everything is additive in a default-off section: rolling back is
reverting the stack (or shipping a patch that removes the skill from
`sections.json`); no consumer data or configuration is touched, and the cache
is disposable.

<!-- -->

> **✎ Notes** · `SPEC §6`
> _(your notes here — replace this line)_

