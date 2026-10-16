> Historical prototype document. Current production behavior is documented in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), [WIFI_PROTOCOL.md](WIFI_PROTOCOL.md), and [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md). BLE, sample-data, and cup-calibration sections below are superseded.

# Hardware Integration Guide: SipSync Smart Coaster

This technical specification details the physical integration, Bluetooth Low Energy (BLE) GATT architecture, load-cell signal processing, and step-by-step migration path from the developer fake (`FakeCoasterRepository`) to production hardware.

---

## 1. Physical Architecture & The Pure Water Invariant

The SipSync Smart Coaster contains a high-precision strain gauge load cell with a 24-bit ADC (e.g., HX711 or ADS1232) capable of $0.1\text{g}$ resolution up to $2000\text{g}$.

### The Pure Water Invariant
Because SipSync exclusively tracks pure water consumption, the physical density of the fluid is invariant:

$$\rho_{\text{water}} = 1.000\text{ g/cm}^3 = 1.000\text{ g/ml}$$

Therefore, any differential drop in mass directly equals volume consumed:

$$\Delta V\text{ (ml)} = \Delta M\text{ (grams)}$$

No beverage lookup tables, alcohol dehydration penalties, or density compensation coefficients are permitted or required.

---

## 2. BLE GATT Specification

The coaster advertises as a peripheral with the custom Hydration Coaster Service.

### Service UUID: `0000FE50-0000-1000-8000-00805F9B34FB`

| Characteristic | UUID | Properties | Format / Payload | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Weight Stream** | `0000FE51-...` | `NOTIFY`, `READ` | `int32` (little-endian), units: $0.1\text{g}$ | Live continuous scale weight (10–20 Hz when active, throttled to 1 Hz when idle). |
| **Sip Event** | `0000FE52-...` | `NOTIFY`, `INDICATE` | `[uint16 volume_ml, uint32 unix_ts, uint8 confidence]` | Hardware-detected sip completion event pushed upon set-down. |
| **Calibration / Tare** | `0000FE53-...` | `WRITE`, `INDICATE` | Write: `[opcode 0x01 = TARE]`<br>Indicate: `[status, uint16 tare_weight_g]` | Interactive tare zeroing handshake. |
| **Offline Sync** | `0000FE54-...` | `READ`, `WRITE`, `NOTIFY` | Burst packet stream of unacknowledged sips | Replay buffer of drinks logged while out of Bluetooth range. |
| **Device Status** | `0000FE55-...` | `READ`, `NOTIFY` | `[uint8 battery_pct, uint8 flags]` | Battery state and tilt/fault status bits. |

---

## 3. Pick-Up / Sip / Set-Down State Machine

To eliminate noise, false sips from table vibrations, and negative volume bugs on refill, the onboard firmware and driver implement the following 5-stage state machine:

```
                  +-----------------------------------+
                  |         RESTING (Idle)            |
                  | Stable weight: W_baseline >= Tare |
                  +-----------------+-----------------+
                                    |
            Pick-Up Detected        | Load drops below Tare - 10g
            (Cup lifted)            v
                  +-----------------+-----------------+
                  |        CUP_LIFTED (Drinking)      |
                  | Load approx 0g (delta < 10g)      |
                  +-----------------+-----------------+
                                    |
            Cup Returned to Coaster | Load jumps back to > Tare
                                    v
                  +-----------------+-----------------+
                  |          SETTLING                 |
                  | Wait 800ms for mechanical settle  |
                  | |W(t) - W(t-100ms)| < 1.0g        |
                  +--------+-----------------+--------+
                           |                 |
         W_new < W_baseline - 5g             | W_new >= W_baseline + 15g
                           |                 |
                           v                 v
            +--------------+----+     +------+----------------+
            |    VALID SIP      |     |     REFILL EVENT      |
            | Delta = W_base    |     | New water added.      |
            |         - W_new   |     | W_baseline = W_new    |
            | Log Sip(Delta)    |     | No sip logged.        |
            | W_base = W_new    |     +-----------------------+
            +-------------------+
```

### Noise Deadband ($\pm 5\text{g}$)
If $|W_{\text{baseline}} - W_{\text{new}}| \le 5\text{g}$, the deviation is classified as load-cell temperature drift, cup placement offset, or condensation evaporation. **No sip is logged.** $W_{\text{baseline}}$ is softly tracked to $W_{\text{new}}$.

### Refill Event Handling ($> +15\text{g}$)
If $W_{\text{new}} \ge W_{\text{baseline}} + 15\text{g}$:
1. The user poured fresh water into the cup.
2. The system must **never** record negative consumption or trigger an error.
3. The internal baseline is automatically advanced to $W_{\text{new}}$:
$$W_{\text{baseline}} \leftarrow W_{\text{new}}$$
4. The Coaster status notifies the app of a cup refill, resetting the inactivity timer to "Fresh".

---

## 4. Tare Calibration Handshake

Tare calibration ensures the system subtracts the tare weight of the user's specific vessel ($W_{\text{cup\_tare}}$, typically $200\text{g} - 550\text{g}$).

