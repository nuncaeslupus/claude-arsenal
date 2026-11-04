# Plan: Android bugreport analysis toolkit

**Date**: 2026-11-04
**Specification**: `docs/design/0005-bugreport-analysis-toolkit.md` (approved r3; §§ 5–6 appended by this design)
**Author**: Claude, for the maintainer
**Revision**: 3
**Status**: approved (2026-11-04, revision 2) — without annotations
**Revision log**:
- r1 — first draft
- r2 — maintainer decisions (2026-11-04): single bump via top-down merge (spec D-10), extra flags accepted, new task T25 `summary`; then review fixes on #542 (stacked-branch CI gap, T9→T25, T24 no longer depends on droppable T23, sign-off mapping, stdlib-only check)
- r3 — maintainer decision (2026-11-04): bump per phase, replacing spec D-10's single bump. The required `version bump` check plus `enforce_admins` on `main` meant P1 could only merge through an admin-protection toggle; each of P2–P4 now targets `main`, carries its own bump and `CHANGELOG.md` entry, and gets CI

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the `<repo>-plan-v<N>-<date>-notes.md`
> export it applied, committed beside this file in the same commit. Approval is
> `approved (YYYY-MM-DD, revision N)`, plus `— without annotations` when there
> were none.

> The spec fixes *what* the toolkit finds and *why* each guarantee exists; its
> § 5 fixes the contracts. This plan fixes *what gets built in what order*, in
> the four stacked PRs the spec names, and the measurable gate that proves each
> task landed. Every gate is derived from a § 1 success criterion or a § 6 risk;
> where a gate is not a number, the row says why.

---

## Technical solution

### Architecture overview

The module layout is spec § 5.1. Three layers, built bottom-up so each PR has a
tested substrate under it:

1. **Substrate (P1)** — `_brlib.py` resolves the input (txt / zip / UTF-16,
   § 5.2), scans delimiters into `name#occurrence` sections (§ 5.4), and keeps a
   byte-offset index in the per-user cache (§ 5.3). `_redact.py` filters every
   emitted string (§ 5.10). `query_bugreport.py` and `validate_bugreport.py` sit
   directly on it, so the fallback route ("not parsed → `locate`, `sample`")
   exists before any detector does.
2. **Detectors (P2, P3, P4)** — `_detectors.py` owns the registry, `Finding`,
   `NotParsed` and the fail-soft run loop (§ 5.8); one `_det_<slug>.py` per
   family. `analyze_bugreport.py` is the run loop plus ranking and the
   `bugreport.analyze/1` envelope (§ 5.6).
3. **Interpretation and sharing (P4)** — `references/advice.md` (§ 5.9),
   `create_bugreport.py --redact`, `compare_bugreport.py`.

`har` is the precedent for shape (two-layer tests, output budget, redaction
stance) and is not imported (§ 5.1).

### Data flow

`--input` → `open_report` (key from size + mtime + head/tail hash) → cache hit:
load `index.json`; miss: stream-scan (and, for zip/UTF-16, write `main.txt`) →
`Report`. Commands then read only slices (`seek(start)`, verify delimiter,
read `size` bytes) or named `FS/` members. Detectors turn slices into
`Finding`s; the run loop ranks, applies the byte budget, redacts, and prints one
JSON document.

### State changes

| Artifact | Change | Notes |
|---|---|---|
| `<cache-root>/<key>/index.json` | CREATE / REPLACE | Offsets + metadata only; temp file + `os.replace`; dir `0700`, file `0600` (§ 5.3) |
| `<cache-root>/<key>/main.txt` | CREATE | Zip main entry or transcoded UTF-16 only; plain UTF-8 text is read in place |
| `<cache-root>/*` | DELETE (prune) | Five most recently used keys kept |
| `create_bugreport.py --output` | CREATE | Refuses the input path; existing file needs `--force` |
| The input report | never written | Asserted: input digest before == after, every command |
| `assets/sections.json` | REGENERATE | `make sync-sections` after the new `android` section |
| `validate.py` `CANONICAL_ARGS` | UPDATE | Eight domain flags (§ 5.7) |

### Technology choices

| Choice | Justification |
|---|---|
| stdlib only (`mmap`, `re`, `zipfile`, `zlib`, `json`, `hashlib`, `hmac`, `zoneinfo`) | Spec criterion: zero third-party runtime deps; the `core tests` job runs bare `python3` |
| Byte-offset JSON index, not SQLite | Spec Option B tradeoff: one file, no conversion step; `timeline` can grow a SQLite backend later behind the same interface |
| Extract the zip main entry once (not stream per query) | § 5.2: deflate has no random access; per-query re-decompression breaks `query_s <= 1` |
| Hand-rolled protobuf wire reader | ~100 lines for varint + length-delimited; avoids a `protobuf` dependency (spec criterion) |
| pytest unit layer + bash CLI layer | The `har` split: scanner/clock/redaction are unit problems; `bugreport_test.sh` asserts exit codes and budgets the way a session calls the scripts |

