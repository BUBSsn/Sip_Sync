> Historical prototype document. Current production behavior is documented in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), [WIFI_PROTOCOL.md](WIFI_PROTOCOL.md), and [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md). BLE, sample-data, and cup-calibration sections below are superseded.

# SipSync: Data Contract Specification

This document is the authoritative hardware and data contract for **SipSync**. It details all domain entities, units, repository interfaces, streams, and mutation methods, followed by a guide for integrating physical Bluetooth Low Energy (BLE) coaster hardware.

---

## 1. Domain Models & Value Objects

### 1.1 `SipEvent`
Represents a discrete liquid intake event detected by the coaster scale.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `id` | `String` | N/A | Unique identifier for deduplication and persistence. |
| `volumeMl` | `int` | Milliliters (`ml`) | Consumed liquid volume. Strictly positive integer (`> 0`). |
| `timestamp` | `DateTime` | UTC | Moment the sip concluded. Transmitted and stored in UTC. Presentation converts via `.toLocal()`. |

---

### 1.2 `CupWeightReading`
Represents a continuous or periodic mass measurement sampled from the scale load cell.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `grams` | `double` | Grams (`g`) | Current vessel + liquid mass. Non-negative real number (`>= 0.0`). |
| `timestamp` | `DateTime` | UTC | Moment sample was acquired by hardware. |

---

### 1.3 `CalibrationResult`
Outcome of an empty-cup tare calibration routine.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `status` | `CalibrationStatus` | Enum | `success`, `failure`, or `timeout`. |
| `measuredGrams` | `double?` | Grams (`g`) | Tare weight measured on success; `null` on failure/timeout. |
| `timestamp` | `DateTime` | UTC | Moment calibration concluded. |
| `errorMessage` | `String?` | N/A | Optional diagnostic message explaining failure/timeout. |

---

### 1.4 `CoasterConnection`
Represents hardware link status and heartbeat.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `status` | `ConnectionStatus` | Enum | `connected`, `connecting`, or `disconnected`. |
| `lastSeen` | `DateTime?` | UTC | Timestamp of last received packet/heartbeat; `null` if never connected. |

---

### 1.5 `UserSettings`
User hydration goals and adaptive reminder preferences.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `dailyGoalMl` | `int` | Milliliters (`ml`) | Target daily intake. Allowed range: `1000` to `4000` ml. Default: `2000`. |
| `inactivityThresholdMinutes` | `int` | Minutes | Inactivity duration before entering dry phase. Default: `45`. |
| `adaptiveRemindersEnabled` | `bool` | Boolean | Master switch for habit-based smart nudges. Default: `true`. |

---

### 1.6 `DailySummary`
Aggregated intake metrics for a single calendar day.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `date` | `DateTime` | Normalized Date | Local calendar date at midnight (`DateTime(year, month, day)`). |
| `totalMl` | `int` | Milliliters (`ml`) | Sum of all sips logged on this calendar day. |
| `goalMl` | `int` | Milliliters (`ml`) | Daily goal active on this calendar day. |
| `progress` *(getter)* | `double` | Ratio | `totalMl / goalMl` (`0.0` to `1.0+`). |
| `isGoalMet` *(getter)* | `bool` | Boolean | True if `totalMl >= goalMl`. |

**Weekly Average Intake Contract**:
Across a 7-day rolling window $[today - 6\text{ days}, \dots, today]$, `averageIntakeMl` is calculated strictly as:
$$\text{Average Intake (ml)} = \left(\frac{\sum_{i=0}^6 \text{totalMl}_i}{7}\right).\text{round}()$$
Dividing by 7 (Option A) enforces that hydration deficit on inactive or skipped days counts against overall habit consistency.


---

### 1.7 `StreakResult` & `StreakBadgeTier`
Calculated gamification streak indicators.

