import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';
import '../theme/liquid_tokens.dart';

/// Event payload emitted for live sip feedback animations (floating +X ml, ripple).
@immutable
class SipFeedbackState {
  const SipFeedbackState({
    this.latestSip,
    this.mergedVolumeMl = 0,
    this.timestamp,
    this.hasActiveFeedback = false,
    this.comboCount = 0,
  });

  /// The underlying discrete sip event, or merged sip event.
  final SipEvent? latestSip;

  /// Aggregated volume in ml for the current feedback burst.
  final int mergedVolumeMl;

  /// UTC timestamp of the feedback trigger.
  final DateTime? timestamp;

  /// Whether an animation sequence should currently be playing.
  final bool hasActiveFeedback;

  /// Number of sips in the current consecutive merge window.
  final int comboCount;

  SipFeedbackState copyWith({
    SipEvent? latestSip,
    int? mergedVolumeMl,
    DateTime? timestamp,
    bool? hasActiveFeedback,
    int? comboCount,
  }) {
    return SipFeedbackState(
      latestSip: latestSip ?? this.latestSip,
      mergedVolumeMl: mergedVolumeMl ?? this.mergedVolumeMl,
      timestamp: timestamp ?? this.timestamp,
      hasActiveFeedback: hasActiveFeedback ?? this.hasActiveFeedback,
      comboCount: comboCount ?? this.comboCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SipFeedbackState &&
          runtimeType == other.runtimeType &&
          latestSip == other.latestSip &&
          mergedVolumeMl == other.mergedVolumeMl &&
          timestamp == other.timestamp &&
          hasActiveFeedback == other.hasActiveFeedback &&
          comboCount == other.comboCount;

  @override
  int get hashCode => Object.hash(
    latestSip,
    mergedVolumeMl,
    timestamp,
    hasActiveFeedback,
    comboCount,
  );

  @override
  String toString() =>
      'SipFeedbackState(+${mergedVolumeMl}ml, active: $hasActiveFeedback, combo: $comboCount)';
}

/// Listens to hardware sip stream and aggregates rapid consecutive sips
/// (within a 2-minute window) so animations merge rather than violently stack.
class SipFeedbackViewModel extends StateNotifier<SipFeedbackState> {
  SipFeedbackViewModel({required this.coasterRepository})
    : super(const SipFeedbackState()) {
    _init();
  }

  final CoasterRepository coasterRepository;
  StreamSubscription<SipEvent>? _sub;
  Timer? _feedbackResetTimer;
  Timer? _comboTimer;

  // Recent sips buffer for window merging
  final List<SipEvent> _recentSips = [];

  void _init() {
    _sub = coasterRepository.sipStream.listen((sip) {
      if (!mounted) return;
      final age = DateTime.now().toUtc().difference(sip.timestamp);
      if (age.isNegative || age > const Duration(minutes: 1)) return;
      _handleIncomingSip(sip);
    });
  }

  int _computeTopClusterCount(List<SipEvent> sips) {
    if (sips.isEmpty) return 0;
    final sorted = List<SipEvent>.from(sips)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    int count = 1;
    for (int i = sorted.length - 1; i > 0; i--) {
      final curr = sorted[i];
      final prev = sorted[i - 1];
      if (curr.timestamp.difference(prev.timestamp).abs() <=
          const Duration(minutes: 2)) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  void _handleIncomingSip(SipEvent sip) {
    _recentSips.add(sip);

    // Merge using pure domain logic
    final merged = groupSipMergeWindows(_recentSips);
    final topMerged = merged.isNotEmpty ? merged.first : sip;
    final combo = _computeTopClusterCount(_recentSips);

    state = SipFeedbackState(
      latestSip: topMerged,
      mergedVolumeMl: topMerged.volumeMl,
      timestamp: topMerged.timestamp,
      hasActiveFeedback: true,
      comboCount: combo,
    );

    _feedbackResetTimer?.cancel();
    _feedbackResetTimer = Timer(LiquidTokens.durationSipFeedback, () {
      if (!mounted) return;
      state = state.copyWith(hasActiveFeedback: false);
      // Clean up old sips older than merge window (2 minutes)
      final cutoff = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      _recentSips.removeWhere((s) => s.timestamp.isBefore(cutoff));
    });

    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted) return;
      _recentSips.clear();
      state = state.copyWith(comboCount: 0);
    });
  }

  /// Manually clears feedback once consumed by an animation controller.
  void clearFeedback() {
    state = state.copyWith(hasActiveFeedback: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _feedbackResetTimer?.cancel();
    _comboTimer?.cancel();
    super.dispose();
  }
}

/// Provider exposing [SipFeedbackState] for vessel droplet/ripple animation triggers.
final sipFeedbackViewModelProvider =
    StateNotifierProvider<SipFeedbackViewModel, SipFeedbackState>((ref) {
      final coasterRepo = ref.watch(coasterRepositoryProvider);
      return SipFeedbackViewModel(coasterRepository: coasterRepo);
    }, dependencies: [coasterRepositoryProvider]);
