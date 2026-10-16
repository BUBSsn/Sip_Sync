import '../../domain/domain.dart';
import 'usb_serial_coaster_repository_stub.dart'
    if (dart.library.js_interop) 'usb_serial_coaster_repository_web.dart';

/// Contract and entry point for Web Serial USB Coaster hardware in Google Chrome.
/// Directly interfaces with the ESP32 Smart Water Coaster firmware.
abstract class UsbSerialCoasterRepository implements CoasterRepository {
  factory UsbSerialCoasterRepository({int baudRate}) =
      UsbSerialCoasterRepositoryImpl;

  int get baudRate;

  /// Requests the user to pick a serial port via Chrome's native prompt.
  /// Must be invoked from a user gesture (button tap).
  Future<bool> connectUsb();

  /// Disconnects from the serial port.
  Future<void> disconnectUsb();

  /// Whether currently connected to a USB port.
  bool get isUsbConnected;

  /// Sends a raw character/string command to the microcontroller over serial.
  Future<void> sendCommand(String cmd);

  /// Sends 'r' to rearm and clear latched faults (SPILL or PUMP TIMEOUT).
  Future<void> rearmHardware();

  /// Sends 'z' to reset microcontroller drankMl counter to 0.
  Future<void> resetHardwareDrankCount();

  /// Stream of hardware fault alerts ('SPILL', 'PUMP TIMEOUT', or null when normal).
  Stream<String?> get faultStream;

  /// Stream of whether the refill pump is actively running on the coaster.
  Stream<bool> get pumpRunningStream;

  /// Disposes internal streams and closes the port.
  void dispose();
}
