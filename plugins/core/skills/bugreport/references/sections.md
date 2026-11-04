# Sections, traps and the fallback recipe

Section ids are `name#occurrence`: top-level dumpstate sections keep their
header name (`SYSTEM LOG#1`), dumpsys services their service name
(`meminfo#1`). A service dumped in two priority blocks appears twice
(`meminfo#1` in `HIGH`, `meminfo#2` in the full `DUMPSYS`); `sections` shows
the `block` of each.

## Which section answers what

| Question | Section | Shape |
|---|---|---|
| Device, build, boot reason | `SYSTEM PROPERTIES` | `[key]: [value]` |
| What happened, in order | `SYSTEM LOG`, `EVENT LOG`, `KERNEL LOG` — use `timeline`, not `show` | logcat / dmesg |
| Memory right now | `meminfo` | tree, PSS/RSS per process |
| Memory over the last hours | `procstats` | windows (`COMMITTED STATS FROM …`, `AGGREGATED OVER LAST …`) |
| Kills by the low-memory killer | `EVENT LOG` (`am_kill`, `am_proc_died`), `SYSTEM LOG` (`lowmemorykiller`, `lmkd`) | log |
| ANRs | `EVENT LOG` (`am_anr`), `SYSTEM LOG` (`ANR in`), files under `FS/data/anr/` | log, trace files |
| Crashes | `SYSTEM LOG` (`FATAL EXCEPTION`), `FS/data/tombstones/` | log, tombstone files |
| Battery level and health | `battery` | kv |
| Battery drain since charge | `batterystats`, `CHECKIN BATTERYSTATS` | tree, csv |
| Heat and throttling | `thermalservice` | kv + history |
| Storage | `diskstats` | kv (`Data-Free: …`) |
| Installed apps | `package` | tree (`Package [name]`, `pkgFlags=[…]`) |
| CPU and threads | `PROCESSES AND THREADS`, `cpuinfo` | table |
| Power state, wakelocks | `power` | tree |

`summary` already reads properties, battery, diskstats, package, procstats and
the log spans; reach for these sections when its answer is not enough.

## Traps

- **CR line ends.** Some reports end lines with `\r\n` or carry stray `\r`.
  Offsets count every byte, so an offset from `show` is a real file offset.
- **UTF16 input.** Saved by some Windows tools. It is transcoded once into the
  cache; `validate` reports `transcoded: true`, and offsets then refer to the
  transcoded text.
- **NUL bytes.** Truncated writes leave NUL runs; `validate` counts them. Lines
  around them may be cut.
- **Locale numbers.** OEM builds print `2.612.345` or `2,612,345` for the same
  count and `0,00` for zero. Read a number in its own locale before comparing.
- **Unsampled PSS.** `procstats` prints PSS as `0` (or `0,00`) when it did not
  sample a process; rank by RSS for those, never treat 0 as "uses nothing".
- **Timeouts.** A service that did not answer in time ends with
  `*** SERVICE '…' DUMP TIMEOUT …`; `sections` marks it `timed_out`, and its
  content is partial.
- **Duplicate services.** The same service in two blocks can differ (the second
  dump is later). Name the occurrence explicitly (`meminfo#2`) when it matters.
- **OEM sections.** Vendors add sections the scripts know nothing about. They
  are indexed like any other; read them with the recipe below.
- **No clock.** Without an alarm or timezone source, kernel times are elapsed
  since boot only; `timeline` keeps them but marks them.

## Fallback recipe

For any section no command parses:

1. `locate --grep TERM` — which sections mention the term, and how often.
2. `sample --section ID` — the first lines and the sniffed format, so the
   field names and record shape are known before reading more.
3. `show --section ID --grep FIELD --context N` — only the lines that answer
   the question.

Two or three calls, each under the output cap, instead of reading the file.
