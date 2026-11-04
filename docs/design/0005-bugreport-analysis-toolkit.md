# Specification: Android bugreport analysis toolkit (`bugreport` skill)

**Date**: 2026-11-04
**Ticket / PR**: none yet (opened with this spec)
**Author**: Claude, for the maintainer
**Revision**: 2
**Status**: approved (2026-11-04, revision 2)
**Revision log**:
- r1 — first draft
- r2 — applied `notes/0005-bugreport-analysis-toolkit-notes-2026-11-04.md` (7 notes): full-checkup mode with advice, security & hygiene family, extra families (network, Bluetooth/GPS, storage/OTA, battery health), fallback primitives for unparsed sections, `android` section, Perfetto as ideas only, `compare` reduced to a JSON diff, skill-workshop conventions, public multi-OEM samples; then, from conversation: public corpus findings (§ 2.1.1) and D-9 (real reports as study material only); then review fixes from the adversarial round and CodeRabbit (selectors, redaction ids, capped-JSON envelope, index location, fixture size)

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

**Success criteria (measurable)**

- [ ] `index_build_s <= 3` for a 160 MB bugreport text on the CI runner (measured today: one `mmap` + regex pass over 156 MB finds 842 sections in 0.96 s); `peak_rss_mb <= 300`.
- [ ] `query_s <= 1` for any single-section command once the index exists (seek to byte range, parse only that slice).
- [ ] `checkup_output_bytes <= 4096` by default, enforced by truncation; every finding carries an evidence pointer (`section` + byte offset or file path) so the full text is one `show` command away.
- [ ] `commands_to_diagnosis <= 1`: `analyze_bugreport.py` (full checkup) on the provenance bugreport reports memory thrashing as the top finding, names the ANR'd processes as victims, and lists the top memory holders — judged against the manual diagnosis recorded above. In CI this runs on a synthetic fixture reproducing that report's signals (swap ≥ 95 %, `kswapd` CPU, PSI, two input ANRs); the real report is re-checked locally before release (D-9).
- [ ] Detector coverage: each problem family F1–F11 in § 2.2 has ≥ 1 detector with a fixture that fires it and one that does not (`make test` asserts both).
- [ ] Advice coverage: every finding id has an entry in `references/advice.md` (a test diffs the two id sets; missing entry = build failure).
- [ ] Android version / OEM coverage: synthetic fixtures reproduce the layouts seen in the corpus (§ 2.1.1) — pre-P (no priority blocks), 9–17 with CRITICAL/HIGH, Samsung `DUMPSYS NORMAL` + OEM sections, Xiaomi/OnePlus/Huawei sections, zips without `main_entry.txt` — and all parse in CI with zero unhandled exceptions; before each release the real corpus is re-run locally (not in CI) with the same zero-exception bar. Unknown sections degrade to "not parsed", never a crash.
- [ ] Fallback cost: for a section with no parser, `commands_to_first_fields <= 2` (`query … locate`, then `query … sample`), each `output_bytes <= 2048`.
- [ ] `validate_skill.py` (skill-workshop) reports 0 `must` findings on the skill folder.
- [ ] `pii_in_default_output == 0`: emails, IMEI/IMSI/ICCID, phone numbers, MAC addresses and SSIDs never appear in default output (asserted by a test over a seeded fixture); `--no-redact` is the explicit opt-out.
- [ ] Zero third-party runtime dependencies for the core scripts (stdlib only, `uv run python`), including tombstone `.pb` decoding.
- [ ] Resident listing cost `<= 130` tokens for installs with the skill's section enabled and `0` for installs without it (`make context-budget`).

## 2. Systems & Impact

### 2.1 What a bugreport contains (parser facts)

