import 'package:flutter/foundation.dart';

/// State of physical/wireless connection to the coaster hardware.
enum ConnectionStatus {
  /// Connected and receiving packets from the coaster.
  connected,

  /// Connecting or reconnecting in progress.
  connecting,

  /// Disconnected from coaster hardware.
  disconnected,
}

/// Represents the connection lifecycle and heartbeat of the coaster device.
///
/// **Units & Semantics**:
/// - [status]: Current link status ([ConnectionStatus]).
/// - [lastSeen]: Timestamp of last valid packet/heartbeat from coaster, in **UTC**.
///   Null if never connected in this session.
@immutable
class CoasterConnection {
  const CoasterConnection({required this.status, this.lastSeen});

  /// Current connection state.
  final ConnectionStatus status;

  /// Timestamp in UTC of the most recent valid packet or heartbeat.
  final DateTime? lastSeen;

  bool get isConnected => status == ConnectionStatus.connected;

  CoasterConnection copyWith({ConnectionStatus? status, DateTime? lastSeen}) {
    return CoasterConnection(
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoasterConnection &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          (lastSeen == null && other.lastSeen == null ||
              (lastSeen != null &&
                  other.lastSeen != null &&
                  lastSeen!.isAtSameMomentAs(other.lastSeen!)));

  @override
  int get hashCode => Object.hash(status, lastSeen?.millisecondsSinceEpoch);

  @override
  String toString() =>
      'CoasterConnection(status: $status, lastSeen: $lastSeen)';
}
