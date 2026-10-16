import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fake/fake_coaster_repository.dart';
import '../../data/fake/fake_history_repository.dart';
import '../../data/fake/seed_data.dart';
import '../../data/providers.dart';
import '../../domain/domain.dart';
import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../view_models/live_weight_provider.dart';

/// Floating debug action button and bottom sheet simulator for testing hardware interactions.
/// Only renders in [kDebugMode].
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final palette = context.liquidColors;

    return FloatingActionButton.small(
      heroTag: 'debug_simulator_fab',
      backgroundColor: palette.primary,
      foregroundColor: palette.onPrimary,
      tooltip: 'Hardware Simulator (Debug)',
      onPressed: () => _showSimulatorSheet(context, ref),
      child: const Icon(Icons.tune, size: 20),
    );
  }

  void _showSimulatorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SimulatorSheet(ref: ref),
    );
  }
}

class _SimulatorSheet extends StatefulWidget {
  const _SimulatorSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_SimulatorSheet> createState() => _SimulatorSheetState();
}

class _SimulatorSheetState extends State<_SimulatorSheet> {
  final _random = Random();
  double _currentWeight = 350.0;

  @override
  void initState() {
    super.initState();
    final coaster = widget.ref.read(coasterRepositoryProvider);
    _currentWeight = coaster.lastReading?.grams ?? 350.0;
  }

