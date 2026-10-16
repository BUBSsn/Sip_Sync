import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/domain.dart';
import '../../domain/models/fixed_cup.dart';

class CoasterStatus {
  const CoasterStatus({
    this.state = 'offline',
    this.pumpRunning = false,
    this.cupPresent = false,
    this.fault,
    this.deviceId,
    this.message,
  });
  final String state;
  final bool pumpRunning;
  final bool cupPresent;
  final String? fault;
  final String? deviceId;
  final String? message;
  String get label => switch (state) {
    'resting' => 'Ready for your next sip',
    'lifted' => 'Cup lifted',
    'settling' => 'Measuring the returned cup',
    'filling' => 'Automatically refilling',
    'no_cup' => 'Place your cup on the coaster',
    'fault' => 'Coaster needs attention',
    _ => 'Join the coaster Wi-Fi to connect',
  };
}

/// Saves validated device events before publishing feedback or acknowledging.
/// Firmware replays unacknowledged IDs; the database is the deduplication owner.
class WifiCoasterRepository implements CoasterRepository {
  WifiCoasterRepository({
    required this.saveSip,
    this.readDailyProgress,
    Uri? endpoint,
    WebSocketChannel Function(Uri)? channelFactory,
    this.retryDelay,
    this.heartbeatTimeout = const Duration(seconds: 12),
  }) : endpoint = endpoint ?? Uri.parse('ws://192.168.4.1:81'),
       _channelFactory = channelFactory ?? WebSocketChannel.connect;
  final Future<bool> Function(SipEvent) saveSip;
  final Future<({int totalMl, int throughSequence})> Function(String deviceId)?
  readDailyProgress;
  Future<void> _pendingProgress = Future.value();
  DateTime? _lastProgressAt;
  final Uri endpoint;
  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration? retryDelay;
  final Duration heartbeatTimeout;
  final _sips = StreamController<SipEvent>.broadcast();
  final _weights = StreamController<CupWeightReading>.broadcast();
  final _connections = StreamController<CoasterConnection>.broadcast();
  final _statuses = StreamController<CoasterStatus>.broadcast();
  CoasterConnection _connection = const CoasterConnection(
    status: ConnectionStatus.disconnected,
  );
  CoasterStatus _status = const CoasterStatus();
  CupWeightReading? _reading;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _heartbeat;
  int _generation = 0;
  int _attempts = 0;
  bool _wanted = false;
  bool _disposed = false;
  String? _deviceId;
  String? _saveError;
  DateTime? _lastPacket;
  Future<void> _pendingEvents = Future.value();
  @override
  Stream<SipEvent> get sipStream => _sips.stream;
  @override
  Stream<CupWeightReading> get weightStream => _weights.stream;
  @override
  Stream<CoasterConnection> get connectionStream => _connections.stream;
  @override
  CoasterConnection get currentConnection => _connection;
  @override
  CupWeightReading? get lastReading => _reading;
  CoasterStatus get currentStatus => _status;
  Stream<CoasterStatus> get statusStream => _statuses.stream;

  void _setStatus(CoasterStatus value) {
    if (_disposed) return;
    _status = value;
    _statuses.add(value);
  }

  void _setConnection(ConnectionStatus status) {
    if (_disposed) return;
    _connection = CoasterConnection(status: status, lastSeen: _lastPacket);
    _connections.add(_connection);
  }

  void _send(Map<String, Object?> message) {
    if (!_disposed && _channel != null) _channel!.sink.add(jsonEncode(message));
  }