| Field | Type | Units | Semantics / Constraints |
|---|---|---|---|
| `currentStreak` | `int` | Days | Consecutive contiguous days goal was met up to today or yesterday. |
| `bestStreak` | `int` | Days | All-time highest contiguous goal-met day streak. |
| `currentTier` | `StreakBadgeTier` | Enum | Badge tier corresponding to `currentStreak`. |
| `bestTier` | `StreakBadgeTier` | Enum | Badge tier corresponding to `bestStreak`. |

**Streak Badge Tiers**:
- `none`: 0 days
- `tier1`: 1–2 days
- `tier2`: 3–6 days
- `tier3`: 7–13 days
- `tier4`: 14–29 days
- `tier5`: 30+ days

---

## 2. Enums & Progression Stages

### 2.1 `HydrationState` (Pillar 1)
| Value | Bracket | Visual Label |
|---|---|---|
| `gettingStarted` | 0% – 24% | "Just Getting Started" |
| `steadyStream` | 25% – 49% | "Steady Stream" |
| `optimalFlow` | 50% – 79% | "Optimal Flow" |
| `nearlyFull` | 80% – 99% | "Nearly Full" |
| `fullReservoir` | 100%+ | "Full Reservoir" |
| `thirstQuenched` | Transient | "Thirst Quenched" *(brief post-sip toast)* |

### 2.2 `FreshnessPhase` (Pillar 2)
| Value | Elapsed Ratio vs Inactivity Threshold | Semantics |
|---|---|---|
| `fresh` | 0% – 50% | Crisp cool blue indicator; recently hydrated. |
| `fading` | >50% – 100% | Desaturating and dimming indicator. |
| `dry` | >100% | Gentle dry state prompting a smart nudge. |

### 2.3 `SealTier` (Pillar 3)
| Value | Daily Completion | Visual Milestone |
|---|---|---|
| `goalMet` | >= 100% | Glowing water seal with ripple effect. |
| `almostThere` | 80% – 99% | Partial completion ring. |
| `underGoal` | < 80% | Muted progress ring. |

---

## 3. Pure Domain Logic Functions

Located in `lib/domain/logic/hydration_logic.dart`.

| Function | Inputs | Output | Boundary & Edge Cases |
|---|---|---|---|
| `getHydrationState` | `int totalMl, int goalMl` | `HydrationState` | Returns `gettingStarted` if `goalMl <= 0` or `totalMl <= 0`. Over-100% returns `fullReservoir`. |
| `getFreshnessPhase` | `Duration elapsed, Duration threshold` | `FreshnessPhase` | Returns `dry` if `threshold <= Duration.zero`. Negative elapsed time falls back to `fresh`. |
| `getSealTier` | `int totalMl, int goalMl` | `SealTier` | Returns `underGoal` if `goalMl <= 0` or `totalMl < 0`. Exactly 80% maps to `almostThere`. |
| `calculateStreaks` | `List<DailySummary> history, {DateTime? today}` | `StreakResult` | Deduplicates identical dates. If today is in progress, keeps streak alive if yesterday met goal. Empty history returns 0/0. |
| `groupSipMergeWindows` | `List<SipEvent> sips, {Duration window}` | `List<SipEvent>` | Sorts ascending before window evaluation. Sips within window merged into combined volume with latest timestamp. Returns newest-first. |
| `checkDayRollover` | `DateTime lastCheck, DateTime now` | `bool` | Normalizes both dates to local calendar midnight. Correctly handles multi-day app suspensions. |
| `detectSipVolumeFromWeightDrop` | `double prevGrams, double currGrams, {double minThreshold}` | `int?` | Returns `(prev - curr).round()` if drop >= threshold; returns `null` for noise or refills. |

---

## 4. Repository Interfaces

### 4.1 `CoasterRepository`
Hardware communication abstraction.