### Out of scope

Perfetto integration (D-3), MCP wrapper (D-2), live adb capture, logcat-only or
ANR-only inputs (room left in the `android` section), comparison analytics beyond
the JSON diff (D-7), a SQLite logcat backend, and committing any real report or
excerpt (D-9).

---

## Implementation tasks

`PR` is the stacked PR the task ships in (spec Option B: P1–P4). Test files are
under `plugins/core/tests/` unless a path says otherwise.

| T# | PR | Description | Scope | Where | Size | Depends | Gate | Tests |
|----|----|-------------|-------|-------|------|---------|------|-------|
| T1 | P1 | Section + scaffold | `android` section + skill scaffold: SKILL.md frontmatter (`name: bugreport`, `metadata.section: android`, `metadata.type: tool`, `allowed-tools`), argparse stubs with `--help` for the five scripts, blurb in `SECTION_BLURBS`, `make sync-sections`, eight domain flags in `CANONICAL_ARGS` | `plugins/core/skills/bugreport/`, `scripts/sync_sections.py`, `plugins/core/skills/init/assets/sections.json`, `plugins/skill-workshop/skills/skill-workshop/scripts/validate.py` | M | — | `resident_token_delta_general == 0` (the `general` row of `make context-budget` is unchanged) and `arg_canon_warnings_bugreport == 0` | `test_section_android_defaults_off` in `skill_sections_test.sh` — a default `/init` vendors no `bugreport` skill · `test_profile_all_includes_android` in `skill_sections_test.sh` — `--profile all` vendors `bugreport` · `test_every_bugreport_script_answers_help` in `bugreport_test.sh` — each of the five scripts exits 0 on `--help` |
| T2 | P1 | Fixture generator | Synthetic fixture generator + seeds: layouts, containers, traps, scenario blocks, PII canaries, scale mode (§ 5.11) | `bugreport/make_fixture.py`, `bugreport/seeds/` | L | T1 | `committed_seed_bytes <= 204800` and `fixture_build_determinism_failures == 0` | `test_same_arguments_build_byte_identical_fixture` in `bugreport/test_fixture.py` — two builds with one seed hash equal · `test_seeds_carry_only_reserved_range_identifiers` in `bugreport/test_fixture.py` — every identifier-shaped string in `seeds/` is in a reserved range · `test_every_layout_and_container_builds` in `bugreport/test_fixture.py` — all 7 layouts × 4 containers produce a file with a dumpstate header |
| T3 | P1 | Input + scanner | `_brlib.py` input resolution + scanner: binary reads, UTF-16 sniff, zip main-entry rule, delimiter scan, priority blocks, `name#occurrence` ids, timed-out sections, tolerant numbers (`1,9GB`, `0,00`) | `skills/bugreport/scripts/_brlib.py` | L | T2 | `section_boundary_mismatches == 0` over every layout × container fixture | `test_bare_cr_does_not_shift_section_offsets` in `bugreport/test_scanner.py` — offsets equal those of the same fixture without `\r` · `test_zip_without_main_entry_picks_largest_dumpstate_text` in `bugreport/test_input.py` — `example.txt` wins over a smaller `dumpstate_board.txt` · `test_service_in_two_blocks_gets_two_occurrence_ids` in `bugreport/test_scanner.py` — ids are `meminfo#1`, `meminfo#2` in file order · `test_locale_decimal_comma_parses_as_number` in `bugreport/test_numbers.py` — `1,9GB` → 1.9 GiB |
| T4 | P1 | Index + cache | Index + cache: key, platform cache root, `--output-dir` override, atomic write, `0700`/`0600`, prune to five, delimiter check + one rebuild, `--force`; `bugreport/benchmark.py` and a dispatch-only benchmark workflow | `_brlib.py`, `bugreport/benchmark.py`, `.github/workflows/bugreport-benchmark.yml` | L | T3 | `index_build_s <= 3` and `peak_rss_mb <= 300` (160 MB txt); `index_build_zip_s <= 6` and `peak_rss_mb <= 300` (234 MB zip); `index_reuse_s <= 0.5` — all on CI `ubuntu-22.04`, 1/10-scale guard on every push | `test_index_holds_no_section_text` in `bugreport/test_index.py` — no canary string appears in `index.json` · `test_output_dir_overrides_cache_root` in `bugreport/test_index.py` — nothing is written under the default root · `test_middle_edit_keeping_size_and_mtime_triggers_rebuild` in `bugreport/test_index.py` — the delimiter check rebuilds and the slice is correct · `test_interrupted_build_keeps_previous_index` in `bugreport/test_index.py` · `test_prune_keeps_five_most_recent_keys` in `bugreport/test_index.py` |
| T4 | build ≤ 3 s / ≤ 300 MB (160 MB txt); zip ≤ 6 s / ≤ 300 MB; reuse ≤ 0.5 s | txt 167.8 MB: 0.49 s / 196.2 MB; zip: 1.18 s / 267.5 MB; reuse 0.002 s — all pass | `gh workflow run bugreport-benchmark.yml` (run 41895306617) | 3323c63 | CI ubuntu-22.04 py3.12.16 | 2026-11-04 |
| T5 | P1 | Redaction + budget | `_redact.py`: the ten § 5.10 kinds, Luhn, harvest, per-run HMAC tokens; `apply_budget` + capped envelope; `_console.py` copy with duplication header | `scripts/_redact.py`, `_brlib.py`, `scripts/_console.py` | M | T3 | `pii_in_default_output == 0` over every canary kind in the seeded fixture | `test_each_canary_kind_is_redacted` in `bugreport/test_redact.py` — one assertion per kind · `test_equal_values_share_a_token_within_one_run` in `bugreport/test_redact.py` · `test_tokens_differ_across_runs` in `bugreport/test_redact.py` — salts are never reused · `test_masked_android_mac_is_left_alone` in `bugreport/test_redact.py` — `02:00:00:00:00:00` passes unchanged · `test_capped_output_is_valid_json_with_envelope` in `bugreport/test_budget.py` — `truncated`, `shown`, `omitted` present and rows whole |
| T6 | P1 | query primitives | `query_bugreport.py` `sections`, `locate`, `sample`, `show`; selector rules (§ 5.4); format sniff + record shape | `scripts/query_bugreport.py` | L | T4, T5 | `query_s <= 1` (any single-section command, warm index) and `commands_to_first_fields <= 2` with each `output_bytes <= 2048` | `test_unparsed_section_reaches_fields_in_two_commands` in `bugreport_test.sh` — `locate` then `sample` on an OEM section yields its key names · `test_ambiguous_bare_name_exits_2_with_candidates` in `bugreport/test_query.py` · `test_sample_sniffs_kv_table_tree_csv_log` in `bugreport/test_query.py` — each seed format is classified correctly · `test_query_never_writes_the_input` in `bugreport_test.sh` — input digest unchanged |
| T7 | P1 | Clock + timeline | Clock + `timeline`: offset derivation (alarm → timezone → none), year inference, kernel/batterystats conversion, `--since` grammar, date selection, DST fold, `--window` | `_brlib.py`, `query_bugreport.py` | L | T6 | `timeline_offset_error_s == 0` on the known-offset fixture | `test_alarm_dump_offset_converts_kernel_time_to_local` in `bugreport/test_clock.py` — a dmesg line lands on its seeded local minute · `test_since_matching_two_dates_exits_2_listing_both` in `bugreport/test_clock.py` · `test_december_logs_in_january_report_get_previous_year` in `bugreport/test_clock.py` · `test_no_offset_source_marks_rows_elapsed` in `bugreport/test_clock.py` — rows carry `clock: elapsed`, nothing is guessed; `test_since_outside_span_exits_1` — a time before the first or after the last timestamp exits 1 with the span printed; `test_since_empty_window_exits_0` — a window inside the span with no events exits 0 with an empty list |
| T8 | P1 | validate script | `validate_bugreport.py`: kind, main entry, format/Android/SDK/OEM, encoding facts, per-detector-input status (registry-ready, empty until P2) | `scripts/validate_bugreport.py` | M | T6 | `layout_fixture_unhandled_exceptions == 0` across every layout × container × trap | `test_validate_reports_layout_facts_per_fixture` in `bugreport/test_validate.py` — Android release and OEM match each fixture's seed · `test_non_bugreport_exits_1` in `bugreport_test.sh` — a random text file is rejected with a reason · `test_utf16_input_is_reported_transcoded` in `bugreport/test_validate.py` |
| T25 | P1 | summary | `query_bugreport.py summary` (spec § 5.7, requirement 12): device, build, capture time, uptime + boot reason, per-source coverage windows, file stats, battery and storage snapshot, app counts; `unknown` for absent fields | `scripts/query_bugreport.py`, `scripts/_summary.py` | M | T6, T7 | `summary_missing_fields == 0` across every layout fixture (output ≤ 2048 B asserted by its test) | `test_summary_reports_every_field_per_layout` in `bugreport/test_summary.py` — every field is present as a value or `unknown` and output stays ≤ 2048 B; `test_summary_coverage_windows_match_fixture_bounds` — per-source first/last timestamps equal the generator's seeded bounds |
| T9 | P1 | SKILL.md (P1) | SKILL.md (P1 scope: standing constraints front-loaded — privacy, output cap, fallback route; script table), `references/sections.md` (section map, traps, fallback recipe), `evals/loading_verification.json` | `skills/bugreport/SKILL.md`, `references/`, `evals/` | M | T7, T8, T25 | `skill_workshop_must_findings == 0` | `test_skill_md_commands_resolve_to_existing_scripts_and_flags` in `bugreport_test.sh` — every command SKILL.md shows parses under its script's argparse · `test_skill_folder_has_no_must_findings` in `bugreport_test.sh` — skill-workshop `validate.py` on the folder reports 0 `must` |
| T10 | P2 | Detector framework | `_detectors.py` + `analyze_bugreport.py`: registry, `Finding`, `NotParsed`, fail-soft loop with `error:` reasons, ranking, `bugreport.analyze/1`, `--family`/`--severity`/`--limit`/`--output`, `views`; `validate` reports detector inputs | `scripts/_detectors.py`, `scripts/analyze_bugreport.py`, `validate_bugreport.py` | L | T9 | `capped_outputs_parse_rate == 1.0` and `checkup_output_bytes <= 4096` | `test_raising_detector_becomes_not_parsed_row` in `bugreport/test_detectors.py` — a deliberately broken detector yields `reason: error: …` and the run exits 0 · `test_analyze_json_is_byte_identical_across_runs_modulo_tokens` in `bugreport/test_analyze.py` · `test_family_accepts_slug_and_f_number` in `bugreport/test_analyze.py` |
| T11 | P2 | F6 memory | F6 memory detectors + `views.memory`: procstats 24 h memory × time (PSS, RSS fallback for `0,00`), foreground-while-screen-off, meminfo, swap, PSI, lmkd kills | `scripts/_det_memory.py` | L | T10 | `family_fire_nofire_failures_f6 == 0` | `test_swap_97pct_with_kswapd_cpu_fires_thrashing` in `bugreport/test_det_memory.py` · `test_unsampled_pss_falls_back_to_rss` in `bugreport/test_det_memory.py` — the holder ranking uses RSS, not 0 · `test_healthy_memory_fixture_fires_nothing` in `bugreport/test_det_memory.py` |
| T12 | P2 | F4 ANR | F4 ANR detectors + `views.anr`: ANR files and `ANR in` blocks, reason, victim vs pressure, main-thread state, top CPU | `scripts/_det_anr.py` | M | T10 | `family_fire_nofire_failures_f4 == 0` | `test_input_dispatch_anr_under_pressure_marks_victim` in `bugreport/test_det_anr.py` — the ANR'd process is `role: victim`, not `cause` · `test_anr_with_idle_system_blames_main_thread` in `bugreport/test_det_anr.py` |
| T13 | P2 | Churn + F2 thermal | Churn (kill → restart loops, `am_proc_died`/`am_proc_start`; F6 view) + F2 thermal (`thermalservice` status/history, `thermal_pressure`) | `scripts/_det_memory.py`, `scripts/_det_thermal.py` | M | T10 | `family_fire_nofire_failures_f2 == 0` and `churn_loop_detected_on_fixture == 1` | `test_restart_loop_names_the_restarted_package` in `bugreport/test_det_churn.py` · `test_throttling_history_fires_thermal` in `bugreport/test_det_thermal.py` · `test_cool_device_fires_no_thermal` in `bugreport/test_det_thermal.py` |
| T14 | P2 | Provenance checkup | Provenance checkup: `thrashing` scenario end to end; SKILL.md checkup recipe | `bugreport_test.sh`, `SKILL.md` | M | T11, T12, T13 | `commands_to_diagnosis <= 1` — top finding `memory.swap_thrashing`, both ANR'd processes as `victim`, top holders listed | `test_checkup_on_thrashing_fixture_ranks_thrashing_first` in `bugreport/test_checkup.py` · `test_checkup_default_output_fits_4096_bytes` in `bugreport_test.sh` |
| T15 | P3 | F5 crashes | F5 crashes + `views.crashes`: `_pbwire.py`, tombstone `.pb` + text, `FATAL EXCEPTION`, `exit-info` reasons, repeat counts | `scripts/_pbwire.py`, `scripts/_det_crashes.py` | L | T14 | `family_fire_nofire_failures_f5 == 0` and `pb_tombstone_decode_failures == 0` | `test_pb_tombstone_yields_signal_and_abort_message` in `bugreport/test_pbwire.py` · `test_unknown_pb_fields_are_skipped` in `bugreport/test_pbwire.py` · `test_repeat_crash_counts_per_package` in `bugreport/test_det_crashes.py` |
| T16 | P3 | F1 battery | F1 battery + `views.battery` from the checkin CSV (vers 15 and 36): wakelocks, wakeup reasons, screen-off drain, radio time, doze, buckets, alarms, jobs | `scripts/_det_battery.py` | L | T14 | `family_fire_nofire_failures_f1 == 0` | `test_foreground_app_screen_off_fires_drain` in `bugreport/test_det_battery.py` — the `battery-exhaustion` scenario names the app · `test_checkin_v15_and_v36_both_parse` in `bugreport/test_det_battery.py` |
| T17 | P3 | F3 reboots | F3 reboots: boot reason properties, last kmsg / pstore panic, watchdog kills, `boot_progress_*`, uptime | `scripts/_det_reboots.py` | M | T14 | `family_fire_nofire_failures_f3 == 0` | `test_shutdown_battery_reason_fires_reboot_finding` in `bugreport/test_det_reboots.py` · `test_watchdog_kill_names_blocked_thread` in `bugreport/test_det_reboots.py` |
| T18 | P3 | F7 + F8 | F7 network (signal, radio-active, drops, scan storms, `netstats`) + F8 peripherals (Bluetooth HAL crashes, HCI timeouts, location holders, GPS on-time, sensor wakeups) | `scripts/_det_network.py`, `scripts/_det_peripherals.py` | L | T14 | `family_fire_nofire_failures_f7 == 0` and `family_fire_nofire_failures_f8 == 0` | `test_wifi_scan_storm_fires_with_requester` in `bugreport/test_det_network.py` · `test_gps_held_by_background_app_fires` in `bugreport/test_det_peripherals.py` · `test_ssid_never_appears_in_network_claims` in `bugreport/test_det_network.py` |
| T19 | P3 | F9 + F11 | F9 storage (free space, cache sizes, `update_engine`/OTA failures, `dex2oat` storms) + F11 battery health (health, capacity vs design, cycles, charge limits, charging temperature) | `scripts/_det_storage.py`, `scripts/_det_battery_health.py` | M | T14 | `family_fire_nofire_failures_f9 == 0` and `family_fire_nofire_failures_f11 == 0` | `test_low_free_space_fires_with_top_caches` in `bugreport/test_det_storage.py` · `test_capacity_below_80pct_of_design_fires` in `bugreport/test_det_battery_health.py` |
| T20 | P4 | F10 security | F10 security & hygiene: non-store installers, `REQUEST_INSTALL_PACKAGES`, accessibility/admin/listener/overlay/usage holders, user CAs, always-on VPN, ADB/dev options, bootloader/verified boot, patch age, Play Protect where exposed | `scripts/_det_security.py` | L | T14 | `family_fire_nofire_failures_f10 == 0` | `test_sideloaded_app_with_accessibility_fires_high` in `bugreport/test_det_security.py` · `test_store_installed_app_does_not_fire` in `bugreport/test_det_security.py` · `test_patch_age_uses_report_date_not_today` in `bugreport/test_det_security.py` |
| T21 | P4 | Advice reference | `references/advice.md` for every `advice_id`; `--advice`; generated `references/detectors.md`; `_index.md` if the split rule triggers | `skills/bugreport/references/`, `analyze_bugreport.py` | M | T15, T16, T17, T18, T19, T20 | `advice_ids_missing_entry == 0` and `advice_orphan_headings == 0` | `test_every_registry_advice_id_has_an_entry` in `bugreport/test_advice.py` · `test_advice_flag_prints_first_line_of_entry` in `bugreport/test_advice.py` · `test_detectors_reference_matches_registry` in `bugreport/test_advice.py` |
| T22 | P4 | Redacted copy | `create_bugreport.py --redact`: text → text, zip → zip with binary members dropped and listed, refuse input path, `--force` | `scripts/create_bugreport.py` | M | T20 | `pii_in_redacted_copy == 0` over every canary kind, txt and zip | `test_redacted_zip_drops_pb_and_proto_members` in `bugreport/test_create.py` · `test_output_equal_to_input_is_refused` in `bugreport/test_create.py` · `test_redacted_copy_still_indexes_and_analyzes` in `bugreport/test_create.py` — the scrubbed file is a valid bugreport |
| T23 | P4 | compare script | `compare_bugreport.py`: pair on id + primary subject, new/gone/changed, ranking deltas, schema-major check (droppable, D-7) | `scripts/compare_bugreport.py` | S | T21 | `invented_changes_on_identical_inputs == 0` | `test_same_report_twice_compares_empty` in `bugreport/test_compare.py` — different salts, no changes · `test_schema_major_mismatch_exits_1` in `bugreport/test_compare.py` |
| T24 | P4 | Release | Release: SKILL.md complete (≤ 500 lines), trigger evals, all-family coverage, flag parity, context budget, `.bundle-version` minor bump + `CHANGELOG.md` entry + `make sync-version` (each phase bumps — see Merge order) | `SKILL.md`, `evals/`, `plugins/core/skills/init/assets/.bundle-version`, `CHANGELOG.md` | M | T22 | `resident_listing_tokens_with_android <= 130` and `resident_token_delta_without_android == 0` and `families_without_fire_nofire_fixture == 0` and `skill_workshop_must_findings == 0` | `test_every_family_f1_to_f11_has_fire_and_nofire` in `bugreport/test_coverage.py` · `test_sibling_scripts_share_input_output_limit_flags` in `bugreport/test_parity.py` · `test_trigger_evals_cover_positive_and_negative_prompts` in `bugreport/test_evals.py` — evals hold ≥ 1 "Not for" prompt per negative trigger |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

