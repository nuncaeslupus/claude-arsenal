# Advice reference

One entry per `advice_id` the detectors emit. The first line under each heading
is the canned remedy `analyze_bugreport.py --advice` prints. The rest is
what to do, where the setting lives, and when to escalate. Settings paths are
AOSP and Pixel names; OEM skins rename or move them, so search Settings for the
last word of the path when it is not where these entries say.

## Contents

- F1 battery
- F2 thermal
- F3 reboots
- F4 anr
- F5 crashes
- F6 memory
- F7 network
- F8 peripherals
- F9 storage
- F10 security
- F11 battery-health

## F1 battery

### battery.find-wakelock

Find the app holding the wakelock and restrict its background use.

- The finding's `cause` subject held the most partial-wakelock time with the screen off.
- Android 9+: Settings › Apps › *app* › Battery › Restricted (or "Background usage" off on 14+).
- Check whether the app has a reason to run in the background (navigation, music, sync); if not, uninstall or restrict it.
- Escalate when the drain persists with the top holder restricted: rerun the checkup on a new report and compare the two with `compare_bugreport.py`.

## F2 thermal

### thermal.cool-down

Let the device cool and stop the workload that heated it.

- Remove the case, leave direct sun and stop charging while gaming or navigating.
- Close the app that was in the foreground during the throttling window (`query_bugreport.py timeline --since` around the event).
- Escalate to repair when throttling happens while idle and cool: a failing battery or charge circuit can heat on its own.

## F3 reboots

### reboots.check-charging

Charge the device before it reaches empty and check the charger and cable.

- A `shutdown,battery` boot reason means the battery ran out, not that the system crashed.
- If it shut down with charge still showing, recalibrate by charging to full once, then check battery health (`--family battery-health`).
- Escalate to repair when it shuts down above 15–20 %: the cell cannot hold voltage under load.

### reboots.read-blocked-thread

Open the watchdog line and find what the blocked thread was waiting on.

- The finding names the thread; `query_bugreport.py show --section SYSTEM\ LOG --grep Watchdog` prints the full message and the stack that follows.
- A recently installed app with an accessibility service or device admin is a common trigger; uninstall it and watch for repeats.
- Escalate to the OEM with the report when the blocked thread is a system HAL or the kills repeat after a factory reset.

## F4 anr

### anr.main-thread

The app's main thread was blocked; report it to the app developer with the trace.

- The ANR was not caused by device-wide pressure, so the app itself is the cause.
- Update the app, then clear its cache: Settings › Apps › *app* › Storage › Clear cache.
- Escalate to the developer with the `VM TRACES AT LAST ANR` section (`query_bugreport.py show`) — redacted with `create_bugreport.py --redact` first.

## F5 crashes

### crashes.fix-top-exception

Update or reinstall the crashing app; report the top exception to its developer.

- Several crashes of one exception is a bug in the app, not the device.
- Clear the app's storage if the crash began after an update: Settings › Apps › *app* › Storage › Clear storage (this deletes its local data).
- Escalate to the developer with the exception and the `am_crash` evidence lines.

### crashes.read-tombstone

Read the native tombstone: signal, abort message and crashing frame.

- `SIGABRT` with an abort message is a deliberate stop by the app's native code; `SIGSEGV` is a memory fault.
- A system process crashing (`/system/bin/…`, a HAL) points at the OS build: install pending system updates.
- Escalate to the app developer, or the OEM for system processes, with the `.pb` tombstone from the zip.

## F6 memory

### memory.free-ram

Free memory: restrict or uninstall the background app holding it, and reboot.

- The finding's `holder` subject used the most memory; its `victim`s were the apps that froze.
- Restrict it: Settings › Apps › *app* › Battery › Restricted; or uninstall it if unused.
- Swap near full with high I/O pressure is thrashing — a reboot clears it, restricting the holder keeps it from coming back.
- Escalate when the device thrashes with few apps installed: it may simply have too little RAM for its workload.

### memory.restart-loop

Stop the app that keeps restarting: force-stop, update, or uninstall it.

- A process killed and restarted many times wastes CPU and battery each cycle.
- Settings › Apps › *app* › Force stop, then update it from its store.
- Escalate to the developer when it loops after a clean reinstall.

## F7 network

### network.throttle-scans

Turn off "Wi-Fi scanning" and find the app requesting scans.

- Android 9+: Settings › Location › Location services › Wi-Fi scanning off.
- The finding's `cause` app requested the scans; revoke its location permission if it has no reason to need it.
- Escalate only if scans continue with scanning off and no app holding location.

## F8 peripherals

### peripherals.limit-location

Limit the app's location access to "While using the app".

- Android 10+: Settings › Apps › *app* › Permissions › Location › Allow only while using the app.
- Android 12+: also turn off "Use precise location" for apps that do not need it.
- Escalate when a system app is the holder: check for a pending system update.

## F9 storage

### storage.clear-caches

Clear the largest app caches and remove unused apps and media.

- The finding's `holder` subjects are the largest caches; Settings › Apps › *app* › Storage › Clear cache is safe and loses no data.
- Android 8+: Settings › Storage shows what else is large (photos, downloads).
- Below 5 % free, updates and app installs start failing; keep at least 10 % free.

## F10 security

### security.review-sideloaded-app

Check the sideloaded app's sensitive access and remove it if you do not trust it.

- The app came from outside an app store and holds an access that can read the screen, notifications or other apps, or install software.
- Revoke the access first: Settings › Accessibility (accessibility services), Settings › Apps › Special app access (device admin, notification access, display over other apps, usage access, install unknown apps).
- Then uninstall it: Settings › Apps › *app* › Uninstall. A device admin must be deactivated before it can be uninstalled.
- Escalate when the app will not uninstall or comes back: boot to safe mode and remove it there, or factory reset.

### security.turn-off-debugging

Turn off USB debugging and developer options unless you are developing.

- Settings › System › Developer options › USB debugging off, then the switch at the top of Developer options off.
- Android 11+: also check Wireless debugging is off.
- A connected computer with debugging authorised has full control of the device.

### security.check-vpn-app

Confirm you installed and trust the always-on VPN app.

- An always-on VPN sees all network traffic.
- Settings › Network & internet › VPN › *app* › Always-on VPN off if you did not set it up.
- Escalate when you do not recognise the app or cannot turn it off: it may be a managed (work) profile — ask the device administrator.

### security.relock-bootloader

Relock the bootloader if you did not unlock it on purpose.

- An unlocked bootloader or non-green verified boot means the OS image is not the verified factory one.
- If you unlocked it to install a custom OS, this is expected.
- If you did not, treat the device as tampered: back up data, reflash the factory image and relock (the OEM's flashing instructions), or take it to repair.

### security.update-system

Install the latest system update.

- Settings › System › System update (Settings › Software update on many OEM skins).
- Android 10+: also Settings › Security › Google Play system update.
- Escalate when no update is offered and the patch is over a year old: the device is likely out of support.

### security.review-user-certs

Remove user-installed CA certificates you did not add.

- A user CA lets whoever holds its key read encrypted traffic from apps that trust user certificates.
- Settings › Security › Encryption & credentials › User credentials (Trusted credentials › User on older versions).
- Work profiles install CAs on purpose; ask the administrator before removing one there.

## F11 battery-health

### battery-health.replace-battery

The battery is worn; replace it to restore capacity.

- Capacity under 80 % of design is the usual warranty threshold.
- Android 14+ on some devices: Settings › Battery › Battery health shows the same estimate.
- Escalate to the OEM or a repair shop with the design and learned capacity from the finding.