| Member | Kind | Return / Payload | Description |
|---|---|---|---|
| `sipStream` | Getter | `Stream<SipEvent>` (Broadcast) | Emits discrete sip events as detected by scale. |
| `weightStream` | Getter | `Stream<CupWeightReading>` (Broadcast) | Emits live weight readings sampled by scale load cell. |
| `connectionStream` | Getter | `Stream<CoasterConnection>` (Broadcast) | Emits connection state updates (`connected`, `disconnected`). |
| `currentConnection` | Getter | `CoasterConnection` | Synchronous state snapshot to prevent cold-subscriber delay. |
| `lastReading` | Getter | `CupWeightReading?` | Synchronous snapshot of last received load cell reading. |
| `calibrate({Duration timeout})` | Method | `Future<CalibrationResult>` | Commands scale tare routine. Returns measured grams on success. |

---

### 4.2 `SettingsRepository`
Hydration settings and persistence abstraction.

| Member | Kind | Return / Payload | Description |
|---|---|---|---|
| `getSettings()` | Method | `Future<UserSettings>` | Reads persisted preferences. |
| `currentSettings` | Getter | `UserSettings` | Synchronous snapshot of current preferences. |
| `watchSettings()` | Method | `Stream<UserSettings>` (Broadcast) | Emits updated preferences when changed. |
| `updateSettings(UserSettings)` | Method | `Future<void>` | Persists modified preferences to disk (`SharedPreferences`). |

---

### 4.3 `HistoryRepository`
Intake log and history data abstraction.

| Member | Kind | Return / Payload | Description |
|---|---|---|---|
| `getDailySummaries({start, end})` | Method | `Future<List<DailySummary>>` | Retrieves historical day summaries. |
| `watchDailySummaries()` | Method | `Stream<List<DailySummary>>` (Broadcast) | Emits updated summary list on log additions/edits. |
| `getSipsForDay(DateTime date)` | Method | `Future<List<SipEvent>>` | Fetches sips for specific day, sorted newest-first. |
| `watchTodaySips()` | Method | `Stream<List<SipEvent>>` (Broadcast) | Emits today's sips in real time. |
| `recordSip(SipEvent)` | Method | `Future<void>` | Appends new sip and recalculates day summary. |
| `deleteSip(String sipId)` | Method | `Future<void>` | Removes sip by ID and updates day summary. |
| `updateSipVolume(String, int)` | Method | `Future<void>` | Modifies logged sip volume and updates day summary. |

---

## 5. How to Plug In Real Hardware

When transitioning from the fake simulator to physical coaster hardware (such as an ESP32 or nRF52 BLE smart coaster scale), follow this architecture:

### 5.1 BLE Service & GATT Characteristics
A typical BLE smart coaster exposes a custom GATT Service (e.g., `0000FFF0-0000-1000-8000-00805F9B34FB`):

1. **Weight Notification Characteristic (`0000FFF1-..`)**:
   - Properties: `NOTIFY`
   - Payload: 4-byte IEEE 754 float (or uint32 milligram integer) representing current scale weight in grams.
   - Frequency: 2–5 Hz when weight changes; throttled when static.
2. **Sip Event Indication Characteristic (`0000FFF2-..`)**:
   - Properties: `INDICATE`
   - Payload:
     - Byte 0..1: `uint16` volume in ml.
     - Byte 2..5: `uint32` Unix timestamp UTC seconds (or device uptime).
   - Fired once when a cup lift-and-replace cycle stabilizes.
3. **Tare / Calibration Command Characteristic (`0000FFF3-..`)**:
   - Properties: `WRITE, INDICATE`
   - Command byte `0x01` triggers tare.
   - Coaster indicates `0x00` (success + float tare weight) or `0x01` (failure).
4. **Device State / Heartbeat (`0000FFF4-..`)**:
   - Properties: `READ, NOTIFY`
   - Battery level, firmware version, link heartbeat.

---

### 5.2 Implementing `BleCoasterRepository`

Create a production class that implements `CoasterRepository`:

