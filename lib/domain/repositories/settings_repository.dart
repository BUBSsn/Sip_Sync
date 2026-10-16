import '../models/user_settings.dart';

/// Contract for reading, watching, and mutating user hydration preferences.
abstract class SettingsRepository {
  /// Fetches the currently persisted user settings.
  Future<UserSettings> getSettings();

  /// Synchronous access to current cached settings.
  UserSettings get currentSettings;

  /// Stream emitting new settings whenever preferences are updated.
  /// Broadcast stream: multiple subscribers supported.
  Stream<UserSettings> watchSettings();

  /// Persists updated [settings] to durable storage.
  Future<void> updateSettings(UserSettings settings);
}
