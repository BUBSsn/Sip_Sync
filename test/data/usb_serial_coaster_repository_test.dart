import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/usb/usb_serial_coaster_repository.dart';
import 'package:liquid_store/domain/domain.dart';

void main() {
  group('UsbSerialCoasterRepository', () {
    late UsbSerialCoasterRepository repo;

    setUp(() {
      repo = UsbSerialCoasterRepository(baudRate: 115200);
    });

    tearDown(() {
      repo.dispose();
    });

    test('initial state is disconnected and empty', () {
      expect(repo, isA<CoasterRepository>());
      expect(repo.baudRate, 115200);
      expect(repo.isUsbConnected, isFalse);
      expect(repo.currentConnection.status, ConnectionStatus.disconnected);
      expect(repo.lastReading, isNull);
    });

    test('non-web stub connectUsb returns false gracefully', () async {
      final result = await repo.connectUsb();
      expect(result, isFalse);
      expect(repo.isUsbConnected, isFalse);
    });

    test(
      'non-web stub calibrate reports clear failure without throwing',
      () async {
        final result = await repo.calibrate();
        expect(result.status, CalibrationStatus.failure);
        expect(result.errorMessage, contains('Google Chrome'));
      },
    );

    test('disconnectUsb updates connection status to disconnected', () async {
      await repo.disconnectUsb();
      expect(repo.currentConnection.status, ConnectionStatus.disconnected);
    });

    test(
      'rearmHardware, resetHardwareDrankCount, and sendCommand complete without error',
      () async {
        await expectLater(repo.rearmHardware(), completes);
        await expectLater(repo.resetHardwareDrankCount(), completes);
        await expectLater(repo.sendCommand('1'), completes);
      },
    );
  });
}
