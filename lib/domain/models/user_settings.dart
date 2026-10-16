import 'package:flutter/foundation.dart';

/// User preferences for daily hydration targets and coaster reminders.
///
/// **Units & Semantics**:
/// - [dailyGoalMl]: Target daily water intake in milliliters (`ml`).
///   Valid range: 1000 ml (1L) to 4000 ml (4L). Default: 2000 ml.
/// - [inactivityThresholdMinutes]: Minutes of coaster inactivity before prompting
///   an adaptive reminder nudge. Default: 45 minutes.
/// - [adaptiveRemindersEnabled]: Master toggle for smart reminder nudges based on habits.
///   Default: true.
/// - [portionLimitMl]: Default volume for quick sips and portion limit in milliliters (`ml`).
///   Valid range: 50 ml to 500 ml. Default: 250 ml.
@immutable
class UserSettings {
  const UserSettings({
    this.dailyGoalMl = defaultDailyGoalMl,
    this.inactivityThresholdMinutes = defaultInactivityThresholdMinutes,
    this.adaptiveRemindersEnabled = defaultAdaptiveRemindersEnabled,
    this.portionLimitMl = defaultPortionLimitMl,
  }) : assert(
         dailyGoalMl >= minDailyGoalMl && dailyGoalMl <= maxDailyGoalMl,
         'dailyGoalMl must be between $minDailyGoalMl and $maxDailyGoalMl',
       ),
       assert(
         inactivityThresholdMinutes > 0,
         'inactivityThresholdMinutes must be strictly positive',
       ),
       assert(
         portionLimitMl >= minPortionLimitMl &&
             portionLimitMl <= maxPortionLimitMl,
         'portionLimitMl must be between $minPortionLimitMl and $maxPortionLimitMl',
       );

  static const int minDailyGoalMl = 1000;
  static const int maxDailyGoalMl = 4000;
  static const int defaultDailyGoalMl = 2000;
  static const int defaultInactivityThresholdMinutes = 45;
  static const bool defaultAdaptiveRemindersEnabled = true;
  static const int minPortionLimitMl = 50;
  static const int maxPortionLimitMl = 500;
  static const int defaultPortionLimitMl = 250;

  /// Target daily water volume in milliliters (ml).
  final int dailyGoalMl;

  /// Minutes of inactivity before freshness enters dry phase / nudges.
  final int inactivityThresholdMinutes;

  /// Whether adaptive smart nudges are active.
  final bool adaptiveRemindersEnabled;

  /// Volume in milliliters for quick portion logs.
  final int portionLimitMl;

  UserSettings copyWith({
    int? dailyGoalMl,
    int? inactivityThresholdMinutes,
    bool? adaptiveRemindersEnabled,
    int? portionLimitMl,
  }) {
    return UserSettings(
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      inactivityThresholdMinutes:
          inactivityThresholdMinutes ?? this.inactivityThresholdMinutes,
      adaptiveRemindersEnabled:
          adaptiveRemindersEnabled ?? this.adaptiveRemindersEnabled,
      portionLimitMl: portionLimitMl ?? this.portionLimitMl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          dailyGoalMl == other.dailyGoalMl &&
          inactivityThresholdMinutes == other.inactivityThresholdMinutes &&
          adaptiveRemindersEnabled == other.adaptiveRemindersEnabled &&
          portionLimitMl == other.portionLimitMl;

  @override
  int get hashCode => Object.hash(
    dailyGoalMl,
    inactivityThresholdMinutes,
    adaptiveRemindersEnabled,
    portionLimitMl,
  );

  @override
  String toString() =>
      'UserSettings(dailyGoalMl: ${dailyGoalMl}ml, inactivityThreshold: ${inactivityThresholdMinutes}m, adaptiveReminders: $adaptiveRemindersEnabled, portionLimit: ${portionLimitMl}ml)';
}