### Protocol Handshake Sequence
1. **User Initiation**: User navigates to Settings and taps "Calibrate Empty Cup Weight".
2. **App Command**: App writes opcode `0x01` (`START_TARE`) to Characteristic `0xFE53`.
3. **Hardware Sampling**:
   - Firmware enters `MEASURING` mode for $1500\text{ms}$.
   - Samples 30 consecutive readings at $20\text{Hz}$.
   - Computes standard deviation $\sigma$.
   - **Stability Check**: If $\sigma > 1.5\text{g}$ (e.g. coaster bumped or table wobbled), hardware emits `0x03` (`STATUS_UNSTABLE`).
4. **Tare Zeroing**:
   - If stable, firmware computes mean mass $\bar{W}$, commits $W_{\text{cup\_tare}} = \bar{W}$ to onboard EEPROM/NVM.
   - Hardware sends Indication: `[0x00 (SUCCESS), uint16 W_cup_tare]`.
5. **App Confirmation**:
   - App transitions `TareRitualButton` from `TareMeasuring` to `TareSuccess(taredGrams)`.
   - UI displays "Cup Tare Zeroed ✓ 350 g".
   - Scale is baselined and ready for water intake tracking.

---

## 5. Reconnection Strategy & Offline Sync

Coasters may disconnect whenever the user walks away with their smartphone.

### Auto-Reconnect Policy
When BLE disconnect occurs:
1. `ConnectionStatus.disconnected` is emitted immediately.
2. The UI enters offline mode (e.g., `FreshnessIndicator` shows "Coaster offline • Reconnecting...").
3. Exponential backoff scan loop:
   - Immediate reconnect attempt ($0\text{s}$)
   - $2\text{s}$ interval (3 attempts)
   - $5\text{s}$ interval (5 attempts)
   - $15\text{s}$ maintenance interval thereafter.

### Offline Sip Replay
The hardware coaster buffers up to 128 sips in an internal circular ring buffer:
- Upon reconnection, app writes `0x02` (`REQUEST_OFFLINE_LOG`) to `0xFE54`.
- Coaster flushes unacknowledged sips with their 32-bit Unix timestamps.
- App deduplicates sips against local database and records them into `HistoryRepository`.
- App writes `0x03` (`ACK_OFFLINE_LOG`), clearing the hardware queue.

---

## 6. Migration Guide: Swapping Fake for Production BLE

The architecture enforces strict dependency inversion: presentation view models **only** depend on the abstract domain interfaces `CoasterRepository` and `HistoryRepository`.

To swap in production hardware:

### Step 1: Add Hardware BLE Driver
Add the approved BLE plugin (e.g., `flutter_blue_plus: ^1.35.0`) to `pubspec.yaml`.

### Step 2: Implement `BleCoasterRepository`
Create `lib/data/ble/ble_coaster_repository.dart` implementing `CoasterRepository`:
```dart
class BleCoasterRepository implements CoasterRepository {
  // Bind BluetoothCharacteristic notifications to _weightController
  // Bind Sip Event indications to _sipController
  // Implement startCalibration() via GATT Characteristic 0xFE53
}
```

### Step 3: Switch Provider in `lib/data/providers.dart`
The infrastructure flag `useFakeHardware` already exists in `lib/data/providers.dart`:
```dart
const bool useFakeHardware = bool.fromEnvironment('USE_FAKE_HARDWARE', defaultValue: kDebugMode);

final coasterRepositoryProvider = Provider<CoasterRepository>((ref) {
  if (useFakeHardware) {
    return FakeCoasterRepository();
  }
  return BleCoasterRepository();
});
```

To run with real hardware:
```bash
flutter run --dart-define=USE_FAKE_HARDWARE=false
```

---

## 7. Physical Bench-Testing Checklist

Before certifying physical coaster hardware for production shipment:

1. [ ] **Graduated Cylinder Accuracy**:
   - Dispense $50\text{ml}$, $100\text{ml}$, $250\text{ml}$, and $500\text{ml}$ of room-temperature distilled water into a tared glass.
   - Verify that recorded sip volume matches cylinder measurement within $\pm 2\%$.
2. [ ] **Noise Deadband Rejection**:
   - Tap on the table surface next to the coaster ($5\times$). Verify 0 false sips are recorded.
   - Rotate the cup on the coaster pad without lifting. Verify 0 false sips are recorded.
3. [ ] **Refill Non-Consumption**:
   - Pour $+300\text{ml}$ into an existing cup resting on the coaster.
   - Verify intake total remains unchanged and no negative sips appear in the log.
4. [ ] **Thermal Drift Tolerance**:
   - Fill cup with $60^\circ\text{C}$ warm water. Leave on coaster for 30 minutes.
   - Verify baseline drift does not trigger ghost sips.
5. [ ] **Disconnect Durability**:
   - Disconnect coaster mid-tare routine by toggling phone Bluetooth off.
   - Verify app transitions cleanly to `TareDisconnected` and recovers without deadlock when Bluetooth is re-enabled.