### Dependency graph

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies — phases",
 "nodes": [
  {"id": "P1", "text": "Phase 1\nT1, T2, T3, T4, T5, T6, T7, T8, T25"},
  {"id": "P2", "text": "Phase 2\nT9, T10, T11, T12, T13, T14, T15, T…"},
  {"id": "P3", "text": "Phase 3\nT18, T19, T20, T21, T22, T23, T24"}
 ],
 "edges": [
  {"from": "P1", "to": "P2"},
  {"from": "P2", "to": "P3"}
 ]}
```

**Phase 1** — T1, T2, T3, T4, T5, T6, T7, T8, T25

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies — phase 1",
 "nodes": [
  {"id": "T1", "text": "T1\nSection + scaffold"},
  {"id": "T2", "text": "T2\nFixture generator"},
  {"id": "T3", "text": "T3\nInput + scanner"},
  {"id": "T4", "text": "T4\nIndex + cache"},
  {"id": "T5", "text": "T5\nRedaction + budget"},
  {"id": "T6", "text": "T6\nquery primitives"},
  {"id": "T7", "text": "T7\nClock + timeline"},
  {"id": "T8", "text": "T8\nvalidate script"},
  {"id": "T25", "text": "T25\nsummary"}
 ],
 "edges": [
  {"from": "T1", "to": "T2"},
  {"from": "T2", "to": "T3"},
  {"from": "T3", "to": "T4"},
  {"from": "T3", "to": "T5"},
  {"from": "T4", "to": "T6"},
  {"from": "T5", "to": "T6"},
  {"from": "T6", "to": "T7"},
  {"from": "T6", "to": "T8"},
  {"from": "T7", "to": "T25"}
 ]}
```

