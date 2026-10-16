import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/domain.dart';
import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../widgets/glass_card.dart';

/// Interactive hardware connection card for Google Chrome Web Serial.
/// Allows user to initiate USB connection via browser device picker,
/// choose baud rate, monitor live link status, pump telemetry, and rearm faults.
class UsbHardwareCard extends ConsumerStatefulWidget {
  const UsbHardwareCard({super.key});

  @override
  ConsumerState<UsbHardwareCard> createState() => _UsbHardwareCardState();
}

class _UsbHardwareCardState extends ConsumerState<UsbHardwareCard> {
  bool _isConnecting = false;

  Future<void> _handleConnect() async {
    setState(() => _isConnecting = true);

    try {
      final usbRepo = ref.read(usbSerialCoasterRepositoryProvider);
      final connected = await usbRepo.connectUsb();

      if (connected) {
        ref.read(isUsbHardwareActiveProvider.notifier).state = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.usb, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to USB Coaster (${usbRepo.baudRate} baud)!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00C48C),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('USB pairing cancelled or device not found.'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting to USB device: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    final usbRepo = ref.read(usbSerialCoasterRepositoryProvider);
    await usbRepo.disconnectUsb();
    ref.read(isUsbHardwareActiveProvider.notifier).state = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Disconnected from USB Coaster. Reverted to simulator.',
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRearm() async {
    final usbRepo = ref.read(usbSerialCoasterRepositoryProvider);
    await usbRepo.rearmHardware();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rearm command sent ("r"). Fault cleared.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleResetCounter() async {
    final usbRepo = ref.read(usbSerialCoasterRepositoryProvider);
    await usbRepo.resetHardwareDrankCount();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MCU drink counter reset ("z").'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final isUsbActive = ref.watch(isUsbHardwareActiveProvider);
    final selectedBaud = ref.watch(usbBaudRateProvider);
    final coasterRepo = ref.watch(coasterRepositoryProvider);
    final isConnected =
        coasterRepo.currentConnection.status == ConnectionStatus.connected;
    final usbRepo = ref.watch(usbSerialCoasterRepositoryProvider);

    return GlassCard(
      padding: const EdgeInsets.all(LiquidTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isUsbActive && isConnected
                      ? const Color(0xFF00C48C).withValues(alpha: 0.15)
                      : palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
                ),
                child: Icon(
                  Icons.usb,
                  color: isUsbActive && isConnected
                      ? const Color(0xFF059669)
                      : palette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USB Hardware Connection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUsbActive && isConnected
                          ? 'ESP32 Smart Coaster active via Web Serial'
                          : 'Connect scale board via USB cable in Chrome',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge with scale-down to protect 200% text scaling
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isUsbActive && isConnected
                        ? const Color(0xFFCCFBF1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(
                      LiquidTokens.radiusPill,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isUsbActive && isConnected
                              ? const Color(0xFF00C48C)
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUsbActive && isConnected ? 'USB LIVE' : 'SIMULATOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: isUsbActive && isConnected
                              ? const Color(0xFF059669)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: LiquidTokens.spaceMd),

          if (!isUsbActive || !isConnected) ...[
            // Baud rate selector using Wrap to prevent overflow at 200% text scale
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Baud Rate:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
                DropdownButton<int>(
                  value: selectedBaud,
                  dropdownColor: palette.surface,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: palette.primary,
                  ),
                  items: const [
                    DropdownMenuItem(value: 9600, child: Text('9600 baud')),
                    DropdownMenuItem(value: 38400, child: Text('38400 baud')),
                    DropdownMenuItem(value: 57600, child: Text('57600 baud')),
                    DropdownMenuItem(
                      value: 115200,
                      child: Text('115200 baud (ESP32)'),
                    ),
                  ],
                  onChanged: (newBaud) {
                    if (newBaud != null) {
                      ref.read(usbBaudRateProvider.notifier).state = newBaud;
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: LiquidTokens.spaceSm),

            // Connect Button
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _handleConnect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cable, size: 18),
              label: Text(
                _isConnecting
                    ? 'Waiting for Chrome device selection...'
                    : 'Connect Physical USB Coaster',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
                ),
              ),
            ),
          ] else ...[
            // Connected state details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF059669),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Streaming live telemetry at $selectedBaud baud.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                      Text(
                        '${coasterRepo.lastReading?.grams.toStringAsFixed(1) ?? '---'} g',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D5D68),
                        ),
                      ),
                    ],
                  ),

                  // Pump status indicator
                  const SizedBox(height: 8),
                  StreamBuilder<bool>(
                    stream: usbRepo.pumpRunningStream,
                    initialData: false,
                    builder: (context, snapshot) {
                      final isPumpRunning = snapshot.data ?? false;
                      return Row(
                        children: [
                          Icon(
                            isPumpRunning
                                ? Icons.water_drop
                                : Icons.water_drop_outlined,
                            size: 14,
                            color: isPumpRunning
                                ? const Color(0xFF00C48C)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPumpRunning
                                ? 'PUMP REFILLING (RUNNING)'
                                : 'PUMP IDLE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPumpRunning
                                  ? const Color(0xFF059669)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Fault banner (if any fault latch is reported)
            StreamBuilder<String?>(
              stream: usbRepo.faultStream,
              initialData: null,
              builder: (context, snapshot) {
                final fault = snapshot.data;
                if (fault == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'HARDWARE FAULT: $fault',
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _handleRearm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Rearm ("r")',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: LiquidTokens.spaceSm),

            // Actions row: Reset MCU Counter & Disconnect with Wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _handleResetCounter,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset MCU (z)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _handleDisconnect,
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.dryState,
                    side: BorderSide(
                      color: palette.dryState.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
