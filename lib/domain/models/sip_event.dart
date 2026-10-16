import 'package:flutter/foundation.dart';

/// Represents a discrete drinking event recorded by the coaster scale.
///
/// **Units & Semantics**:
/// - [id]: Unique string identifier for deduplication and persistence.
/// - [volumeMl]: Liquid volume consumed in milliliters (`ml`). Strictly positive integer.
/// - [timestamp]: Moment the sip concluded, stored and transmitted in **UTC**.
///   Presentation widgets should convert to local time via [DateTime.toLocal].
@immutable
class SipEvent {
  const SipEvent({
    required this.id,
    required this.volumeMl,
    required this.timestamp,
    this.timestampEstimated = false,
  }) : assert(volumeMl > 0, 'Volume in ml must be strictly positive');

  /// Unique event ID.
  final String id;

  /// Volume of water consumed in milliliters (ml).
  final int volumeMl;

  /// Timestamp of the event in UTC.
  final DateTime timestamp;

  /// True if an offline event predates a device clock sync or power restart.
  final bool timestampEstimated;

  /// Returns a copy of this [SipEvent] with updated fields.
  SipEvent copyWith({
    String? id,
    int? volumeMl,
    DateTime? timestamp,
    bool? timestampEstimated,
  }) {
    return SipEvent(
      id: id ?? this.id,
      volumeMl: volumeMl ?? this.volumeMl,
      timestamp: timestamp ?? this.timestamp,
      timestampEstimated: timestampEstimated ?? this.timestampEstimated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SipEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          volumeMl == other.volumeMl &&
          timestampEstimated == other.timestampEstimated &&
          timestamp.isAtSameMomentAs(other.timestamp);

  @override
  int get hashCode =>
      Object.hash(id, volumeMl, timestamp.millisecondsSinceEpoch);

  @override
  String toString() =>
      'SipEvent(id: $id, volumeMl: ${volumeMl}ml, timestamp: $timestamp)';
}
