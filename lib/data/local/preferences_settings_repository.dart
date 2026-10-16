import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/domain.dart';

/// Imports legacy preferences at startup. Once attached, SQLite is the
/// authoritative goal store shared with history.
class PreferencesSettingsRepository implements SettingsRepository {
  PreferencesSettingsRepository(this.preferences) {
    _settings = UserSettings(
      dailyGoalMl: (preferences.getInt(_goalKey) ?? 2000).clamp(1000, 4000),
      // Reminder timing belongs to the fixed firmware workflow, not an inert UI.
      inactivityThresholdMinutes: 90,
      adaptiveRemindersEnabled: false,
    );
  }
  static const _goalKey = 'liquid_store.daily_goal_ml';
  final SharedPreferences preferences;
  late UserSettings _settings;
  final _changes = StreamController<UserSettings>.broadcast();
  Future<void> _pending = Future.value();
  Future<void> Function(int goal)? _saveGoal;

  void attachGoalStore(int goal, Future<void> Function(int) save) {
    _settings = _settings.copyWith(dailyGoalMl: goal);
    _saveGoal = save;
  }

  @override
  UserSettings get currentSettings => _settings;
  @override
  Future<UserSettings> getSettings() async => _settings;
  @override
  Stream<UserSettings> watchSettings() => _changes.stream;
  @override
  Future<void> updateSettings(UserSettings settings) {
    final operation = _pending.then((_) async {
      final saveGoal = _saveGoal;
      if (saveGoal != null) {
        await saveGoal(settings.dailyGoalMl);
      } else if (!await preferences.setInt(_goalKey, settings.dailyGoalMl)) {
        throw StateError('Could not save the daily goal.');
      }
      _settings = settings;
      _changes.add(settings);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  void dispose() => _changes.close();
}
