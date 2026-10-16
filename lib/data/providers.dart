import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/domain.dart';
import 'fake/fake_coaster_repository.dart';
import 'local/sqlite_history_repository.dart';
import 'wifi/wifi_coaster_repository.dart';

import 'usb/usb_serial_coaster_repository.dart';

/// Configurable USB baud rate. Defaults to 115200 (standard for microcontroller serial).
final usbBaudRateProvider = StateProvider<int>((ref) => 115200);

/// Tracks whether physical USB serial hardware is active or developer fake is used.
final isUsbHardwareActiveProvider = StateProvider<bool>((ref) {
  return const bool.fromEnvironment('USE_USB_HARDWARE', defaultValue: false);
});

/// Direct instance provider for [UsbSerialCoasterRepository].
final usbSerialCoasterRepositoryProvider = Provider<UsbSerialCoasterRepository>(
  (ref) {
    final baudRate = ref.watch(usbBaudRateProvider);
    final repository = UsbSerialCoasterRepository(baudRate: baudRate);
    ref.onDispose(repository.dispose);
    return repository;
  },
);

/// Direct instance provider for [FakeCoasterRepository].
final fakeCoasterRepositoryProvider = Provider<FakeCoasterRepository>((ref) {
  final repository = FakeCoasterRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Production transport; test fakes must be explicitly injected.
final coasterRepositoryProvider = Provider<CoasterRepository>((ref) {
  final history = ref.watch(historyRepositoryProvider);
  final repository = WifiCoasterRepository(
    readDailyProgress: history is SqliteHistoryRepository
        ? history.deviceProgress
        : null,
    saveSip: (sip) async {
      if (history is SqliteHistoryRepository) {
        return history.recordHardwareSip(sip);
      }
      await history.recordSip(sip);
      return true;
    },
  );
  final updates = history.watchDailySummaries().listen((_) {
    unawaited(repository.syncDailyProgress().catchError((Object _) {}));
  });
  ref.onDispose(updates.cancel);
  ref.onDispose(repository.dispose);
  return repository;
}, dependencies: [historyRepositoryProvider]);

/// Initialized by application startup before screens are created.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw StateError('Settings must be loaded at startup or injected by a test.');
});
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  throw StateError('History must be loaded at startup or injected by a test.');
});

final coasterStatusProvider = StreamProvider<CoasterStatus>((ref) async* {
  final repository = ref.watch(coasterRepositoryProvider);
  if (repository is WifiCoasterRepository) {
    yield repository.currentStatus;
    yield* repository.statusStream;
  } else {
    yield const CoasterStatus();
  }
}, dependencies: [coasterRepositoryProvider]);
