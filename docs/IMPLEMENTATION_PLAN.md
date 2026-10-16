# Fixed-cup implementation status — 15 October 2026

Confirmed: **258 g empty cup**, **655 g safe total**, **350 g refill threshold**.

Implemented software:

1. Stable pre-lift/returned weight comparison; sip recorded before refill.
2. Fixed-cup filling, spill/timeout faults, physical rearming, sensor-failure shutdown, independent pump guard, and persistent empty-scale zero.
3. ESP32 access-point Wi-Fi, structured WebSocket messages, one active protocol client, persistent event queue, clock sync, and replay acknowledgements.
4. Flutter Wi-Fi transport saves before ACK and suppresses duplicate feedback.
5. SQLite intake, edits, deletion tombstones, daily goals, local midnight rollover, startup preference loading, and lifetime XP from real retained records.
6. Production UI excludes sample presets, simulators, USB settings, simulated refill/Quick Sip, portion controls, and cup calibration.
7. Automated storage, local WebSocket, domain, widget, and pure firmware-state tests. Full firmware compiles for ESP32 Dev Module.

Legacy fakes and isolated calibration/USB widgets remain for existing tests but are not wired into production screens or the data path.

## Remaining physical acceptance

Board upload, real-phone routing/permissions, scale factor, relay OFF behavior, pump coast allowance, touch thresholds, and physical sip accuracy still require testing. Follow `HARDWARE_ACCEPTANCE.md`; compilation cannot validate physics.

The initial cutoff includes a conservative 10 g residual-flow allowance. Untimed events spanning ESP32 power restart are explicitly estimated; precise original-day recovery requires an RTC.

## Verification completed

- 189 Flutter tests passed, including real local WebSocket delivery through SQLite to the gauge and restart recovery.
- Flutter static analysis reports no issues.
- Android debug APK builds successfully.
- Complete ESP32 sketch compiles for ESP32 Dev Module; pure cup-state tests pass.
- iOS runtime, physical Wi-Fi routing, scale readings, pump behavior, and spill thresholds await device testing.

## Correctness fixes — 15 October 2026

- Database v2 makes daily goals and current settings one transaction and migrates v1 records without clearing history.
- Delayed days inherit the previous goal; timezone regrouping includes every intake date.
- Resume/rollover refresh handles timezone and backward-date changes; current Home/History goals remain aligned.
- Streaks advance by calendar dates, including 23/25-hour daylight-saving days.
- Gauge tick labels and geometry scale with the selected goal.
- Ten lifetime bosses carry progress across days and award distinct badges in Settings. Boss HP increases from 2,000 to 6,500 ml, with a completed state after boss ten. Badges and XP derive from saved intake, including replay, restart, and correction behavior. Levels cap at 50.
- Coaster connection controls appear only in Settings. Sip animation rises smoothly from empty and uses continuous wave phases, while honoring reduced motion.
- ESP32 LEDs use persisted local daily progress synchronized with the phone, including queued events and deletion watermarks.
- Physical pump/scale/LED validation and iOS runtime checks remain pending.