```dart
import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'; // or your preferred BLE package
import 'package:liquid_store/domain/domain.dart';

class BleCoasterRepository implements CoasterRepository {
  BleCoasterRepository({required this.ble, required this.deviceId}) {
    _initBleSubscriptions();
  }

  final FlutterReactiveBle ble;
  final String deviceId;

  final _sipController = StreamController<SipEvent>.broadcast();
  final _weightController = StreamController<CupWeightReading>.broadcast();
  final _connectionController = StreamController<CoasterConnection>.broadcast();

  CoasterConnection _currentConnection = const CoasterConnection(status: ConnectionStatus.disconnected);
  CupWeightReading? _lastReading;

  @override
  Stream<SipEvent> get sipStream => _sipController.stream;
  @override
  Stream<CupWeightReading> get weightStream => _weightController.stream;
  @override
  Stream<CoasterConnection> get connectionStream => _connectionController.stream;
  @override
  CoasterConnection get currentConnection => _currentConnection;
  @override
  CupWeightReading? get lastReading => _lastReading;

  void _initBleSubscriptions() {
    // 1. Listen to BLE connection state
    ble.connectedDeviceStream.listen((update) {
      final status = update.connectionState == DeviceConnectionState.connected
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected;
      _currentConnection = CoasterConnection(status: status, lastSeen: DateTime.now().toUtc());
      _connectionController.add(_currentConnection);
    });

    // 2. Subscribe to weight characteristic notifications
    ble.subscribeToCharacteristic(weightChar).listen((bytes) {
      final grams = _parseWeightBytes(bytes);
      final reading = CupWeightReading(grams: grams, timestamp: DateTime.now().toUtc());
      _lastReading = reading;
      _weightController.add(reading);
    });

    // 3. Subscribe to discrete sip characteristic indications
    ble.subscribeToCharacteristic(sipChar).listen((bytes) {
      final volumeMl = _parseSipBytes(bytes);
      final sip = SipEvent(
        id: 'ble_${DateTime.now().millisecondsSinceEpoch}',
        volumeMl: volumeMl,
        timestamp: DateTime.now().toUtc(),
      );
      _sipController.add(sip);
    });
  }

  @override
  Future<CalibrationResult> calibrate({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      // Send tare command over BLE
      await ble.writeCharacteristicWithResponse(tareChar, value: [0x01]);
      final responseBytes = await _awaitTareConfirmation(timeout);
      final measuredGrams = _parseWeightBytes(responseBytes);
      return CalibrationResult(
        status: CalibrationStatus.success,
        measuredGrams: measuredGrams,
        timestamp: DateTime.now().toUtc(),
      );
    } catch (e) {
      return CalibrationResult(
        status: CalibrationStatus.failure,
        timestamp: DateTime.now().toUtc(),
        errorMessage: e.toString(),
      );
    }
  }

  void dispose() {
    _sipController.close();
    _weightController.close();
    _connectionController.close();
  }
}
```

---

### 5.3 One-Line Provider Swap

Because the entire application only consumes the abstract `coasterRepositoryProvider` from `lib/data/providers.dart`, swapping to physical hardware requires **zero UI or domain changes**.

Simply pass the real repository in the root `ProviderScope`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ble = FlutterReactiveBle();
  final realHardwareRepo = BleCoasterRepository(ble: ble, deviceId: 'COASTER_MAC_ADDR');

  runApp(
    ProviderScope(
      overrides: [
        coasterRepositoryProvider.overrideWithValue(realHardwareRepo),
      ],
      child: const LiquidStoreApp(),
    ),
  );
}
```

---

## 6. Timestamp & Unit Contract Verification

- **Storage & Transmission**: All timestamps (`SipEvent.timestamp`, `CupWeightReading.timestamp`, `CalibrationResult.timestamp`, `CoasterConnection.lastSeen`) are strictly UTC.
- **Display & Aggregation**: Conversion to local time occurs exclusively at presentation boundaries (`.toLocal()`) or when aggregating by calendar date (`normalizeDate()`).
- **Physical Units**:
  - Volumes: `int` milliliters (`ml`).
  - Masses: `double` grams (`g`).
  - Times / Intervals: `int` minutes / `Duration`.
