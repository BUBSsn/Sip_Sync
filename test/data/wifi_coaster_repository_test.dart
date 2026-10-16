import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/data/local/sqlite_history_repository.dart';
import 'package:liquid_store/data/local/preferences_settings_repository.dart';
import 'package:liquid_store/presentation/view_models/hydration_view_model.dart';
import 'package:liquid_store/data/wifi/wifi_coaster_repository.dart';
import 'package:liquid_store/domain/domain.dart';

Future<void> until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Expected protocol transition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  sqfliteFfiInit();
  late HttpServer server;
  late WifiCoasterRepository repository;
  late WebSocket peer;
  late List<Map<String, dynamic>> received;
  late List<SipEvent> published;
  late Set<String> saved;
  Future<bool> Function(SipEvent)? saveOverride;
  Future<({int totalMl, int throughSequence})> Function(String)?
  progressOverride;
  int sessions = 0;
  Map<String, Object?> packet(
    String type, [
    Map<String, Object?> fields = const {},
  ]) => {'type': type, 'protocol': 1, 'device_id': 'coaster-1', ...fields};
  void send(Map<String, Object?> value) => peer.add(jsonEncode(value));
  void sendSip([String id = '1', int volume = 120]) => send(
    packet('sip', {
      'event_id': id,
      'volume_ml': volume,
      'unix_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
      'time_estimated': false,
    }),
  );
  setUp(() async {
    received = [];
    published = [];
    saved = {};
    saveOverride = null;
    progressOverride = null;
    sessions = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      peer = await WebSocketTransformer.upgrade(request);
      sessions++;
      peer.listen((data) {
        final message = jsonDecode(data as String) as Map<String, dynamic>;
        received.add(message);
        if (message['type'] == 'hello') {
          send(packet('hello', {'empty_g': 258, 'safe_g': 655}));
        }
        if (message['type'] == 'ping') send(packet('pong'));
      });
    });
    repository = WifiCoasterRepository(
      endpoint: Uri.parse('ws://127.0.0.1:${server.port}'),
      retryDelay: const Duration(milliseconds: 30),
      readDailyProgress: (id) async => progressOverride == null
          ? (totalMl: 0, throughSequence: 0)
          : await progressOverride!(id),
      saveSip: (sip) async =>
          saveOverride != null ? await saveOverride!(sip) : saved.add(sip.id),
    );
    repository.sipStream.listen(published.add);
    await repository.connect();
    await until(() => repository.currentConnection.isConnected);
  });
  tearDown(() async {
    await repository.dispose();
    await peer.close();
    await server.close(force: true);
  });
  test(
    'Wi-Fi sip updates saved history and gauge, including after restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = PreferencesSettingsRepository(
        await SharedPreferences.getInstance(),
      );
      final directory = await Directory.systemTemp.createTemp('coaster_e2e_');
      Future<SqliteHistoryRepository> open() => SqliteHistoryRepository.open(
        settings: settings,
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/history.db',
      );
      var history = await open();
      ProviderContainer scope() => ProviderContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(history),
          settingsRepositoryProvider.overrideWithValue(settings),
          coasterRepositoryProvider.overrideWithValue(repository),
        ],
      );
      var container = scope();
      try {
        saveOverride = (sip) => history.recordHardwareSip(sip);
        progressOverride = history.deviceProgress;
        expect(container.read(hydrationViewModelProvider).currentMl, 0);
        sendSip();
        await until(
          () => container.read(hydrationViewModelProvider).currentMl == 120,
        );
        await until(() => received.any((m) => m['type'] == 'ack'));
        final canonical = received.lastWhere(
          (m) => m['type'] == 'daily_progress',
        );
        expect(canonical['total_ml'], 120);
        expect(canonical['through_sequence'], 1);
        expect(
          received.indexOf(canonical),
          lessThan(received.indexWhere((m) => m['type'] == 'ack')),
        );
        expect(history.currentTodaySips.single.volumeMl, 120);
        expect(history.currentSummaries.single.totalMl, 120);
        container.dispose();
        await history.dispose();
        history = await open();
        progressOverride = history.deviceProgress;
        container = scope();
        expect(container.read(hydrationViewModelProvider).currentMl, 120);
        sendSip();
        await until(
          () => received.where((m) => m['type'] == 'ack').length == 2,
        );
        expect(history.currentTodaySips.length, 1);
        expect(container.read(hydrationViewModelProvider).currentMl, 120);
      } finally {
        container.dispose();
        await history.dispose();
        settings.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'validates fixed-cup handshake and delivers live hardware state',
    () async {
      expect(received.any((m) => m['type'] == 'time_sync'), true);
      send(
        packet('status', {
          'state': 'filling',
          'weight_g': 450.5,
          'cup_present': true,
          'pump_running': true,
          'fault': null,
        }),
      );
      await until(() => repository.currentStatus.pumpRunning);
      expect(repository.lastReading!.grams, 450.5);
      expect(repository.currentStatus.deviceId, 'coaster-1');
    },
  );
  test(
    'acknowledges only after save and publishes one event on duplicate replay',
    () async {
      final committed = Completer<bool>();
      saveOverride = (_) => committed.future;
      sendSip();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(received.where((m) => m['type'] == 'ack'), isEmpty);
      expect(published, isEmpty);
      committed.complete(true);
      await until(() => published.length == 1);
      await until(() => received.any((m) => m['type'] == 'ack'));
      saveOverride = (_) async => false;
      sendSip();
      await until(() => received.where((m) => m['type'] == 'ack').length == 2);
      expect(published.length, 1);
    },
  );
  test(
    'save failure leaves event unacknowledged and replay retries successfully',
    () async {
      saveOverride = (_) async => throw StateError('Storage unavailable');
      sendSip();
      await until(() => repository.currentStatus.message != null);
      expect(received.where((m) => m['type'] == 'ack'), isEmpty);
      saveOverride = null;
      sendSip();
      await until(() => published.length == 1);
      expect(saved, {'coaster-1:1'});
    },
  );
  test('daily progress sends the canonical total and local offset', () async {
    progressOverride = (_) async => (totalMl: 450, throughSequence: 8);
    await repository.syncDailyProgress();
    await until(
      () => received.any(
        (m) => m['type'] == 'daily_progress' && m['total_ml'] == 450,
      ),
    );
    final snapshot = received.lastWhere((m) => m['type'] == 'daily_progress');
    expect(snapshot['through_sequence'], 8);
    expect(
      snapshot['utc_offset_minutes'],
      DateTime.now().timeZoneOffset.inMinutes,
    );
    progressOverride = (_) async => (totalMl: 0, throughSequence: 8);
    await repository.syncDailyProgress();
    await until(
      () =>
          received.last['type'] == 'daily_progress' &&
          received.last['total_ml'] == 0,
    );
  });

  test('invalid and foreign packets cannot change intake', () async {
    peer.add('{broken');
    sendSip('negative', -1);
    sendSip('too-large', 500);
    send({
      ...packet('sip'),
      'device_id': 'another-device',
      'event_id': 'x',
      'volume_ml': 100,
      'unix_ms': DateTime.now().millisecondsSinceEpoch,
      'time_estimated': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(saved, isEmpty);
    expect(published, isEmpty);
  });
  test(
    'connection loss clears stale weight and reconnects without replay feedback',
    () async {
      sendSip();
      await until(() => published.length == 1);
      send(
        packet('status', {
          'state': 'resting',
          'weight_g': 550,
          'cup_present': true,
          'pump_running': false,
          'fault': null,
        }),
      );
      await until(() => repository.lastReading != null);
      await peer.close();
      await until(
        () => sessions == 2 && repository.currentConnection.isConnected,
      );
      expect(repository.lastReading, isNull);
      sendSip();
      await until(() => received.where((m) => m['type'] == 'ack').length == 2);
      expect(published.length, 1);
    },
  );
}
