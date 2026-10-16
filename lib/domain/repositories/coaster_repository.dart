import '../models/calibration_result.dart';
import '../models/coaster_connection.dart';
import '../models/cup_weight_reading.dart';
import '../models/sip_event.dart';

/// Contract for communicating with the smart coaster scale hardware.
///
/// Implementations may bridge over Bluetooth Low Energy (BLE), WebSockets,
/// or in-memory simulation.
abstract class CoasterRepository {
  /// Stream of discrete water sip events detected by the coaster.
  /// Broadcast stream: multiple subscribers supported.
  Stream<SipEvent> get sipStream;

  /// Stream of raw/smoothed cup weight readings (in grams) sampled by the coaster.
  /// Broadcast stream: multiple subscribers supported.
  Stream<CupWeightReading> get weightStream;

  /// Stream of connection state updates.
  /// Broadcast stream: multiple subscribers supported.
  Stream<CoasterConnection> get connectionStream;

  /// Synchronous snapshot of the current connection state.
  /// Avoids blank UI states when components subscribe after initial connection.
  CoasterConnection get currentConnection;

  /// Synchronous snapshot of the most recently received weight reading,
  /// or `null` if no reading has been received yet in this session.
  CupWeightReading? get lastReading;

  /// Commands the coaster to execute an empty-cup tare calibration routine.
  ///
  /// The user should place their empty vessel on the coaster before invoking.
  /// Returns a [CalibrationResult] upon completion or timeout.
  Future<CalibrationResult> calibrate({
    Duration timeout = const Duration(seconds: 10),
  });
}
