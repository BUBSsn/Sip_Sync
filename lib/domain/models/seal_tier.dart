/// Archive milestone seal tier for daily completion status.
enum SealTier {
  /// 100%+ completion: Glowing water seal.
  goalMet('Goal Met!'),

  /// 80% - 99% completion: Partial completion ring.
  almostThere('Almost there!'),

  /// <80% completion: Muted state.
  underGoal('In Progress');

  const SealTier(this.statusText);

  /// Status description matching visual reference copy.
  final String statusText;
}
