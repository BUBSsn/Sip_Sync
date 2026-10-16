# Physical acceptance checklist

These checks require the real ESP32, circuit, fixed cup, and phone. They are pending.

- [ ] Confirm pins and that relay INPUT reliably means OFF.
- [ ] First setup: remove cup, press button, verify saved empty-coaster zero.
- [ ] Verify the cup reads 258 g and scale factor 382.09 is accurate.
- [ ] Phone joins LiquidCoaster and receives live state after granting access.
- [ ] Fill from empty and partially filled conditions; final weight stays at or below 655 g after residual flow. Tune the initial 10 g allowance.
- [ ] Cup removal, spill, stale readings, and the 15-second timeout stop pumping.
- [ ] Pump protection continues with the phone disconnected.
- [ ] Lift/return without drinking produces no sip.
- [ ] A measured drink produces exactly one matching saved sip after settling.
- [ ] Return at or below 350 g records the sip before refill; refill adds no sip.
- [ ] Manual water additions update the reference without false intake.
- [ ] Vibration, unstable placement, and drops below 5 g are excluded.
- [ ] Reconnect recovers queued sips without duplicates.
- [ ] Phone/app restart restores history, goal, edits, and deletion tombstones.
- [ ] ESP32 restart preserves timed records and labels unrecoverable times.
- [ ] Queue full raises a fault and pauses refill until records save.
- [ ] Local midnight resets today while retaining previous days.

Do not mark these complete based only on automated checks.

Daily LED regression checks:

- [ ] App intake and LED progress agree after reconnect and queued-event replay.
- [ ] Editing or deleting a sip adjusts the LED progress without restoring deleted volume.
- [ ] ESP32 restart retains the counter; progress LEDs wait for phone clock sync, then show the correct day.
- [ ] Midnight resets local daily LED progress while retaining previous days in phone history.
