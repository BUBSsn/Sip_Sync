import 'package:flutter/foundation.dart';

/// Represents a physical weight measurement sampled from the smart coaster scale.
///
/// **Units & Semantics**:
/// - [grams]: Cup + liquid mass measured in grams (`g`). Non-negative real number.
/// - [timestamp]: Moment the reading was sampled by hardware, in **UTC**.
@immutable
class CupWeightReading {
  const CupWeightReading({required this.grams, required this.timestamp})
    : assert(grams >= 0.0, 'Weight in grams cannot be negative');

  /// Weight in grams (g).
  final double grams;

  /// UTC timestamp of reading.
  final DateTime timestamp;

  /// Returns a copy of this [CupWeightReading] with updated fields.
  CupWeightReading copyWith({double? grams, DateTime? timestamp}) {
    return CupWeightReading(
      grams: grams ?? this.grams,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CupWeightReading &&
          runtimeType == other.runtimeType &&
          grams == other.grams &&
          timestamp.isAtSameMomentAs(other.timestamp);

  @override
  int get hashCode => Object.hash(grams, timestamp.millisecondsSinceEpoch);

  @override
  String toString() =>
      'CupWeightReading(grams: ${grams}g, timestamp: $timestamp)';
}