  Future<void> _triggerSip(int volumeMl) async {
    final coasterRepo = widget.ref.read(coasterRepositoryProvider);
    final historyRepo = widget.ref.read(historyRepositoryProvider);
    final isCupEmpty = widget.ref.read(isCupEmptyProvider);

    if (isCupEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cannot take sip: cup is empty (${_currentWeight.toStringAsFixed(0)}g). Refill with water first.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final now = DateTime.now().toUtc();
    final sip = SipEvent(
      id: 'debug_sip_${now.millisecondsSinceEpoch}',
      volumeMl: volumeMl,
      timestamp: now,
    );

    // Dual-write: hardware stream + durable intake history
    if (coasterRepo is FakeCoasterRepository) {
      coasterRepo.simulateSip(volumeMl, now);
    }
    await historyRepo.recordSip(sip);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulated sip: +$volumeMl ml'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _changeWeight(double grams) {
    setState(() => _currentWeight = grams);
    final coasterRepo = widget.ref.read(coasterRepositoryProvider);
    if (coasterRepo is FakeCoasterRepository) {
      coasterRepo.simulateWeightChange(grams);
    }
  }

  void _toggleConnection() {
    final coasterRepo = widget.ref.read(coasterRepositoryProvider);
    if (coasterRepo is FakeCoasterRepository) {
      final isCurrentlyConnected = coasterRepo.currentConnection.isConnected;
      coasterRepo.simulateConnection(
        isCurrentlyConnected
            ? ConnectionStatus.disconnected
            : ConnectionStatus.connected,
      );
    }
  }

  Future<void> _connectUsb() async {
    final usbRepo = widget.ref.read(usbSerialCoasterRepositoryProvider);
    final ok = await usbRepo.connectUsb();
    if (ok) {
      widget.ref.read(isUsbHardwareActiveProvider.notifier).state = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to USB Coaster Hardware!'),
            backgroundColor: Color(0xFF00C48C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _disconnectUsb() async {
    final usbRepo = widget.ref.read(usbSerialCoasterRepositoryProvider);
    await usbRepo.disconnectUsb();
    widget.ref.read(isUsbHardwareActiveProvider.notifier).state = false;
  }

  void _setCalibration(CalibrationStatus status, [String? error]) {
    final coasterRepo = widget.ref.read(coasterRepositoryProvider);
    if (coasterRepo is FakeCoasterRepository) {
      coasterRepo.setNextCalibrationOutcome(
        status: status,
        measuredGrams: 350.0,
        errorMessage: error,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Next calibration set to: ${status.name}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setHistoryPreset(HistoryPreset preset) async {
    final historyRepo = widget.ref.read(historyRepositoryProvider);
    if (historyRepo is FakeHistoryRepository) {
      await historyRepo.setHistoryPreset(preset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${preset.name} history'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _simulateMidnightRollover() async {
    final historyRepo = widget.ref.read(historyRepositoryProvider);
    if (historyRepo is FakeHistoryRepository) {
      await historyRepo.simulateMidnightRollover();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Midnight rollover simulated: today reset to 0 ml'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final isConnected = widget.ref.watch(
      coasterRepositoryProvider.select((r) => r.currentConnection.isConnected),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LiquidTokens.radiusSheet),
        ),
        boxShadow: LiquidTokens.cardShadow(palette),
      ),
      padding: const EdgeInsets.all(LiquidTokens.spaceLg),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hardware Simulator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: LiquidTokens.spaceMd),

              // Connection Toggle
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? palette.primary : palette.dryState,
                ),
                title: Text(isConnected ? 'Connected' : 'Disconnected'),
                subtitle: const Text('Toggle coaster link state'),
                trailing: Switch(
                  value: isConnected,
                  onChanged: (_) => _toggleConnection(),
                ),
              ),

              // Physical USB Connection Section
              Builder(
                builder: (context) {
                  final isUsbActive = widget.ref.watch(
                    isUsbHardwareActiveProvider,
                  );
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: LiquidTokens.spaceSm,
                    ),
                    padding: const EdgeInsets.all(LiquidTokens.spaceMd),
                    decoration: BoxDecoration(
                      color: isUsbActive
                          ? const Color(0xFFCCFBF1).withValues(alpha: 0.4)
                          : palette.waterShallow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        LiquidTokens.radiusSm,
                      ),
                      border: Border.all(
                        color: isUsbActive
                            ? const Color(0xFF00C48C)
                            : palette.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.usb,
                          color: isUsbActive
                              ? const Color(0xFF059669)
                              : palette.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUsbActive
                                    ? 'USB Hardware Live'
                                    : 'Physical USB Coaster',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                isUsbActive
                                    ? 'Streaming via Chrome Web Serial'
                                    : 'Connect board via USB cable',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isUsbActive)
                          TextButton(
                            onPressed: _disconnectUsb,
                            child: const Text(
                              'Disconnect',
                              style: TextStyle(color: Color(0xFFDC2626)),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _connectUsb,
                            icon: const Icon(Icons.cable, size: 14),
                            label: const Text(
                              'Connect',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: palette.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(),

              // Sip Simulations
              Text(
                'Simulate Sip Event',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: LiquidTokens.spaceSm),
              Wrap(
                spacing: LiquidTokens.spaceSm,
                runSpacing: LiquidTokens.spaceSm,
                children: [
                  ActionChip(
                    label: const Text('+45 ml'),
                    onPressed: () => _triggerSip(45),
                  ),
                  ActionChip(
                    label: const Text('+120 ml'),
                    onPressed: () => _triggerSip(120),
                  ),
                  ActionChip(
                    label: const Text('+250 ml'),
                    onPressed: () => _triggerSip(250),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.casino, size: 16),
                    label: const Text('Random'),
                    onPressed: () => _triggerSip(30 + _random.nextInt(221)),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.water_drop,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    label: const Text('Refill (+250ml)'),
                    onPressed: () {
                      final coasterRepo = widget.ref.read(
                        coasterRepositoryProvider,
                      );
                      if (coasterRepo is FakeCoasterRepository) {
                        coasterRepo.refillCup(250);
                        setState(
                          () => _currentWeight =
                              coasterRepo.lastReading?.grams ?? 600.0,
                        );
                      }
                    },
                  ),
                ],
              ),
              const Divider(),

              // History Presets
              Text(
                'History Presets (Phase 3)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: LiquidTokens.spaceSm),
              Wrap(
                spacing: LiquidTokens.spaceSm,
                runSpacing: LiquidTokens.spaceSm,
                children: [
                  ActionChip(
                    label: const Text('Reference (12.9L)'),
                    onPressed: () => _setHistoryPreset(HistoryPreset.reference),
                  ),
                  ActionChip(
                    label: const Text('Tier 5 (35d Streak)'),
                    onPressed: () =>
                        _setHistoryPreset(HistoryPreset.highStreak),
                  ),
                  ActionChip(
                    label: const Text('Partial (3 days)'),
                    onPressed: () => _setHistoryPreset(HistoryPreset.partial),
                  ),
                  ActionChip(
                    label: const Text('Empty History'),
                    onPressed: () => _setHistoryPreset(HistoryPreset.empty),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.nightlight_round, size: 16),
                    label: const Text('Midnight Rollover'),
                    onPressed: _simulateMidnightRollover,
                  ),
                ],
              ),
              const Divider(),

              // Scale Weight Slider
              Text(
                'Scale Cup Weight: ${_currentWeight.toStringAsFixed(0)} g',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              Slider(
                value: _currentWeight,
                min: 0,
                max: 1000,
                divisions: 20,
                onChanged: _changeWeight,
              ),
              const Divider(),

              // Calibration Outcomes
              Text(
                'Next Tare Outcome',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: LiquidTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _setCalibration(CalibrationStatus.success),
                      child: const Text('Success'),
                    ),
                  ),
                  const SizedBox(width: LiquidTokens.spaceSm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setCalibration(
                        CalibrationStatus.failure,
                        'Unstable surface detected',
                      ),
                      child: const Text('Failure'),
                    ),
                  ),
                  const SizedBox(width: LiquidTokens.spaceSm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setCalibration(
                        CalibrationStatus.timeout,
                        'Tare timed out',
                      ),
                      child: const Text('Timeout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