**Phase 2** — T9, T10, T11, T12, T13, T14, T15, T16, T17 (with T8, T25 from earlier phases)

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies — phase 2",
 "nodes": [
  {"id": "T8", "text": "T8\nphase 1"},
  {"id": "T25", "text": "T25\nphase 1"},
  {"id": "T9", "text": "T9\nSKILL.md (P1)"},
  {"id": "T10", "text": "T10\nDetector framework"},
  {"id": "T11", "text": "T11\nF6 memory"},
  {"id": "T12", "text": "T12\nF4 ANR"},
  {"id": "T13", "text": "T13\nChurn + F2 thermal"},
  {"id": "T14", "text": "T14\nProvenance checkup"},
  {"id": "T15", "text": "T15\nF5 crashes"},
  {"id": "T16", "text": "T16\nF1 battery"},
  {"id": "T17", "text": "T17\nF3 reboots"}
 ],
 "edges": [
  {"from": "T8", "to": "T9"},
  {"from": "T25", "to": "T9"},
  {"from": "T9", "to": "T10"},
  {"from": "T10", "to": "T11"},
  {"from": "T10", "to": "T12"},
  {"from": "T10", "to": "T13"},
  {"from": "T11", "to": "T14"},
  {"from": "T12", "to": "T14"},
  {"from": "T13", "to": "T14"},
  {"from": "T14", "to": "T15"},
  {"from": "T14", "to": "T16"},
  {"from": "T14", "to": "T17"}
 ]}
