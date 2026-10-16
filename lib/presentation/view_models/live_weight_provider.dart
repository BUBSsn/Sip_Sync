import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';
import '../../domain/models/fixed_cup.dart';

/// StateNotifier providing smoothed live weight readings from the smart coaster hardware.
///
/// Implements rolling hysteresis/smoothing to prevent mechanical vibration jitter
/// on the scale, while immediately snapping on significant weight shifts (> 5g).
class LiveWeightNotifier extends StateNotifier<double> {
  LiveWeightNotifier({required this.coasterRepository})
    : super(coasterRepository.lastReading?.grams ?? 0.0) {
    _init();
  }

  final CoasterRepository coasterRepository;
  StreamSubscription<CupWeightReading>? _sub;
  final List<double> _samples = [];

  void _init() {
    _sub = coasterRepository.weightStream.listen((reading) {
      if (!mounted) return;
      _processReading(reading.grams);
    });
  }

  void _processReading(double rawGrams) {
    // If large weight change (e.g., sip taken, cup picked up/set down), snap immediately
    if ((rawGrams - state).abs() >= 5.0) {
      _samples.clear();
      _samples.add(rawGrams);
      state = rawGrams;
      return;
    }

    // Small fluctuations: smooth across up to 3 samples
    _samples.add(rawGrams);
    if (_samples.length > 3) {
      _samples.removeAt(0);
    }

    final smoothed = _samples.reduce((a, b) => a + b) / _samples.length;
    if ((state - smoothed).abs() >= 0.5) {
      state = (smoothed * 10).round() / 10.0;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider exposing smoothed live coaster cup weight in grams.
final liveWeightProvider = StateNotifierProvider<LiveWeightNotifier, double>((
  ref,
) {
  final coasterRepo = ref.watch(coasterRepositoryProvider);
  return LiveWeightNotifier(coasterRepository: coasterRepo);
}, dependencies: [coasterRepositoryProvider]);

/// Provider deriving whether the cup on the smart coaster is empty.
///
/// Returns `true` if:
/// - No cup is detected (< 100g on coaster load cell).
/// - Current weight is at or below the calibrated empty cup weight plus margin (<= emptyCupWeight + 5.0g).
final isCupEmptyProvider = Provider<bool>((ref) {
  final liveWeight = ref.watch(liveWeightProvider);
  const emptyCupWeight = FixedCup.emptyGrams;

  if (liveWeight < 100.0) return true;
  return liveWeight <= (emptyCupWeight + 5.0);
}, dependencies: [liveWeightProvider]);

/// Provider deriving the volume of water currently in the cup in milliliters (1g ≈ 1ml).
final cupWaterVolumeMlProvider = Provider<int>((ref) {
  final liveWeight = ref.watch(liveWeightProvider);
  const emptyCupWeight = FixedCup.emptyGrams;

  if (liveWeight < 100.0) return 0;
  final waterGrams = liveWeight - emptyCupWeight;
  return waterGrams > 0 ? waterGrams.round() : 0;
}, dependencies: [liveWeightProvider]);
