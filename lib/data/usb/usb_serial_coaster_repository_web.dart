import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:webserial/webserial.dart';

import '../../domain/domain.dart';
import 'usb_serial_coaster_repository.dart';

/// Production Web Serial Coaster Repository for Google Chrome.
/// Directly bridges ESP32 Smart Water Coaster hardware over USB serial.
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

  JSSerialPort? _port;
  web.ReadableStreamDefaultReader? _reader;
  web.WritableStreamDefaultWriter? _writer;
  bool _isReading = false;

  // Onboard sip detection & calibration state
  // Default matches MCU firmware EMPTY_CUP_WEIGHT = 258.0g
  double _cupTareGrams = 258.0;
  double _baselineGrams = 258.0;
  bool _cupLifted = false;
  int? _lastReportedDrankMl;

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
  bool get isUsbConnected =>
      _port != null && _currentConnection.status == ConnectionStatus.connected;

  @override
  Future<bool> connectUsb() async {
    try {
      final port = await requestWebSerialPort(null);
      if (port == null) {
        return false;
      }

      await port
          .open(
            JSSerialOptions(
              baudRate: baudRate,
              dataBits: 8,
              stopBits: 1,
              parity: 'none',
              bufferSize: 1024,
              flowControl: 'none',
            ),
          )
          .toDart;

      _port = port;
      _currentConnection = _currentConnection.copyWith(
        status: ConnectionStatus.connected,
        lastSeen: DateTime.now().toUtc(),
      );
      _connectionController.add(_currentConnection);

      _startReadLoop();
      return true;
    } catch (e, stack) {
      debugPrint('[UsbSerial] Error connecting to USB port: $e\n$stack');
      _currentConnection = _currentConnection.copyWith(
        status: ConnectionStatus.disconnected,
      );
      _connectionController.add(_currentConnection);
      return false;
    }
  }

  void _startReadLoop() async {
    if (_port == null || _port!.readable == null) return;
    _isReading = true;

    try {
      _reader = _port!.readable!.getReader() as web.ReadableStreamDefaultReader;
      final buffer = StringBuffer();

      while (_isReading && _port != null) {
        final result = await _reader!.read().toDart;
        if (result.done) break;

        final chunk = result.value;
        if (chunk != null) {
          final uint8List = (chunk as JSUint8Array).toDart;
          final text = utf8.decode(uint8List, allowMalformed: true);
          buffer.write(text);

          var content = buffer.toString();
          while (content.contains('\n')) {
            final newlineIdx = content.indexOf('\n');
            final line = content.substring(0, newlineIdx).trim();
            content = content.substring(newlineIdx + 1);
            if (line.isNotEmpty) {
              _processSerialLine(line);
            }
          }
          buffer.clear();
          buffer.write(content);
        }
      }
    } catch (e) {
      debugPrint('[UsbSerial] Read loop error/disconnect: $e');
    } finally {
      await disconnectUsb();
    }
  }

  /// Parses incoming telemetry line from ESP32 Smart Coaster firmware
  void _processSerialLine(String line) {
    // 1. Firmware telemetry format: "[WEIGHT]  258.0 g"
    final weightBracketMatch = RegExp(
      r'\[WEIGHT\]\s*([\d\.\-]+)\s*g?',
      caseSensitive: false,
    ).firstMatch(line);
    if (weightBracketMatch != null) {
      final g = double.tryParse(weightBracketMatch.group(1)!);
      if (g != null) {
        _handleWeight(g);
        return;
      }
    }

    // 2. Firmware drink detection format: "-> [DRINK] Detected. Total today: 45 ml"
    final drinkMatch = RegExp(
      r'\[DRINK\]\s*Detected\.\s*Total today:\s*([\d\.]+)\s*ml',
      caseSensitive: false,
    ).firstMatch(line);
    if (drinkMatch != null) {
      final totalMl = double.tryParse(drinkMatch.group(1)!)?.round() ?? 0;
      if (_lastReportedDrankMl == null) {
        _lastReportedDrankMl = totalMl;
        if (totalMl > 0) _emitSip(totalMl);
      } else if (totalMl > _lastReportedDrankMl!) {
        final deltaMl = totalMl - _lastReportedDrankMl!;
        _lastReportedDrankMl = totalMl;
        _emitSip(deltaMl);
      }
      return;
    }

    // 3. Firmware pump status: "[PUMP]    RUNNING" / "STOPPED"
    if (line.contains('[PUMP]')) {
      final isRunning = line.toUpperCase().contains('RUNNING');
      _pumpRunningController.add(isRunning);
      return;
    }

    // 4. Firmware fault status: "[FAULT]   none" / "SPILL (rearm required)"
    if (line.contains('[FAULT]')) {
      final upper = line.toUpperCase();
      if (upper.contains('SPILL')) {
        _faultController.add('SPILL');
      } else if (upper.contains('TIMEOUT')) {
        _faultController.add('PUMP TIMEOUT');
      } else if (upper.contains('NONE')) {
        _faultController.add(null);
      }
      return;
    }

    // 5. Firmware spill alert: ">>> [SPILL ALERT] Liquid detected!"
    if (line.contains('[SPILL ALERT]')) {
      _faultController.add('SPILL');
      return;
    }

    // 6. Firmware rearm cleared: "-> [REARM] Cleared fault"
    if (line.contains('[REARM]')) {
      _faultController.add(null);
      return;
    }

    // 7. Fallback prefix formats: "W: 250.4", "SIP: 45", "TARE: 258.0"
    final upper = line.toUpperCase();
    if (upper.startsWith('SIP:') || upper.startsWith('SIP ')) {
      final valStr = line
          .split(RegExp(r'[: ]+'))
          .last
          .replaceAll(RegExp(r'[^\d]'), '');
      final ml = int.tryParse(valStr);
      if (ml != null && ml > 0) {
        _emitSip(ml);
        return;
      }
    }

    if (upper.startsWith('W:') ||
        upper.startsWith('WEIGHT:') ||
        upper.startsWith('G:')) {
      final valStr = line
          .split(RegExp(r'[: ]+'))
          .last
          .replaceAll(RegExp(r'[^\d\.\-]'), '');
      final g = double.tryParse(valStr);
      if (g != null) {
        _handleWeight(g);
        return;
      }
    }

    // 8. Plain numeric reading (e.g. "258.0")
    final plainNum = double.tryParse(line.replaceAll(RegExp(r'[^\d\.\-]'), ''));
    if (plainNum != null) {
      _handleWeight(plainNum);
    }
  }

  void _handleWeight(double grams) {
    final reading = CupWeightReading(
      grams: grams,
      timestamp: DateTime.now().toUtc(),
    );
    _lastReading = reading;
    _weightController.add(reading);

    // Keep connection heartbeat fresh
    _currentConnection = _currentConnection.copyWith(
      status: ConnectionStatus.connected,
      lastSeen: DateTime.now().toUtc(),
    );
    _connectionController.add(_currentConnection);

    // Client-side fallback drink detection only if MCU drink events are not reporting
    if (_lastReportedDrankMl == null) {
      if (_baselineGrams == 0.0) {
        _baselineGrams = grams;
        return;
      }

      // Pick-up detection: load drops below Tare - 10g or near 0g
      if (grams < (_cupTareGrams - 10.0) || grams < 15.0) {
        _cupLifted = true;
        return;
      }

      // Set-down detection: cup returned to coaster
      if (_cupLifted && grams >= (_cupTareGrams - 10.0)) {
        _cupLifted = false;
        final delta = _baselineGrams - grams;

        // Refill event (> +15g): fresh water poured
        if (delta < -15.0) {
          _baselineGrams = grams;
          return;
        }

        // Noise deadband (+/- 5g)
        if (delta.abs() <= 5.0) {
          _baselineGrams = grams;
          return;
        }

        // Valid sip consumed!
        if (delta > 5.0) {
          final volumeMl = delta.round();
          _baselineGrams = grams;
          _emitSip(volumeMl);
        }
      }
    }
  }

  void _emitSip(int volumeMl) {
    if (volumeMl <= 0) return;
    _sipController.add(
      SipEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        volumeMl: volumeMl,
        timestamp: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> sendCommand(String cmd) async {
    if (_port != null && _port!.writable != null) {
      try {
        _writer = _port!.writable!.getWriter();
        final bytes = utf8.encode(cmd);
        await _writer!.write(bytes.toJS).toDart;
        _writer!.releaseLock();
      } catch (e) {
        debugPrint('[UsbSerial] Error sending command "$cmd": $e');
      }
    }
  }

  @override
  Future<void> rearmHardware() async {
    await sendCommand('r\n');
    _faultController.add(null);
  }

  @override
  Future<void> resetHardwareDrankCount() async {
    await sendCommand('z\n');
    _lastReportedDrankMl = 0;
  }

  @override
  Future<CalibrationResult> calibrate({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final taredGrams = _lastReading?.grams ?? 258.0;
    _cupTareGrams = taredGrams;
    _baselineGrams = taredGrams;
    return CalibrationResult(
      status: CalibrationStatus.success,
      measuredGrams: taredGrams,
      timestamp: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> disconnectUsb() async {
    _isReading = false;
    try {
      _reader?.releaseLock();
      _reader = null;
      _writer = null;
      if (_port != null) {
        await _port!.close().toDart;
        _port = null;
      }
    } catch (_) {}

    _currentConnection = _currentConnection.copyWith(
      status: ConnectionStatus.disconnected,
    );
    _connectionController.add(_currentConnection);
  }

  @override
  void dispose() {
    disconnectUsb();
    _sipController.close();
    _weightController.close();
    _connectionController.close();
    _faultController.close();
    _pumpRunningController.close();
  }
}
