import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../theme/reduced_motion.dart';
import '../../view_models/settings_view_model.dart';

/// Tactile hardware tare calibration button implementing the 7-phase state machine
/// (idle, prompt, measuring, success, failure, timeout, disconnected).
///
/// **Architecture**:
/// - Zero business logic: reads [settingsViewModelProvider] and delegates actions to the notifier.
/// - Declaratively pattern-matches against sealed hierarchy [TareRitualState].
/// - Displays live converging cup weight during [TareMeasuring].
/// - Reduced-motion fallback replaces ripple and wave animations with clean static UI.
class TareRitualButton extends ConsumerWidget {
  const TareRitualButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final state = ref.watch(settingsViewModelProvider);
    final vm = ref.read(settingsViewModelProvider.notifier);
    final reduceMotion = shouldReduceMotion(context, ref);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (state.ritualState) {
          TareIdle() => _buildIdleButton(context, palette, vm),
          TarePrompt() => _buildPromptCard(context, palette, vm),
          TareMeasuring(:final liveGrams) => _buildMeasuringCard(
            context,
            palette,
            vm,
            liveGrams,
            reduceMotion,
          ),
          TareSuccess(:final taredGrams) => _buildSuccessCard(
            context,
            palette,
            vm,
            taredGrams,
            reduceMotion,
          ),
          TareFailure(:final errorMessage) => _buildFailureCard(
            context,
            palette,
            vm,
            errorMessage,
          ),
          TareTimeout(:final errorMessage) => _buildTimeoutCard(
            context,
            palette,
            vm,
            errorMessage,
          ),
          TareDisconnected() => _buildDisconnectedButton(context, palette),
        },
        const SizedBox(height: LiquidTokens.spaceSm),
        _buildHelperText(state.ritualState, palette),
      ],
    );
  }

  Widget _buildIdleButton(
    BuildContext context,
    LiquidColorPalette palette,
    SettingsViewModel vm,
  ) {
    return Semantics(
      button: true,
      label: 'Calibrate Empty Cup Weight',
      hint:
          'Initiates coaster tare routine for pure water measurement accuracy',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: vm.promptTare,
          borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
          child: Ink(
            height: 52.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.waterDeep,
                  palette.primary,
                  palette.aquaHighlight.withValues(alpha: 0.85),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.35),
                  blurRadius: 14.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LiquidTokens.spaceMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_empty_rounded,
                    color: Colors.white,
                    size: 20.0,
                  ),
                  const SizedBox(width: LiquidTokens.spaceSm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Calibrate Empty Cup Weight',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(
    BuildContext context,
    LiquidColorPalette palette,
    SettingsViewModel vm,
  ) {
    return Container(
      padding: const EdgeInsets.all(LiquidTokens.spaceMd),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: LiquidTokens.cardShadow(palette),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(LiquidTokens.spaceXs + 2),
                decoration: BoxDecoration(
                  color: palette.waterShallow.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_drink_rounded,
                  color: palette.primary,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: LiquidTokens.spaceSm),
              Expanded(
                child: Text(
                  'Place Empty Cup on Coaster',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LiquidTokens.spaceSm),
          Text(
            'Ensure the cup is empty and resting completely still on the coaster.',
            style: TextStyle(
              fontSize: 13.0,
              color: palette.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: LiquidTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: vm.cancelTare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textSecondary,
                    side: BorderSide(color: palette.glassBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LiquidTokens.radiusButton,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: LiquidTokens.spaceSm),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: vm.confirmTare,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LiquidTokens.radiusButton,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18.0),
                  label: const Text(
                    'Start Calibration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasuringCard(
    BuildContext context,
    LiquidColorPalette palette,
    SettingsViewModel vm,
    double? liveGrams,
    bool reduceMotion,
  ) {
    final liveText = liveGrams != null
        ? 'Stabilizing (${liveGrams.toStringAsFixed(0)} g)...'
        : 'Zeroing Empty Cup...';

    return Container(
      height: 54.0,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: LiquidTokens.cardShadow(palette),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!reduceMotion)
              Positioned.fill(
                child: LinearProgressIndicator(
                  backgroundColor: palette.waterShallow.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    palette.waterMid.withValues(alpha: 0.4),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LiquidTokens.spaceMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16.0,
                    height: 16.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        palette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: LiquidTokens.spaceSm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        liveText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(
    BuildContext context,
    LiquidColorPalette palette,
    SettingsViewModel vm,
    double taredGrams,
    bool reduceMotion,
  ) {
    return Container(
      height: 52.0,
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
        border: Border.all(color: palette.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.2),
            blurRadius: 10.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LiquidTokens.spaceMd),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: palette.primary,
              size: 20.0,
            ),
            const SizedBox(width: LiquidTokens.spaceSm),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Cup Tare Zeroed ✓ ${taredGrams.round()} g',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                    color: palette.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureCard(
    BuildContext context,
    LiquidColorPalette palette,
    SettingsViewModel vm,
    String errorMessage,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidTokens.spaceMd,
        vertical: LiquidTokens.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        border: Border.all(
          color: palette.error.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.error, size: 20.0),
          const SizedBox(width: LiquidTokens.spaceSm),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 13.0,
                color: palette.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: vm.confirmTare,
            style: TextButton.styleFrom(
              foregroundColor: palette.error,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18.0),
            color: palette.textSecondary,
            onPressed: vm.resetTare,
            tooltip: 'Dismiss',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutCard(
    BuildContext context,
    LiquidColorPalette palette,
    SettingsViewModel vm,
    String errorMessage,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidTokens.spaceMd,
        vertical: LiquidTokens.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: palette.dryState.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        border: Border.all(
          color: palette.dryState.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_off_outlined, color: palette.dryState, size: 20.0),
          const SizedBox(width: LiquidTokens.spaceSm),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 13.0,
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: vm.confirmTare,
            style: TextButton.styleFrom(
              foregroundColor: palette.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedButton(
    BuildContext context,
    LiquidColorPalette palette,
  ) {
    return Container(
      height: 52.0,
      decoration: BoxDecoration(
        color: palette.dryState.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
        border: Border.all(color: palette.glassBorder, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled_rounded,
            color: palette.textSecondary,
            size: 20.0,
          ),
          const SizedBox(width: LiquidTokens.spaceSm),
          Text(
            'Coaster Disconnected',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperText(TareRitualState state, LiquidColorPalette palette) {
    final text = switch (state) {
      TareSuccess() => 'Scale ready for water intake tracking.',
      TareDisconnected() =>
        'Connect your coaster to calibrate empty cup weight.',
      TareMeasuring() => 'Sampling empty cup tare on coaster load cell...',
      TarePrompt() =>
        'Tare establishes baseline zero weight for pure water (1.0 g = 1.0 ml).',
      TareFailure() => 'Ensure coaster is on a flat, stable surface and retry.',
      TareTimeout() =>
        'Coaster communication timed out. Check connection and retry.',
      TareIdle() =>
        'Calibrate your coaster once with an empty cup for maximum accuracy.',
    };

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12.5,
        color: palette.textSecondary,
        height: 1.35,
      ),
    );
  }
}
