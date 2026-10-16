import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';

/// Immutable presentation snapshot of hydration freshness.
@immutable
class FreshnessState {
  const FreshnessState({
    required this.elapsed,
    required this.threshold,
    required this.phase,
    this.lastSipTime,
    required this.elapsedDisplay,
  });

  /// Time elapsed since the most recent sip.
  final Duration elapsed;

  /// Active inactivity threshold.
  final Duration threshold;

  /// Freshness meter phase (fresh, fading, dry).
  final FreshnessPhase phase;

  /// UTC timestamp of the most recent sip, if any.
  final DateTime? lastSipTime;

  /// Glanceable display string (e.g., "12m ago", "Just now", "No sips yet").
  final String elapsedDisplay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreshnessState &&
          runtimeType == other.runtimeType &&
          elapsed == other.elapsed &&
          threshold == other.threshold &&
          phase == other.phase &&
          lastSipTime == other.lastSipTime &&
          elapsedDisplay == other.elapsedDisplay;

  @override
  int get hashCode =>
      Object.hash(elapsed, threshold, phase, lastSipTime, elapsedDisplay);

  @override
  String toString() =>
      'FreshnessState(phase: ${phase.name}, elapsed: $elapsedDisplay)';
}

/// Periodic timer-driven ViewModel tracking elapsed time since last sip.
/// Avoids per-frame overhead by ticking at low frequency (every 10 seconds).
class FreshnessViewModel extends StateNotifier<FreshnessState> {
  FreshnessViewModel({
    required this.historyRepository,
    required this.settingsRepository,
  }) : super(_buildInitialState(historyRepository, settingsRepository)) {
    _init();
  }

  final HistoryRepository historyRepository;
  final SettingsRepository settingsRepository;

  StreamSubscription<List<SipEvent>>? _sipsSub;
  StreamSubscription<UserSettings>? _settingsSub;
  Timer? _timer;

  DateTime? _lastSipTime;
  late Duration _threshold;

  static FreshnessState _buildInitialState(
    HistoryRepository historyRepo,
    SettingsRepository settingsRepo,
  ) {
    final sips = historyRepo.currentTodaySips;
    final threshold = Duration(
      minutes: settingsRepo.currentSettings.inactivityThresholdMinutes,
    );

    if (sips.isEmpty) {
      return FreshnessState(
        elapsed: Duration.zero,
        threshold: threshold,
        phase: FreshnessPhase.dry,
        lastSipTime: null,
        elapsedDisplay: 'No sips yet',
      );
    }

    final lastSip = sips.first.timestamp;
    final elapsed = DateTime.now().toUtc().difference(lastSip);
    final phase = getFreshnessPhase(elapsed, threshold);
    return FreshnessState(
      elapsed: elapsed,
      threshold: threshold,
      phase: phase,
      lastSipTime: lastSip,
      elapsedDisplay: _formatElapsed(elapsed),
    );
  }

  void _init() {
    _threshold = Duration(
      minutes: settingsRepository.currentSettings.inactivityThresholdMinutes,
    );
    final initialSips = historyRepository.currentTodaySips;
    _lastSipTime = initialSips.isNotEmpty ? initialSips.first.timestamp : null;

    // 1. Watch today sips updates
    _sipsSub = historyRepository.watchTodaySips().listen((sips) {
      if (!mounted) return;
      _updateLastSip(sips);
    });

    // 2. Watch settings updates
    _settingsSub = settingsRepository.watchSettings().listen((settings) {
      if (!mounted) return;
      _threshold = Duration(minutes: settings.inactivityThresholdMinutes);
      _recalculate();
    });

    // 3. Low-frequency 10-second timer
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _recalculate();
    });
  }

  void _updateLastSip(List<SipEvent> sips) {
    _lastSipTime = sips.isNotEmpty ? sips.first.timestamp : null;
    _recalculate();
  }

  void _recalculate() {
    if (_lastSipTime == null) {
      state = FreshnessState(
        elapsed: Duration.zero,
        threshold: _threshold,
        phase: FreshnessPhase.dry,
        lastSipTime: null,
        elapsedDisplay: 'No sips yet',
      );
      return;
    }

    final now = DateTime.now().toUtc();
    final elapsed = now.difference(_lastSipTime!);
    final phase = getFreshnessPhase(elapsed, _threshold);
    final display = _formatElapsed(elapsed);

    state = FreshnessState(
      elapsed: elapsed,
      threshold: _threshold,
      phase: phase,
      lastSipTime: _lastSipTime,
      elapsedDisplay: display,
    );
  }

  static String _formatElapsed(Duration elapsed) {
    if (elapsed.inSeconds < 60) {
      return 'Just now';
    } else if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}m ago';
    } else if (elapsed.inHours < 24) {
      return '${elapsed.inHours}h ago';
    } else {
      return '${elapsed.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _sipsSub?.cancel();
    _settingsSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider exposing [FreshnessState].
final freshnessViewModelProvider =
    StateNotifierProvider<FreshnessViewModel, FreshnessState>((ref) {
      final historyRepo = ref.watch(historyRepositoryProvider);
      final settingsRepo = ref.watch(settingsRepositoryProvider);

      return FreshnessViewModel(
        historyRepository: historyRepo,
        settingsRepository: settingsRepo,
      );
    }, dependencies: [historyRepositoryProvider, settingsRepositoryProvider]);
