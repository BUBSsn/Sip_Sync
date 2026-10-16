import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';

/// Presentation state for coaster hardware connectivity.
@immutable
class ConnectionViewState {
  const ConnectionViewState({required this.connection});

  final CoasterConnection connection;

  bool get isConnected => connection.isConnected;
  ConnectionStatus get status => connection.status;
  DateTime? get lastSeen => connection.lastSeen;

  String get label {
    switch (connection.status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionViewState &&
          runtimeType == other.runtimeType &&
          connection == other.connection;

  @override
  int get hashCode => connection.hashCode;

  @override
  String toString() => 'ConnectionViewState($label)';
}

/// Reactive ViewModel for coaster connection state changes.
class ConnectionViewModel extends StateNotifier<ConnectionViewState> {
  ConnectionViewModel({required this.coasterRepository})
    : super(
        ConnectionViewState(connection: coasterRepository.currentConnection),
      ) {
    _init();
  }

  final CoasterRepository coasterRepository;
  StreamSubscription<CoasterConnection>? _sub;

  void _init() {
    _sub = coasterRepository.connectionStream.listen((conn) {
      if (!mounted) return;
      state = ConnectionViewState(connection: conn);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider exposing [ConnectionViewState].
final connectionViewModelProvider =
    StateNotifierProvider<ConnectionViewModel, ConnectionViewState>((ref) {
      final coasterRepo = ref.watch(coasterRepositoryProvider);
      return ConnectionViewModel(coasterRepository: coasterRepo);
    }, dependencies: [coasterRepositoryProvider]);
