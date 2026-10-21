import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'data/providers.dart';
import 'data/local/preferences_settings_repository.dart';
import 'data/local/sqlite_history_repository.dart';
import 'data/local/screenshot_history_profile.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/theme/liquid_theme.dart';
import 'presentation/theme/theme_mode_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Startup());
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<(PreferencesSettingsRepository, SqliteHistoryRepository)>
  _loading;
  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<(PreferencesSettingsRepository, SqliteHistoryRepository)>
  _load() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = PreferencesSettingsRepository(preferences);
    try {
      final history = await SqliteHistoryRepository.open(
        settings: settings,
        initialDailyTotals: ScreenshotHistoryProfile.enabled
            ? ScreenshotHistoryProfile.days
            : const [],
        initialDailyGoalMl: ScreenshotHistoryProfile.enabled
            ? ScreenshotHistoryProfile.currentGoalMl
            : null,
      );
      if (history.initialHistoryRestored &&
          preferences.getString('sip_sync_theme_mode') == null) {
        await preferences.setString('sip_sync_theme_mode', 'dark');
      }
      return (settings, history);
    } catch (_) {
      settings.dispose();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final (settings, history) = snapshot.data!;
        return ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            historyRepositoryProvider.overrideWithValue(history),
          ],
          child: const LiquidStoreApp(),
        );
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your saved records could not be opened. Please retry. No records have been cleared.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            _loading = _load();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}

/// Root application widget for SipSync.
class LiquidStoreApp extends ConsumerWidget {
  const LiquidStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SipSync',
      debugShowCheckedModeBanner: false,
      theme: LiquidTheme.light,
      darkTheme: LiquidTheme.dark,
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
