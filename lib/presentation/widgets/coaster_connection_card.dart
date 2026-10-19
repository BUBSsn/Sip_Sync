import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/wifi/wifi_coaster_repository.dart';
import '../theme/liquid_theme.dart';
import '../view_models/connection_view_model.dart';
import '../view_models/live_weight_provider.dart';
import 'glass_card.dart';

class CoasterConnectionCard extends ConsumerWidget {
  const CoasterConnectionCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionViewModelProvider);
    final status =
        ref.watch(coasterStatusProvider).valueOrNull ?? const CoasterStatus();
    final water = ref.watch(cupWaterVolumeMlProvider);
    final colors = context.liquidColors;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.wifi, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Coaster · ${connection.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connection.isConnected
                ? status.label
                : 'Join LiquidCoaster in your phone’s Wi-Fi settings, then return here.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (!connection.isConnected) ...[
            const SizedBox(height: 8),
            Text(
              'Wi-Fi password: Water258Cup',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onPrimary,
                backgroundColor: colors.primary,
                side: BorderSide.none,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: LiquidTheme.homeFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              onPressed: () {
                final repository = ref.read(coasterRepositoryProvider);
                if (repository is WifiCoasterRepository) repository.reconnect();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              status.cupPresent
                  ? '$water ml of water in cup'
                  : 'Cup is off the coaster',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          if (status.fault != null) ...[
            const SizedBox(height: 12),
            Text(
              _faultMessage(status.fault!),
              style: TextStyle(
                color: colors.dryState,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (status.message != null) ...[
            const SizedBox(height: 12),
            Text(status.message!, style: TextStyle(color: colors.dryState)),
          ],
        ],
      ),
    );
  }

  String _faultMessage(String fault) => switch (fault) {
    'SPILL' =>
      'Spill detected. Clear the spill and press the coaster button to rearm.',
    'PUMP_TIMEOUT' =>
      'Refilling timed out. Check the water supply, then press the coaster button.',
    'SENSOR' =>
      'Scale readings are unavailable. Check the sensor before restarting the coaster.',
    'QUEUE_FULL' =>
      'Connect the app to save queued sips. Refilling is paused until records are saved.',
    'STORAGE' =>
      'The coaster could not save its records. Refilling is paused; check the device.',
    'ZERO_REQUIRED' =>
      'First setup: remove the cup and press the coaster button to zero the empty scale.',
    'STARTUP_CUP' =>
      'Remove the cup, then restart the coaster so the empty scale can be zeroed.',
    _ => 'Coaster fault: $fault. Check the device before continuing.',
  };
}
