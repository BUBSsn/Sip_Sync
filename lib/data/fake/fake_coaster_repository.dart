import 'dart:async';

import '../../domain/domain.dart';
import 'seed_data.dart';

/// Fake implementation of [CoasterRepository] for testing and offline development.
///
/// Pre-seeded with 350g cup weight and connected status.
/// Uses broadcast streams to support multiple concurrent listeners and exposes
/// synchronous getters to avoid cold-subscriber initialization bugs.
class FakeCoasterRepository implements CoasterRepository {
  FakeCoasterRepository({
    double initialWeightGrams = SeedData.defaultCupWeightGrams,
    ConnectionStatus initialConnection = ConnectionStatus.connected,
  }) : _currentConnection = CoasterConnection(
         status: initialConnection,
         lastSeen: DateTime.now().toUtc(),
       ),
       _lastReading = CupWeightReading(
         grams: initialWeightGrams,
         timestamp: DateTime.now().toUtc(),
       );

  final StreamController<SipEvent> _sipController =
      StreamController<SipEvent>.broadcast();
  final StreamController<CupWeightReading> _weightController =
      StreamController<CupWeightReading>.broadcast();
  final StreamController<CoasterConnection> _connectionController =
      StreamController<CoasterConnection>.broadcast();

  CoasterConnection _currentConnection;
  CupWeightReading? _lastReading;

  // Next planned calibration outcome (can be overridden by simulator)
  CalibrationStatus _nextCalibrationStatus = CalibrationStatus.success;
  double _nextCalibrationGrams = SeedData.defaultCupWeightGrams;
  String? _nextCalibrationError;

  @override
  Stream<SipEvent> get sipStream => _sipController.stream;

  @override
  Stream<CupWeightReading> get weightStream => _weightController.stream;

  @override
  Stream<CoasterConnection> get connectionStream =>
      _connectionController.stream;

  @override
  CoasterConnection get currentConnection => _currentConnection;

  @override
  CupWeightReading? get lastReading => _lastReading;

  @override
  Future<CalibrationResult> calibrate({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Simulate real hardware tare settling time
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final now = DateTime.now().toUtc();
    final result = CalibrationResult(
      status: _nextCalibrationStatus,
      measuredGrams: _nextCalibrationStatus == CalibrationStatus.success
          ? _nextCalibrationGrams
          : null,
      timestamp: now,
      errorMessage: _nextCalibrationError,
    );

    if (result.isSuccess && result.measuredGrams != null) {
      simulateWeightChange(result.measuredGrams!, now);
    }

    return result;
  }

  // --- Hardware Simulator Methods ---

  /// Simulates a discrete sip event recorded by the coaster.
  /// Also adjusts cup weight reading downward by equivalent grams (1 ml ≈ 1 g).
  void simulateSip(int volumeMl, [DateTime? timestamp]) {
    assert(volumeMl > 0, 'volumeMl must be positive');
    final ts = (timestamp ?? DateTime.now()).toUtc();
    final event = SipEvent(
      id: 'sip_${ts.millisecondsSinceEpoch}',
      volumeMl: volumeMl,
      timestamp: ts,
    );

    // Update weight if current reading exists
    if (_lastReading != null) {
      final newGrams = (_lastReading!.grams - volumeMl).clamp(0.0, 5000.0);
      simulateWeightChange(newGrams, ts);
    }

    _sipController.add(event);
  }

  /// Simulates a cup weight reading change (e.g. lift, sip, replace, refill).
  void simulateWeightChange(double grams, [DateTime? timestamp]) {
    final ts = (timestamp ?? DateTime.now()).toUtc();
    final reading = CupWeightReading(grams: grams, timestamp: ts);
    _lastReading = reading;
    _weightController.add(reading);
  }

  /// Simulates refilling the cup on the coaster with [waterMl] milliliters of water (1 ml ≈ 1 g).
  void refillCup([int waterMl = 250]) {
    final currentGrams = _lastReading?.grams ?? SeedData.defaultCupWeightGrams;
    simulateWeightChange(currentGrams + waterMl);
  }

  /// Simulates a connection status change (connected, disconnected, connecting).
  void simulateConnection(ConnectionStatus status) {
    _currentConnection = CoasterConnection(
      status: status,
      lastSeen: status == ConnectionStatus.connected
          ? DateTime.now().toUtc()
          : _currentConnection.lastSeen,
    );
    _connectionController.add(_currentConnection);
  }

  /// Pre-configures the outcome of the next calibration invocation,
  /// or immediately executes a simulated calibration routine.
  void setNextCalibrationOutcome({
    CalibrationStatus status = CalibrationStatus.success,
    double measuredGrams = SeedData.defaultCupWeightGrams,
    String? errorMessage,
  }) {
    _nextCalibrationStatus = status;
    _nextCalibrationGrams = measuredGrams;
    _nextCalibrationError = errorMessage;
  }

  /// Closes all broadcast streams upon disposal.
  void dispose() {
    _sipController.close();
    _weightController.close();
    _connectionController.close();
  }
}
