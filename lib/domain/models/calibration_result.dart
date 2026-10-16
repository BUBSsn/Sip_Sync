import 'package:flutter/foundation.dart';

/// Status of an empty cup tare/calibration routine.
enum CalibrationStatus {
  /// Tare operation completed successfully.
  success,

  /// Tare failed (e.g., unstable scale, weight out of bounds).
  failure,

  /// Calibration operation timed out before obtaining stable reading.
  timeout,
}

/// Outcome of calibrating (taring) the empty cup weight on the coaster.
///
/// **Units & Semantics**:
/// - [status]: Whether calibration succeeded, failed, or timed out.
/// - [measuredGrams]: Tare empty cup weight in grams (`g`) if [status] == [CalibrationStatus.success],
///   otherwise `null`.
/// - [timestamp]: Moment calibration completed, in **UTC**.
/// - [errorMessage]: Optional human-readable explanation when [status] is not success.
@immutable
class CalibrationResult {
  const CalibrationResult({
    required this.status,
    this.measuredGrams,
    required this.timestamp,
    this.errorMessage,
  }) : assert(
         status != CalibrationStatus.success ||
             (measuredGrams != null && measuredGrams >= 0),
         'measuredGrams must be non-null and non-negative on success',
       );

  /// Status outcome of the calibration routine.
  final CalibrationStatus status;

  /// Measured empty cup weight in grams (g) upon success.
  final double? measuredGrams;

  /// Timestamp of the calibration in UTC.
  final DateTime timestamp;

  /// Human-readable error description on failure/timeout.
  final String? errorMessage;

  bool get isSuccess => status == CalibrationStatus.success;

  CalibrationResult copyWith({
    CalibrationStatus? status,
    double? measuredGrams,
    DateTime? timestamp,
    String? errorMessage,
  }) {
    return CalibrationResult(
      status: status ?? this.status,
      measuredGrams: measuredGrams ?? this.measuredGrams,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalibrationResult &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          measuredGrams == other.measuredGrams &&
          errorMessage == other.errorMessage &&
          timestamp.isAtSameMomentAs(other.timestamp);

  @override
  int get hashCode => Object.hash(
    status,
    measuredGrams,
    errorMessage,
    timestamp.millisecondsSinceEpoch,
  );

  @override
  String toString() =>
      'CalibrationResult(status: $status, measuredGrams: ${measuredGrams}g, timestamp: $timestamp, error: $errorMessage)';
}
