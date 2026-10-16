import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/fake/fake_coaster_repository.dart';
import 'data/fake/fake_history_repository.dart';
import 'data/fake/fake_settings_repository.dart';
import 'data/providers.dart';
import 'data/wifi/wifi_coaster_repository.dart';
import 'domain/domain.dart';
import 'main.dart' show LiquidStoreApp;

/// Browser-only screen preview. Production startup stays in main.dart.
void main() {
  const showProgress = bool.fromEnvironment('PREVIEW_PROGRESS');
  runApp(
    ProviderScope(
      overrides: [
        if (showProgress)
          coasterStatusProvider.overrideWith(
            (ref) => Stream.value(
              const CoasterStatus(state: 'resting', cupPresent: true),
            ),
          ),
        coasterRepositoryProvider.overrideWith((ref) {
          final repository = FakeCoasterRepository(
            initialWeightGrams: showProgress ? 500 : 0,
            initialConnection: showProgress
                ? ConnectionStatus.connected
                : ConnectionStatus.disconnected,
          );
          ref.onDispose(repository.dispose);
          return repository;
        }),
        historyRepositoryProvider.overrideWith((ref) {
          final repository = FakeHistoryRepository(
            initialSips: showProgress ? null : [],
            initialSummaries: showProgress
                ? List.generate(6, (index) {
                    final now = DateTime.now();
                    return DailySummary(
                      date: DateTime(now.year, now.month, now.day - 6 + index),
                      totalMl: const [
                        1600,
                        1950,
                        2100,
                        2200,
                        2050,
                        1800,
                      ][index],
                      goalMl: 2000,
                    );
                  })
                : [],
          );
          ref.onDispose(repository.dispose);
          return repository;
        }),
        settingsRepositoryProvider.overrideWith((ref) {
          final repository = FakeSettingsRepository();
          ref.onDispose(repository.dispose);
          return repository;
        }),
      ],
      child: const LiquidStoreApp(),
    ),
  );
}