```

**Phase 3** — T18, T19, T20, T21, T22, T23, T24 (with T14, T15, T16, T17 from earlier phases)

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies — phase 3",
 "nodes": [
  {"id": "T14", "text": "T14\nphase 2"},
  {"id": "T15", "text": "T15\nphase 2"},
  {"id": "T16", "text": "T16\nphase 2"},
  {"id": "T17", "text": "T17\nphase 2"},
  {"id": "T18", "text": "T18\nF7 + F8"},
  {"id": "T19", "text": "T19\nF9 + F11"},
  {"id": "T20", "text": "T20\nF10 security"},
  {"id": "T21", "text": "T21\nAdvice reference"},
  {"id": "T22", "text": "T22\nRedacted copy"},
  {"id": "T23", "text": "T23\ncompare script"},
  {"id": "T24", "text": "T24\nRelease"}
 ],
 "edges": [
  {"from": "T14", "to": "T18"},
  {"from": "T14", "to": "T19"},
  {"from": "T14", "to": "T20"},
  {"from": "T15", "to": "T21"},
  {"from": "T16", "to": "T21"},
  {"from": "T17", "to": "T21"},
  {"from": "T18", "to": "T21"},
  {"from": "T19", "to": "T21"},
  {"from": "T20", "to": "T21"},
  {"from": "T20", "to": "T22"},
  {"from": "T21", "to": "T23"},
  {"from": "T22", "to": "T24"}
 ]}
```

