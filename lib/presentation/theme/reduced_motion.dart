import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// StateProvider allowing users or developer settings to manually force
/// reduced effects / motion (e.g., in battery saver mode or low-end devices).
final manualReducedEffectsProvider = StateProvider<bool>((ref) => false);

/// Riverpod helper provider taking a [BuildContext] to evaluate combined motion reduction:
/// returns `true` if either the system accessibility setting (`MediaQuery.disableAnimations`)
/// or the manual [manualReducedEffectsProvider] flag is active.
final reducedEffectsProvider = Provider.family<bool, BuildContext>((
  ref,
  context,
) {
  final manual = ref.watch(manualReducedEffectsProvider);
  final system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return manual || system;
});

/// Direct query helper for widgets that have access to [WidgetRef] and [BuildContext].
bool shouldReduceMotion(BuildContext context, WidgetRef ref) {
  final manual = ref.watch(manualReducedEffectsProvider);
  final system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return manual || system;
}
