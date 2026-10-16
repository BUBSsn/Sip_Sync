/// Dynamic hydration progression state labels driven by daily intake vs goal.
enum HydrationState {
  /// 0% - 24% of daily goal.
  gettingStarted('Just Getting Started'),

  /// 25% - 49% of daily goal.
  steadyStream('Steady Stream'),

  /// 50% - 79% of daily goal.
  optimalFlow('Optimal Flow'),

  /// 80% - 99% of daily goal.
  nearlyFull('Nearly Full'),

  /// 100%+ of daily goal.
  fullReservoir('Full Reservoir'),

  /// Transient celebratory state displayed briefly after a sip event.
  thirstQuenched('Thirst Quenched');

  const HydrationState(this.label);

  /// User-facing display string for the state.
  final String label;
}
