/// Freshness phase indicating time elapsed since the most recent sip
/// relative to the user's inactivity threshold.
enum FreshnessPhase {
  /// 0% - 50% of threshold elapsed. Crisp, hydrated, fresh state.
  fresh('Fresh'),

  /// >50% - 100% of threshold elapsed. Gradually desaturating/dimming state.
  fading('Fading'),

  /// >100% of threshold elapsed. Gentle dry state prompting a nudge.
  dry('Dry');

  const FreshnessPhase(this.label);

  /// Human-readable label.
  final String label;
}
