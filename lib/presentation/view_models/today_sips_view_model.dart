import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';

/// StateNotifier providing today's intake sip events (sorted newest first)
/// and mutation methods delegating to [HistoryRepository].
class TodaySipsViewModel extends StateNotifier<List<SipEvent>> {
  TodaySipsViewModel({required this.historyRepository})
    : super(historyRepository.currentTodaySips) {
    _init();
  }

  final HistoryRepository historyRepository;
  StreamSubscription<List<SipEvent>>? _sub;

  void _init() {
    _sub = historyRepository.watchTodaySips().listen((sips) {
      if (!mounted) return;
      state = sips;
    });
  }

  /// Removes a sip event from today's history.
  Future<void> deleteSip(String sipId) async {
    await historyRepository.deleteSip(sipId);
  }

  /// Updates the volume of an existing sip event.
  Future<void> updateSipVolume(String sipId, int newVolumeMl) async {
    await historyRepository.updateSipVolume(sipId, newVolumeMl);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider exposing today's list of [SipEvent] items.
final todaySipsViewModelProvider =
    StateNotifierProvider<TodaySipsViewModel, List<SipEvent>>((ref) {
      final historyRepo = ref.watch(historyRepositoryProvider);
      return TodaySipsViewModel(historyRepository: historyRepo);
    }, dependencies: [historyRepositoryProvider]);
