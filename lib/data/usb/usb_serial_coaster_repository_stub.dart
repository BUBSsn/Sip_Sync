import 'dart:async';
import '../../domain/domain.dart';
import 'usb_serial_coaster_repository.dart';

/// Non-web fallback stub for UsbSerialCoasterRepository.
/// On platforms other than Web (or in headless test runners), this stub
/// provides a safe placeholder that throws or emulates disconnection.
class UsbSerialCoasterRepositoryImpl implements UsbSerialCoasterRepository {
  UsbSerialCoasterRepositoryImpl({this.baudRate = 115200});

  @override
  final int baudRate;

  final _sipController = StreamController<SipEvent>.broadcast();
  final _weightController = StreamController<CupWeightReading>.broadcast();
  final _connectionController = StreamController<CoasterConnection>.broadcast();
  final _faultController = StreamController<String?>.broadcast();
  final _pumpRunningController = StreamController<bool>.broadcast();

  CoasterConnection _currentConnection = const CoasterConnection(
    status: ConnectionStatus.disconnected,
  );
  CupWeightReading? _lastReading;

  @override
  Stream<SipEvent> get sipStream => _sipController.stream;

  @override
  Stream<CupWeightReading> get weightStream => _weightController.stream;

  @override
  Stream<CoasterConnection> get connectionStream =>
      _connectionController.stream;

  @override
  Stream<String?> get faultStream => _faultController.stream;

  @override
  Stream<bool> get pumpRunningStream => _pumpRunningController.stream;

  @override
  CoasterConnection get currentConnection => _currentConnection;

  @override
  CupWeightReading? get lastReading => _lastReading;

  @override
  bool get isUsbConnected => false;

  @override
  Future<bool> connectUsb() async {
    // Stub on non-web platform
    return false;
  }

  @override
  Future<void> disconnectUsb() async {
    _currentConnection = _currentConnection.copyWith(
      status: ConnectionStatus.disconnected,
    );
    _connectionController.add(_currentConnection);
  }

  @override
  Future<void> sendCommand(String cmd) async {}

  @override
  Future<void> rearmHardware() async {}

  @override
  Future<void> resetHardwareDrankCount() async {}

  @override
  Future<CalibrationResult> calibrate({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return CalibrationResult(
      status: CalibrationStatus.failure,
      timestamp: DateTime.now().toUtc(),
      errorMessage: 'USB Serial is only available in Google Chrome (Web)',
    );
  }

  @override
  void dispose() {
    _sipController.close();
    _weightController.close();
    _connectionController.close();
    _faultController.close();
    _pumpRunningController.close();
  }
}
