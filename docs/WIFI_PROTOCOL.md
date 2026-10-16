# Coaster Wi-Fi protocol v1

WebSocket: `ws://192.168.4.1:81`. Phone manually joins the ESP32 access point. The pump remains autonomous; there is no force-fill network command.

Phone sends `{"type":"hello","protocol":1}`. Firmware responds:

```json
{"type":"hello","protocol":1,"device_id":"device-mac","empty_g":258,"safe_g":655}
```

App checks protocol and cup values, then sends `{"type":"time_sync","unix_ms":<UTC epoch milliseconds>}`. Only the active protocol client can synchronize time or acknowledge events.

Status arrives every 500 ms:

```json
{"type":"status","protocol":1,"device_id":"device-mac","state":"resting","weight_g":555,"cup_present":true,"pump_running":false,"fault":null}
```

States: `no_cup`, `settling`, `resting`, `lifted`, `filling`, `fault`.
Faults: `SPILL`, `PUMP_TIMEOUT`, `SENSOR`, `QUEUE_FULL`, `STORAGE`, `ZERO_REQUIRED`.
Sensor-fault display weights are bounded; they never authorize pumping.

Phone sends `{"type":"ping"}` every two seconds. Firmware responds with a `pong` envelope containing protocol and device ID. No valid packet for 12 seconds clears stale readings and triggers reconnect; retries back off from one to thirty seconds.

## Sip delivery

```json
{"type":"sip","protocol":1,"device_id":"device-mac","event_id":"42","volume_ml":100,"unix_ms":1791979200000,"time_estimated":false}
```

The example time is illustrative. Volume is an integer from 5 through 397 ml. IDs are persistent sequences; the phone namespaces them by device ID. Oldest pending event retries every two seconds until acknowledged.

Phone saves transactionally, refreshes history, synchronizes daily progress, then sends `{"type":"ack","event_id":"42"}`. Duplicate and deleted IDs receive ACK without another animation. Failed saves get no ACK. Firmware removes an event only after persisting its acknowledgement. Its 64-event queue never evicts old records; it pauses refilling when full.

## Daily progress

After handshake, saving a sip, edits/deletions, and rollover, the phone sends:

```json
{"type":"daily_progress","unix_ms":1791979200000,"utc_offset_minutes":480,"total_ml":450,"through_sequence":42}
```

`total_ml` is the authoritative phone-local daily intake. `through_sequence` is the
highest saved sequence for this device, including deleted rows. Firmware adds only
queued events newer than that sequence and belonging to the current local day.
Snapshots are serialized and sent before ACK so removing a queued event cannot
cause progress loss or duplication. Firmware persists its counter, rolls it over
using synchronized time/offset, and waits for clock sync before showing progress
LEDs after reboot. The phone retries a progress snapshot at least every 30 seconds;
offline rollover uses the last known offset until the next connection.

## Time

UTC timestamps are grouped by phone-local calendar day. Before sync, firmware stores boot ID and 64-bit monotonic uptime. Sync reconstructs times within the same boot. Untimed events spanning power restart receive the next sync time with `time_estimated=true`; the app labels them. Accurate original-day assignment for these events requires an RTC.
