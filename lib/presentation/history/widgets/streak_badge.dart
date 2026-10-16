import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/domain.dart';
import 'streak_drop_badge.dart';

/// Builder signature for rendering the gamification streak badge.
///
/// In Phase 3, defaults to [StreakDropBadge] (Canvas/CustomPainter).
/// In Phase 6, [streakBadgeBuilderProvider] can be cleanly overridden with a Rive-powered
/// implementation without any changes to HistoryScreen or downstream callers.
typedef StreakBadgeBuilder =
    Widget Function(
      BuildContext context, {
      required int streakDays,
      required int bestStreakDays,
      required StreakBadgeTier currentTier,
      required int daysToNextTier,
      required bool isReducedMotion,
    });

/// Riverpod provider exposing the active [StreakBadgeBuilder].
final streakBadgeBuilderProvider = Provider<StreakBadgeBuilder>((ref) {
  return (
    context, {
    required streakDays,
    required bestStreakDays,
    required currentTier,
    required daysToNextTier,
    required isReducedMotion,
  }) {
    return StreakDropBadge(
      streakDays: streakDays,
      bestStreakDays: bestStreakDays,
      currentTier: currentTier,
      daysToNextTier: daysToNextTier,
      isReducedMotion: isReducedMotion,
    );
  };
});