  /// Serialize snapshots and send them before acknowledgements. The device can
  /// then add only pending events newer than the database watermark.
  Future<void> syncDailyProgress() {
    final generation = _generation;
    final operation = _pendingProgress.then((_) async {
      final reader = readDailyProgress, id = _deviceId;
      if (_disposed ||
          reader == null ||
          id == null ||
          !_connection.isConnected ||
          generation != _generation) {
        return;
      }
      final progress = await reader(id);
      if (_disposed || generation != _generation) return;
      final now = DateTime.now();
      _send({
        'type': 'daily_progress',
        'unix_ms': now.toUtc().millisecondsSinceEpoch,
        'utc_offset_minutes': now.timeZoneOffset.inMinutes,
        'total_ml': progress.totalMl,
        'through_sequence': progress.throughSequence,
      });
      _lastProgressAt = now;
    });
    _pendingProgress = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> connect() async {
    if (_disposed) return;
    _wanted = true;
    _retry?.cancel();
    if (_channel != null) return;
    final generation = ++_generation;
    _deviceId = null;
    _lastPacket = DateTime.now().toUtc();
    _setConnection(ConnectionStatus.connecting);
    try {
      final channel = _channelFactory(endpoint);
      _channel = channel;
      _subscription = channel.stream.listen(
        (data) => _receive(data, generation),
        onError: (Object _) => _lost(generation),
        onDone: () => _lost(generation),
      );
      await channel.ready.timeout(const Duration(seconds: 8));
      if (_disposed || generation != _generation) return;
      _send({'type': 'hello', 'protocol': 1});
      _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
        if (DateTime.now().toUtc().difference(_lastPacket!) >
            heartbeatTimeout) {
          _lost(generation);
        } else {
          _send({'type': 'ping'});
          if (_lastProgressAt == null ||
              DateTime.now().difference(_lastProgressAt!) >
                  const Duration(seconds: 30)) {
            unawaited(syncDailyProgress().catchError((Object _) {}));
          }
        }
      });
    } catch (_) {
      _lost(generation);
    }
  }

  void _receive(dynamic data, int generation) {
    if (_disposed ||
        generation != _generation ||
        data is! String ||
        data.length > 4096) {
      return;
    }
    try {
      final packet = jsonDecode(data);
      if (packet is! Map<String, dynamic> || packet['protocol'] != 1) return;
      final id = packet['device_id'];
      if (id is! String || id.isEmpty || id.length > 64) return;
      if (packet['type'] == 'hello') {
        if (packet['empty_g'] != FixedCup.emptyGrams ||
            packet['safe_g'] != FixedCup.safeFilledGrams) {
          return;
        }
        _deviceId = id;
        _attempts = 0;
        _lastPacket = DateTime.now().toUtc();
        _setConnection(ConnectionStatus.connected);
        _setStatus(CoasterStatus(deviceId: id));
        _send({
          'type': 'time_sync',
          'unix_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
        });
        unawaited(syncDailyProgress().catchError((Object _) {}));
        return;
      }
      if (id != _deviceId) return;
      switch (packet['type']) {
        case 'status':
          final grams = packet['weight_g'];
          final state = packet['state'];
          final pump = packet['pump_running'];
          final cup = packet['cup_present'];
          final fault = packet['fault'];
          if (grams is! num ||
              !grams.isFinite ||
              grams < -20 ||
              grams > 2000 ||
              ![
                'resting',
                'lifted',
                'settling',
                'filling',
                'no_cup',
                'fault',
              ].contains(state) ||
              pump is! bool ||
              cup is! bool ||
              (fault != null && fault is! String)) {
            return;
          }
          _reading = CupWeightReading(
            grams: max(0, grams.toDouble()),
            timestamp: DateTime.now().toUtc(),
          );
          _weights.add(_reading!);
          _setStatus(
            CoasterStatus(
              state: state,
              pumpRunning: pump,
              cupPresent: cup,
              fault: fault as String?,
              deviceId: id,
              message: _saveError,
            ),
          );
        case 'sip':
          final eventId = packet['event_id'];
          final volume = packet['volume_ml'];
          final unix = packet['unix_ms'];
          final estimated = packet['time_estimated'];
          if (eventId is! String ||
              eventId.isEmpty ||
              eventId.length > 128 ||
              volume is! int ||
              volume < 5 ||
              volume > FixedCup.maxSipMl ||
              unix is! int ||
              estimated is! bool) {
            return;
          }
          final now = DateTime.now().toUtc();
          if (unix < 1577836800000 ||
              unix > now.millisecondsSinceEpoch + 60000) {
            return;
          }
          final sip = SipEvent(
            id: '$id:$eventId',
            volumeMl: volume,
            timestamp: DateTime.fromMillisecondsSinceEpoch(unix, isUtc: true),
            timestampEstimated: estimated,
          );
          _pendingEvents = _pendingEvents.then((_) async {
            if (_disposed) return;
            try {
              final inserted = await saveSip(sip);
              if (_disposed) return;
              await syncDailyProgress();
              _saveError = null;
              _setStatus(
                CoasterStatus(
                  state: _status.state,
                  pumpRunning: _status.pumpRunning,
                  cupPresent: _status.cupPresent,
                  fault: _status.fault,
                  deviceId: id,
                ),
              );
              if (inserted) _sips.add(sip);
              if (generation == _generation) {
                _send({'type': 'ack', 'event_id': eventId});
              }
            } catch (_) {
              _saveError =
                  'Could not save a sip. The coaster will retry; keep this app open.';
              _setStatus(
                CoasterStatus(
                  state: _status.state,
                  pumpRunning: _status.pumpRunning,
                  cupPresent: _status.cupPresent,
                  fault: _status.fault,
                  deviceId: id,
                  message: _saveError,
                ),
              );
            }
          });
        case 'pong':
          break;
        default:
          return;
      }
      _lastPacket = DateTime.now().toUtc();
      _setConnection(ConnectionStatus.connected);
    } on FormatException {
      /* Incomplete or invalid packets never alter records. */
    }
  }

  Future<void> _closeChannel(WebSocketChannel? channel) async {
    try {
      await channel?.sink.close();
    } catch (_) {
      /* already disconnected */
    }
  }

  void _lost(int generation) {
    if (_disposed || generation != _generation) return;
    ++_generation;
    _heartbeat?.cancel();
    _subscription?.cancel();
    _subscription = null;
    unawaited(_closeChannel(_channel));
    _channel = null;
    _reading = null;
    _weights.add(CupWeightReading(grams: 0, timestamp: DateTime.now().toUtc()));
    _setStatus(const CoasterStatus());
    _setConnection(ConnectionStatus.disconnected);
    if (_wanted) {
      final delay =
          retryDelay ?? Duration(seconds: min(30, 1 << min(_attempts++, 5)));
      _retry = Timer(delay, connect);
    }
  }

  Future<void> disconnect() async {
    _wanted = false;
    _retry?.cancel();
    _lost(_generation);
  }

  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  @override
  Future<CalibrationResult> calibrate({
    Duration timeout = const Duration(seconds: 10),
  }) async => CalibrationResult(
    status: CalibrationStatus.failure,
    timestamp: DateTime.now().toUtc(),
    errorMessage:
        'This coaster uses a fixed 258 g cup. Zero the empty coaster using the hardware startup procedure.',
  );
  Future<void> dispose() async {
    await disconnect();
    _disposed = true;
    await _pendingEvents;
    await _pendingProgress;
    await _sips.close();
    await _weights.close();
    await _connections.close();
    await _statuses.close();
  }
}