### Merge order and PRs

| PR | Tasks | Branch | Bump |
|---|---|---|---|
| P1 | T1–T9, T25 | `feat/bugreport-p1-substrate` from `main` | none — merged in #547 through an admin-protection toggle, which r3 retires |
| P2 | T10–T14 | `feat/bugreport-p2-memory-anr` from `main` | **minor** (5.16.0) — first release of the `bugreport` skill: P1's substrate plus `analyze` for memory, ANR and thermal |
| P3 | T15–T19 | `feat/bugreport-p3-families` from `main` | **minor** — new detector families |
| P4 | T20–T24 | `feat/bugreport-p4-security-release` from `main` | **minor** — security, `create`/`compare`, release polish |

Each phase targets `main` once the previous one has merged, and carries its own
`.bundle-version` bump, `CHANGELOG.md` entry and `make sync-version`, so every PR
passes the required `version bump` check and runs the full CI on its own diff.
Inside a phase the tasks run in table order; T11–T13 and T15–T19 are
independent of each other and may be parallel commits. **Chosen by the
maintainer (r3, 2026-11-04): bump per phase**, after the single-bump plan of
spec D-10 left P1 mergeable only by toggling `enforce_admins`.

A stall after any phase leaves a released, coherent subset: the `CHANGELOG.md`
entry of each phase says what the skill covers so far. T24 keeps its release
checks (SKILL.md, evals, coverage, parity, budget) and its own bump.

