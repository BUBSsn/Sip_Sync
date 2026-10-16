import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/domain.dart';
import 'seed_data.dart';

/// Fake implementation of [SettingsRepository] that persists preferences to
/// [SharedPreferences] while broadcasting live changes to active subscribers.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({SharedPreferences? preferences})
    : _prefs = preferences {
    if (_prefs != null) {
      _loadFromPrefs();
    }
  }

  static const String keyDailyGoal = 'liquid_store.daily_goal_ml';
  static const String keyInactivityThreshold =
      'liquid_store.inactivity_threshold_minutes';
  static const String keyAdaptiveReminders =
      'liquid_store.adaptive_reminders_enabled';
  static const String keyPortionLimit = 'liquid_store.portion_limit_ml';

  SharedPreferences? _prefs;

  UserSettings _currentSettings = const UserSettings(
    dailyGoalMl: SeedData.defaultDailyGoalMl,
    inactivityThresholdMinutes: SeedData.defaultInactivityThresholdMinutes,
    adaptiveRemindersEnabled: true,
    portionLimitMl: UserSettings.defaultPortionLimitMl,
  );

  final StreamController<UserSettings> _settingsController =
      StreamController<UserSettings>.broadcast();

  void _loadFromPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;

    final goal = prefs.getInt(keyDailyGoal) ?? _currentSettings.dailyGoalMl;
    final threshold =
        prefs.getInt(keyInactivityThreshold) ??
        _currentSettings.inactivityThresholdMinutes;
    final adaptive =
        prefs.getBool(keyAdaptiveReminders) ??
        _currentSettings.adaptiveRemindersEnabled;
    final portion =
        prefs.getInt(keyPortionLimit) ?? _currentSettings.portionLimitMl;

    _currentSettings = UserSettings(
      dailyGoalMl: goal.clamp(
        UserSettings.minDailyGoalMl,
        UserSettings.maxDailyGoalMl,
      ),
      inactivityThresholdMinutes: threshold > 0 ? threshold : 45,
      adaptiveRemindersEnabled: adaptive,
      portionLimitMl: portion.clamp(
        UserSettings.minPortionLimitMl,
        UserSettings.maxPortionLimitMl,
      ),
    );
  }

  /// Optional asynchronous initialization method when `SharedPreferences` is loaded lazily.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadFromPrefs();
    _settingsController.add(_currentSettings);
  }

  @override
  UserSettings get currentSettings => _currentSettings;

  @override
  Future<UserSettings> getSettings() async {
    if (_prefs == null) {
      await init();
    }
    return _currentSettings;
  }

  @override
  Stream<UserSettings> watchSettings() => _settingsController.stream;

  @override
  Future<void> updateSettings(UserSettings settings) async {
    _currentSettings = settings;
    _settingsController.add(_currentSettings);

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    await Future.wait([
      prefs.setInt(keyDailyGoal, settings.dailyGoalMl),
      prefs.setInt(keyInactivityThreshold, settings.inactivityThresholdMinutes),
      prefs.setBool(keyAdaptiveReminders, settings.adaptiveRemindersEnabled),
      prefs.setInt(keyPortionLimit, settings.portionLimitMl),
    ]);
  }

  void dispose() {
    _settingsController.close();
  }
}
