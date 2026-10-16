import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/fake/fake_settings_repository.dart';

// Simulation is explicit and confined to tests. Nested scopes let individual
// test overrides take precedence without replacing production defaults.
List<Override> _defaults() => [
  coasterRepositoryProvider.overrideWith((ref) {
    final repo = FakeCoasterRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }),
  historyRepositoryProvider.overrideWith((ref) {
    final repo = FakeHistoryRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }),
  settingsRepositoryProvider.overrideWith((ref) {
    final repo = FakeSettingsRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }),
];

class TestProviderScope extends StatelessWidget {
  const TestProviderScope({
    super.key,
    this.overrides = const [],
    required this.child,
  });
  final List<Override> overrides;
  final Widget child;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: _defaults(),
    child: ProviderScope(overrides: overrides, child: child),
  );
}

ProviderContainer createTestContainer({List<Override> overrides = const []}) {
  final root = ProviderContainer(overrides: _defaults());
  addTearDown(root.dispose);
  return ProviderContainer(parent: root, overrides: overrides);
}