After the release merges: `make release-check`; on `NO TAG`, ask the maintainer
to run `make tag` from their machine (CLAUDE.md § Versioning).

### Fixtures — generated, never captured

Every fixture is built at test time by `make_fixture.py` (§ 5.11); only seeds
are committed. One scenario per detector branch, so a failure names its cause:

| Fixture build | Exercises |
|---|---|
| `modern` + `thrashing` | the provenance case (SC `commands_to_diagnosis`) |
| `modern` + `battery-exhaustion` | F1/F3: `shutdown,battery`, foreground app screen off |
| each layout × each container | scanner, main-entry rule, validate facts |
| `modern` + all traps | `\r`, UTF-16, NUL, locale commas, unsampled PSS, timed-out section, duplicate service |
| `modern` + `canaries` | one identifier of every § 5.10 kind |
| `modern` + `multi-day` | `--since` ambiguity |
| `modern` + `healthy` | every detector's no-fire case |
| scale mode 160 MB txt / 234 MB zip | benchmark (CI dispatch), 1/10 scale on push |

Before the release (T24), the maintainer's five Pixel reports and the public
corpus are re-run **locally** with the zero-`error:` bar and the provenance
diagnosis and the T25 summary coverage windows (within one minute of the hand-read values) checked by hand (D-9); the result is recorded in the Evidence log as
`Env: local`, beside — never instead of — the CI rows.

---

## Evidence log