- **Zip layout**: `main_entry.txt` names the main text (`bugreport-<build>-<date>.txt`); `version.txt` gives the format (`2.0` since Android P); `FS/` mirrors device paths — `FS/data/anr/` (ANR traces, one file per ANR), `FS/data/tombstones/tombstone_NN` + `.pb` (native crashes; protobuf since Android 12), `FS/data/misc/logd/` (persistent logcat, when enabled), `FS/data/misc/recovery/` and `update_engine_log/` (OTA); `proto/*.proto` (binary dumps of some services, build-dependent — 12 files in the provenance report); `dumpstate_board.txt` (vendor HAL); `visible_windows.zip`.
- **Delimiters**: `------ SECTION TITLE (command) ------` for top-level sections, `DUMP OF SERVICE [CRITICAL|HIGH ]<name>:` inside the three DUMPSYS priority blocks (a service can appear more than once), `------ 0.123s was the duration of 'SECTION TITLE' ------` closers, `*** command '…' timed out` for truncated sections.
- **Where the size is** (provenance report): Wi-Fi HAL dump 16.5 MB, `CHECKIN BATTERYSTATS` 15.3 MB, `batterystats` 11.2 MB, `activity` 9.3 MB, `package` 7.4 MB, VM traces 5.9 MB, system log 5.1 MB. Logcat is not the bulk; a section index makes almost every question a slice read.
- **Traps** (each one has already cost a real session a step): bare `\r` bytes inside lines (10 757 in the provenance file — text-mode readers shift line numbers); locale-formatted numbers (`0,00`, `1,9GB`); UTF-16 text when a `.txt` was captured through PowerShell redirection; NUL/invalid UTF-8 in logcat; logcat in local time vs batterystats/kernel in UTC/elapsed (offset from the alarm dump's `nowRTC`/`nowELAPSED`, as Perfetto does, or `persist.sys.timezone`); procstats PSS triples reading `0,00` when unsampled (use RSS as fallback).

### 2.1.1 Public sample corpus (collected for r2)

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

### 2.2 Problem families the detectors target (ranked by forum demand)

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

### 2.3 Systems touched

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `plugins/core/skills/bugreport/` | Primary | New skill: SKILL.md, references, stdlib scripts, evals. `plugins/core/` is the folder every vendored skill lives in (`har` included) — **not** the always-installed tier; who installs it is decided by the section below | Yes | New code only | Med |
| Skill sections (`init.py`, `assets/sections.json`) | Dependent | New default-off section **`android`** (frontmatter `metadata.section: android`); `har` stays in `extract`. Room for future Android tools (logcat, ANR/tombstone-only inputs) | Yes (one section entry, regenerated manifest) | Listing cost only where enabled; 0 for everyone else | Low |
| `.bundle-version` + `CHANGELOG.md` | Dependent | Minor bump (new skill) | Yes | Consumer-visible release note | Low |
| `plugins/core/tests/` + fixtures | Dependent | Synthetic, PII-free fixtures; detector fire/no-fire tests | Yes | CI time; fixtures are generated at test time by the fixture generator, committed seeds stay ≤ 200 KB (the `har` skill's fixtures are 136 KB) | Low |
| `har` skill | Reference only | Source of shared conventions: output cap, index sidecar, redaction stance | No | None | Low |
| User's device data | Shared resource (read-only) | Bugreports hold accounts, IMEI, SSIDs, locations, notification text | No (never written back) | Privacy: local-only processing, redacted output | High |

### 2.4 Skill-workshop constraints the design must meet

- Authoring runs under `/skill-workshop:skill-workshop`; its validator must report 0 `must` findings.
- Frontmatter: `name: bugreport` (folder name, kebab-case), third-person `description` stating what + when with a negative trigger ("Not for live-device adb sessions or logcat-only files" — or whatever scope v1 ends with), no angle brackets, `metadata.section: android`, `metadata.type: tool`, `allowed-tools` pre-approving the script invocations.
- Body ≤ 500 lines, imperative voice, no second person; standing constraints (privacy, output cap, fallback route) front-loaded; detail in `references/` with "load when…" triggers; `references/_index.md` if the body passes 300 lines; each reference ≤ 10K tokens; no PII in references.
- Scripts: `verb_noun.py` naming, canonical flags (`--input`, `--output`, `--output-dir`, `--json`, `--limit`, `--since`), domain flags `--family`, `--advice`, `--no-redact`, `--window` registered in the validator's canon list rather than invented ad hoc, stdout = payload only, progress and errors on stderr via `_console.py`, exit codes 0/1/2, `main()` + guard, no top-level work, `--help` on every script.
- Evals: loading-verification + trigger evals in `evals/`, like `har`.

Impact summary: **Data** — read-only on the input, sidecar index in `--output-dir` (default: a per-user cache dir keyed by the input hash, so read-only inputs and zips work); **API** — new CLI surface, no existing contract changes; **Performance** — bounded by the criteria above; **User** — opt-in skill; **Operational** — fixtures must never contain a real report; **Risk of inaction** — every bugreport question keeps costing ~15 calls and re-learned traps.

## 3. Options

### Option A: Recipe reference + a handful of grep scripts (Conservative)

- **Description**: A SKILL.md plus a `references/sections.md` cheat-sheet of section names, patterns and traps, and 3–4 small scripts (`summary`, `anr`, `memory`) that each scan the whole file.
- **Scope**: New skill folder only.
- **Effort**: Small
- **Tradeoffs**: Fast to ship and already cuts most wasted calls. No problem detection — the session still diagnoses; each script re-scans the file (~1 s each, fine); format knowledge is spread across scripts and drifts.
- **Compatibility**: Additive.

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

### Option C: Build on Perfetto `trace_processor` as the substrate (rejected by the maintainer — ideas only)

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
