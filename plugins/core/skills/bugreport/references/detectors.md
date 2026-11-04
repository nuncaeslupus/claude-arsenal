# Detector catalogue

Generated from the detector registry by `make sync-bugreport-detectors`; do not edit.
The advice column names the remedy's entry in `advice.md`.

## F1 battery

| detector | finding | advice | inputs |
|---|---|---|---|
| `battery.drain` | `battery.screen_off_drain` | `battery.find-wakelock` | `CHECKIN BATTERYSTATS` |

## F2 thermal

| detector | finding | advice | inputs |
|---|---|---|---|
| `thermal.status` | `thermal.throttling` | `thermal.cool-down` | `thermalservice`, `EVENT LOG` |

## F3 reboots

| detector | finding | advice | inputs |
|---|---|---|---|
| `reboots.reasons` | `reboots.battery_shutdown` | `reboots.check-charging` | `SYSTEM PROPERTIES`, `SYSTEM LOG` |
| `reboots.reasons` | `reboots.watchdog` | `reboots.read-blocked-thread` | `SYSTEM PROPERTIES`, `SYSTEM LOG` |

## F4 anr

| detector | finding | advice | inputs |
|---|---|---|---|
| `anr.anr` | `anr.under_pressure` | `memory.free-ram` | `SYSTEM LOG`, `EVENT LOG`, `VM TRACES AT LAST ANR`, `meminfo`, `CPU INFO`, `PSI memory`, `PSI io` |
| `anr.anr` | `anr.main_thread` | `anr.main-thread` | `SYSTEM LOG`, `EVENT LOG`, `VM TRACES AT LAST ANR`, `meminfo`, `CPU INFO`, `PSI memory`, `PSI io` |

## F5 crashes

| detector | finding | advice | inputs |
|---|---|---|---|
| `crashes.events` | `crashes.repeat_crash` | `crashes.fix-top-exception` | `EVENT LOG` |
| `crashes.events` | `crashes.native_crash` | `crashes.read-tombstone` | `EVENT LOG` |

## F6 memory

| detector | finding | advice | inputs |
|---|---|---|---|
| `memory.churn` | `memory.restart_loop` | `memory.restart-loop` | `EVENT LOG` |
| `memory.pressure` | `memory.swap_thrashing` | `memory.free-ram` | `meminfo`, `CPU INFO`, `PSI memory`, `PSI io` |

## F7 network

| detector | finding | advice | inputs |
|---|---|---|---|
| `network.wifi_scans` | `network.scan_storm` | `network.throttle-scans` | `CHECKIN BATTERYSTATS` |

## F8 peripherals

| detector | finding | advice | inputs |
|---|---|---|---|
| `peripherals.gps` | `peripherals.gps_background` | `peripherals.limit-location` | `CHECKIN BATTERYSTATS` |

## F9 storage

| detector | finding | advice | inputs |
|---|---|---|---|
| `storage.data_free` | `storage.low_free_space` | `storage.clear-caches` | `diskstats` |

## F10 security

| detector | finding | advice | inputs |
|---|---|---|---|
| `security.hygiene` | `security.sideloaded_with_access` | `security.review-sideloaded-app` | `package`, `settings`, `device_policy`, `appops`, `SYSTEM PROPERTIES` |
| `security.hygiene` | `security.debugging_enabled` | `security.turn-off-debugging` | `package`, `settings`, `device_policy`, `appops`, `SYSTEM PROPERTIES` |
| `security.hygiene` | `security.always_on_vpn` | `security.check-vpn-app` | `package`, `settings`, `device_policy`, `appops`, `SYSTEM PROPERTIES` |
| `security.hygiene` | `security.bootloader_unlocked` | `security.relock-bootloader` | `package`, `settings`, `device_policy`, `appops`, `SYSTEM PROPERTIES` |
| `security.hygiene` | `security.patch_old` | `security.update-system` | `package`, `settings`, `device_policy`, `appops`, `SYSTEM PROPERTIES` |
| `security.hygiene` | `security.user_ca` | `security.review-user-certs` | `package`, `settings`, `device_policy`, `appops`, `SYSTEM PROPERTIES` |

## F11 battery-health

| detector | finding | advice | inputs |
|---|---|---|---|
| `battery-health.capacity` | `battery-health.degraded` | `battery-health.replace-battery` | `batterystats` |