`execution` appends one row per task as it lands (RED → GREEN → RECORD): the measured value, the exact command that produced it, the commit SHA, and the environment provenance. `review` / `ship` audit this table; `gate-check`'s `run_gate.py` reads it. A gated task is not "done" until its row is complete and the measured value meets the gate.

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | `resident_token_delta_general == 0`, `arg_canon_warnings_bugreport == 0` | general row 3053 → 3053 (Δ 0); 0 arg-canon warnings; listing 70 tok | `make context-budget`; `validate.py plugins/core/skills/bugreport` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T2 | `committed_seed_bytes <= 204800`, `fixture_build_determinism_failures == 0` | 9857 B; 0 failures | `uv run pytest plugins/core/tests/bugreport/test_fixture.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T3 | `section_boundary_mismatches == 0` | 0 over every layout × container | `uv run pytest plugins/core/tests/bugreport/test_scanner.py test_input.py test_numbers.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T4 | build ≤ 3 s / ≤ 300 MB (160 MB txt); zip ≤ 6 s / ≤ 300 MB; reuse ≤ 0.5 s | txt 167.8 MB: 0.70 s / 200.6 MB; zip: 1.68 s / 271.8 MB; reuse 0.004 s | `python3 plugins/core/tests/bugreport/benchmark.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T5 | `pii_in_default_output == 0` | 0 over every canary kind | `uv run pytest plugins/core/tests/bugreport/test_redact.py test_budget.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T6 | `query_s <= 1`, `commands_to_first_fields <= 2`, each ≤ 2048 B | 160 MB warm: show 0.135 s / 967 B, sample 0.138 s / 1061 B, locate 0.263 s / 158 B; 2 commands | `uv run pytest plugins/core/tests/bugreport/test_query.py`; `bugreport_test.sh` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T7 | `timeline_offset_error_s == 0` | 0 | `uv run pytest plugins/core/tests/bugreport/test_clock.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T8 | `layout_fixture_unhandled_exceptions == 0` | 0 | `uv run pytest plugins/core/tests/bugreport/test_validate.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T25 | `summary_missing_fields == 0`, output ≤ 2048 B | 0; 1494 B at 160 MB | `uv run pytest plugins/core/tests/bugreport/test_summary.py` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T9 | `skill_workshop_must_findings == 0` | 0 | `validate.py plugins/core/skills/bugreport`; `bugreport_test.sh` | 92bc00d | local Linux x86_64 py3.12 | 2026-11-04 |
| T10 | `capped_outputs_parse_rate == 1.0`, `checkup_output_bytes <= 4096` | 1.0 (0 `error:` rows over 7 layouts × 4 scenarios × traps); 3896 B with every view | `uv run pytest plugins/core/tests/bugreport/test_detectors.py test_analyze.py`; `bugreport_test.sh` | P2 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T11 | `family_fire_nofire_failures_f6 == 0` | 0 | `uv run pytest plugins/core/tests/bugreport/test_det_memory.py test_checkup.py` | P2 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T12 | `family_fire_nofire_failures_f4 == 0` | 0 | `uv run pytest plugins/core/tests/bugreport/test_det_anr.py test_checkup.py` | P2 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T13 | `family_fire_nofire_failures_f2 == 0`, `churn_loop_detected_on_fixture == 1` | 0; 1 | `uv run pytest plugins/core/tests/bugreport/test_det_churn.py test_det_thermal.py` | P2 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T14 | `commands_to_diagnosis <= 1` | 1 — top finding `memory.swap_thrashing`, ANRs as `victim`, top 3 holders | `uv run pytest plugins/core/tests/bugreport/test_checkup.py` | P2 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T15 | `family_fire_nofire_failures_f5 == 0`, `pb_tombstone_decode_failures == 0` | 0; 0 | `uv run pytest plugins/core/tests/bugreport/test_pbwire.py test_det_crashes.py` | P3 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T16 | `family_fire_nofire_failures_f1 == 0` | 0 (v15 and v36 checkin) | `uv run pytest plugins/core/tests/bugreport/test_det_battery.py` | P3 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T17 | `family_fire_nofire_failures_f3 == 0` | 0 | `uv run pytest plugins/core/tests/bugreport/test_det_reboots.py` | P3 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T18 | `family_fire_nofire_failures_f7 == 0`, `family_fire_nofire_failures_f8 == 0` | 0; 0 | `uv run pytest plugins/core/tests/bugreport/test_det_network.py test_det_peripherals.py` | P3 PR | local Linux x86_64 py3.14 | 2026-11-04 |
| T19 | `family_fire_nofire_failures_f9 == 0`, `family_fire_nofire_failures_f11 == 0` | 0; 0 | `uv run pytest plugins/core/tests/bugreport/test_det_storage.py test_det_battery_health.py` | P3 PR | local Linux x86_64 py3.14 | 2026-11-04 |

**Benchmark provenance.** `index_build_s`, `index_build_zip_s`, `index_reuse_s`
and `peak_rss_mb` are measured on the CI `ubuntu-22.04` runner against a report
generated by `benchmark.py` itself, recording the generator seed. A local
measurement may sit beside it; it never replaces it.

---

## Sign-off

- [ ] Every spec § 1 success criterion maps to a gate row (T4, T5, T6, T8, T10, T14, T21, T24, T25 cover them; T24 also carries the stdlib-only check — `test_runtime_imports_are_stdlib_only` scans every script, `_pbwire.py` included, for non-stdlib imports)
- [ ] Every spec § 6 risk has a test or an accepted-risk note
- [x] Merge strategy chosen: one PR into `main` per phase, one bump each (r3, superseding spec D-10)
- [ ] T25 summary gate green, and before release the provenance report's summary coverage windows checked locally against the hand-read values (within one minute; real report never committed, D-9)
- [ ] `make context-budget`: `android` row ≤ 130 tokens, `general` row unchanged
- [ ] Ready for execution
