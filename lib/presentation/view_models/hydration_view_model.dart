import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';
import '../theme/liquid_tokens.dart';

/// Status of the progressive Boss Raid encounter across scaling Acts.
@immutable
class BossRaidStatus {
  const BossRaidStatus({
    required this.act,
    required this.actName,
    required this.bossName,
    required this.currentHp,
    required this.maxHp,
    required this.remainingMl,
    required this.progress,
    required this.lootName,
    required this.lootXp,
  });

  /// 1-based act index (Act 1, Act 2, Act 3...).
  final int act;

  /// Human-readable Act identifier (e.g. 'ACT I', 'ACT II', 'ACT III').
  final String actName;

  /// Boss name displayed in raid cards.
  final String bossName;

  /// Damage dealt in milliliters within the current Act.
  final int currentHp;

  /// Maximum hit points in milliliters required to defeat the current Act.
  final int maxHp;

  /// Remaining milliliters required to defeat this Act's boss.
  final int remainingMl;

  /// Normalized progress ratio clamped between 0.0 and 1.0.
  final double progress;

  /// Name of the reward loot.
  final String lootName;

  /// XP awarded upon defeating this Act.
  final int lootXp;

  /// Default starting status for Act 1.
  static const defaultStatus = BossRaidStatus(
    act: 1,
    actName: 'ACT I',
    bossName: 'Dust Imp',
    currentHp: 0,
    maxHp: 2000,
    remainingMl: 2000,
    progress: 0.0,
    lootName: 'Dewdrop Scout',
    lootXp: 250,
  );

  /// Calculates the current Act and HP progression based on total water consumed.
  ///
  /// - Act 1 starts at 2,000 ml HP.
  /// - Each subsequent Act increases in HP by +500 ml (Act 2: 2,500 ml, Act 3: 3,000 ml...).
  /// - Defeating an Act advances to the next Act and resets damage to 0.
  static const bossNames = [
    'Dust Imp',
    'Drought Beetle',
    'Sand Serpent',
    'Mirage Phantom',
    'Scorch Golem',
    'Saltwater Kraken',
    'Desert Wyvern',
    'Sunfire Titan',
    'Eclipse Hydra',
    'Drought Sovereign',
  ];
  static const badgeNames = [
    'Dewdrop Scout',
    'Oasis Guardian',
    'River Fang',
    'Mirage Breaker',
    'Crystal Heart',
    'Tidal Crest',
    'Storm Wing',
    'Solar Shield',
    'Lunar Crown',
    'Hydration Sovereign',
  ];
  static int defeatedCount(int totalMl) {
    var remaining = totalMl;
    var count = 0;
    while (count < 10 && remaining >= hpForAct(count + 1)) {
      remaining -= hpForAct(++count);
    }
    return count;
  }

  bool get isComplete => act == 10 && remainingMl == 0;

  static int hpForAct(int act) => 2000 + (act - 1) * 500;
  static int rewardForAct(int act) => 200 + act * 50;

  /// Derived from retained lifetime intake, so replay/restart cannot award twice.
  /// Corrections that undo a completed encounter also reverse its reward.
  static int earnedRewardXp(int totalMl) {
    int remaining = totalMl.clamp(0, 9999999), act = 1, xp = 0;
    while (act <= 10 && remaining >= hpForAct(act)) {
      remaining -= hpForAct(act);
      xp += rewardForAct(act++);
    }
    return xp;
  }

  static BossRaidStatus calculate(int totalDamageMl) {
    int act = 1;
    int remainingDamage = totalDamageMl.clamp(0, 9999999);

    while (true) {
      final actHp = hpForAct(act);
      if (remainingDamage < actHp || act == 10) {
        final currentActDamage = remainingDamage.clamp(0, actHp);
        final remainingToKnockout = (actHp - currentActDamage).clamp(0, actHp);
        final progress = (currentActDamage / actHp).clamp(0.0, 1.0);
        return BossRaidStatus(
          act: act,
          actName: _toRoman(act),
          bossName: bossNames[act - 1],
          currentHp: currentActDamage,
          maxHp: actHp,
          remainingMl: remainingToKnockout,
          progress: progress,
          lootName: badgeNames[act - 1],
          lootXp: rewardForAct(act),
        );
      }
      remainingDamage -= actHp;
      act++;
    }
  }

  static String _toRoman(int number) {
    const romanNumerals = [
      'ACT I',
      'ACT II',
      'ACT III',
      'ACT IV',
      'ACT V',
      'ACT VI',
      'ACT VII',
      'ACT VIII',
      'ACT IX',
      'ACT X',
    ];
    if (number >= 1 && number <= romanNumerals.length) {
      return romanNumerals[number - 1];
    }
    return 'ACT $number';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BossRaidStatus &&
          runtimeType == other.runtimeType &&
          act == other.act &&
          actName == other.actName &&
          bossName == other.bossName &&
          currentHp == other.currentHp &&
          maxHp == other.maxHp &&
          remainingMl == other.remainingMl &&
          progress == other.progress &&
          lootName == other.lootName &&
          lootXp == other.lootXp;

  @override
  int get hashCode => Object.hash(
    act,
    actName,
    bossName,
    currentHp,
    maxHp,
    remainingMl,
    progress,
    lootName,
    lootXp,
  );
}

/// Immutable presentation snapshot of the user's current hydration progress.
///
/// Named [HydrationSnapshot] to prevent collision with the domain [HydrationState] enum.
@immutable
class HydrationSnapshot {
  HydrationSnapshot({
    required this.currentMl,
    required this.goalMl,
    required this.progress,
    required this.hydrationState,
    required this.stateLabel,
    required this.isOverGoal,
    required this.isThirstQuenched,
    int? rawCurrentMl,
    this.lastSipMl,
    this.lastSipTime,
    int? xpToday,
    int? totalXp,
    int? currentLevelXp,
    int? nextLevelXp,
    int? level,
    bool? isScaleTared,
    BossRaidStatus? bossRaid,
  }) : isScaleTared = isScaleTared ?? true,
       rawCurrentMl = rawCurrentMl ?? currentMl,
       xpToday = xpToday ?? ((rawCurrentMl ?? currentMl) ~/ 8),
       totalXp = totalXp ?? ((rawCurrentMl ?? currentMl) ~/ 8),
       level =
           level ??
           calculateLevelProgress(
             totalXp ?? ((rawCurrentMl ?? currentMl) ~/ 8),
           ).level,
       currentLevelXp =
           currentLevelXp ??
           calculateLevelProgress(
             totalXp ?? ((rawCurrentMl ?? currentMl) ~/ 8),
           ).currentLevelXp,
       nextLevelXp =
           nextLevelXp ??
           calculateLevelProgress(
             totalXp ?? ((rawCurrentMl ?? currentMl) ~/ 8),
           ).nextLevelXp,
       bossRaid = bossRaid ?? BossRaidStatus.defaultStatus;

  /// Whether the coaster scale has been tared/zeroed by the user.
  final bool isScaleTared;

  /// Actual daily intake; only the visual fill ratio is capped at 100%.
  final int currentMl;

  /// Uncapped cumulative water volume from today's sips in milliliters.
  final int rawCurrentMl;

  /// User's target daily water goal in milliliters.
  final int goalMl;

  /// Progress ratio clamped to a maximum of 1.0 (100% maximum, no exceeding).
  final double progress;

  /// Dynamic progression state (e.g. Getting Started, Steady Stream, Full Reservoir).
  final HydrationState hydrationState;

  /// Human-readable label displayed prominently on the vessel.
  final String stateLabel;

  /// Whether cumulative intake meets or exceeds the daily target.
  final bool isOverGoal;

  /// Transient celebratory state active for 3 seconds following a sip.
  final bool isThirstQuenched;

  /// Volume of the most recently consumed sip, if known.
  final int? lastSipMl;

  /// Timestamp in UTC of the most recent sip, if known.
  final DateTime? lastSipTime;

  /// Today’s intake XP plus completed boss rewards.
  final int xpToday;

  /// Lifetime intake XP plus completed boss rewards.
  final int totalXp;

  /// Current progress XP towards the next level (resets to 0 when reaching a new level).
  final int currentLevelXp;

  /// Target XP required to complete the current level (scales with level: Level 1 = 100, Level 2 = 200...).
  final int nextLevelXp;

  /// User hydration level (always starts on Level 1).
  final int level;

  /// Progressive Boss Raid encounter status.
  final BossRaidStatus bossRaid;

  /// Returns the XP required to advance from [level] to [level + 1].
  ///
  /// Level 1 is easy to level up (100 XP = 800 ml), and each subsequent level
  /// requires progressively more XP (Level 2: 200 XP, Level 3: 300 XP, etc.).
  static int xpRequiredForLevel(int level) {
    final effectiveLevel = level < 1 ? 1 : level;
    return effectiveLevel * 100;
  }

  /// Calculates level, current level XP progress, and XP needed for next level from [totalXp].
  ///
  /// - Starts at Level 1 with 0 XP.
  /// - Level 1 requires 100 XP to complete.
  /// - Level 2 requires 200 XP to complete.
  /// - Level 3 requires 300 XP to complete, etc.
  /// - XP resets to 0 upon reaching each new level.
  static ({int level, int currentLevelXp, int nextLevelXp})
  calculateLevelProgress(int totalXp) {
    int lvl = 1;
    int remaining = totalXp.clamp(0, 99999999);

    while (lvl < 50) {
      final needed = xpRequiredForLevel(lvl);
      if (remaining < needed) {
        return (level: lvl, currentLevelXp: remaining, nextLevelXp: needed);
      }
      remaining -= needed;
      lvl++;
    }
    return (level: 50, currentLevelXp: 0, nextLevelXp: 0);
  }

  /// Remaining volume in milliliters required to reach the daily goal, clamped to [0, goalMl].
  int get remainingMl => (goalMl - currentMl).clamp(0, goalMl);

  /// Boss act name (e.g. 'ACT I', 'ACT II').
  String get bossAct => bossRaid.actName;

  /// Boss raid loot description.
  String get lootName => bossRaid.lootName;

  // Boss constants
  static const String bossName = 'Defeat Dehydration';

  /// Clamped progress ratio between 0.0 and 1.0 for vessel level fill animations.
  double get visualProgress => progress.clamp(0.0, 1.0);

  HydrationSnapshot copyWith({
    int? currentMl,
    int? rawCurrentMl,
    int? goalMl,
    double? progress,
    HydrationState? hydrationState,
    String? stateLabel,
    bool? isOverGoal,
    bool? isThirstQuenched,
    int? lastSipMl,
    DateTime? lastSipTime,
    int? xpToday,
    int? totalXp,
    int? currentLevelXp,
    int? nextLevelXp,
    int? level,
    bool? isScaleTared,
    BossRaidStatus? bossRaid,
  }) {
    final newRawCurrentMl = rawCurrentMl ?? currentMl ?? this.rawCurrentMl;
    final newGoalMl = goalMl ?? this.goalMl;
    final newCurrentMl = currentMl ?? newRawCurrentMl;
    final newProgress =
        progress ??
        (newGoalMl > 0 ? (newCurrentMl / newGoalMl).clamp(0.0, 1.0) : 0.0);
    final newTotalXp = totalXp ?? this.totalXp;
    final prog = calculateLevelProgress(newTotalXp);
    final newLevel = level ?? prog.level;
    final newCurrentLevelXp = currentLevelXp ?? prog.currentLevelXp;
    final newNextLevelXp = nextLevelXp ?? prog.nextLevelXp;
    final newBossRaid = bossRaid ?? this.bossRaid;

    return HydrationSnapshot(
      currentMl: newCurrentMl,
      rawCurrentMl: newRawCurrentMl,
      goalMl: newGoalMl,
      progress: newProgress,
      hydrationState: hydrationState ?? this.hydrationState,
      stateLabel: stateLabel ?? this.stateLabel,
      isOverGoal: isOverGoal ?? this.isOverGoal,
      isThirstQuenched: isThirstQuenched ?? this.isThirstQuenched,
      lastSipMl: lastSipMl ?? this.lastSipMl,
      lastSipTime: lastSipTime ?? this.lastSipTime,
      xpToday: xpToday ?? this.xpToday,
      totalXp: newTotalXp,
      currentLevelXp: newCurrentLevelXp,
      nextLevelXp: newNextLevelXp,
      level: newLevel,
      isScaleTared: isScaleTared ?? this.isScaleTared,
      bossRaid: newBossRaid,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrationSnapshot &&
          runtimeType == other.runtimeType &&
          currentMl == other.currentMl &&
          rawCurrentMl == other.rawCurrentMl &&
          goalMl == other.goalMl &&
          progress == other.progress &&
          hydrationState == other.hydrationState &&
          stateLabel == other.stateLabel &&
          isOverGoal == other.isOverGoal &&
          isThirstQuenched == other.isThirstQuenched &&
          lastSipMl == other.lastSipMl &&
          lastSipTime == other.lastSipTime &&
          xpToday == other.xpToday &&
          totalXp == other.totalXp &&
          currentLevelXp == other.currentLevelXp &&
          nextLevelXp == other.nextLevelXp &&
          level == other.level &&
          isScaleTared == other.isScaleTared &&
          bossRaid == other.bossRaid;

  @override
  int get hashCode => Object.hash(
    currentMl,
    rawCurrentMl,
    goalMl,
    progress,
    hydrationState,
    stateLabel,
    isOverGoal,
    isThirstQuenched,
    lastSipMl,
    lastSipTime,
    xpToday,
    totalXp,
    currentLevelXp,
    nextLevelXp,
    level,
    isScaleTared,
    bossRaid,
  );

  @override
  String toString() =>
      'HydrationSnapshot($currentMl/${goalMl}ml, progress: ${(progress * 100).toStringAsFixed(1)}%, state: $stateLabel, LVL $level [$currentLevelXp/$nextLevelXp XP], tared: $isScaleTared, ${bossRaid.actName})';
}

/// Daily intake and lifetime progression derived from saved records.
class HydrationViewModel extends StateNotifier<HydrationSnapshot> {
  HydrationViewModel({
    required this.historyRepository,
    required this.settingsRepository,
    required this.coasterRepository,
    this.isScaleTared = true,
  }) : super(_snapshot(historyRepository, settingsRepository)) {
    _sipsSub = historyRepository.watchTodaySips().listen((_) => _recalculate());
    _summariesSub = historyRepository.watchDailySummaries().listen(
      (_) => _recalculate(),
    );
    _settingsSub = settingsRepository.watchSettings().listen(
      (_) => _recalculate(),
    );
    _coasterSipsSub = coasterRepository.sipStream.listen((sip) {
      if (!mounted) return;
      final age = DateTime.now().toUtc().difference(sip.timestamp);
      if (age.isNegative || age > const Duration(minutes: 1)) return;
      _isThirstQuenched = true;
      _quenchTimer?.cancel();
      _quenchTimer = Timer(LiquidTokens.durationThirstQuenched, () {
        _isThirstQuenched = false;
        _recalculate();
      });
      _recalculate();
    });
  }
  final HistoryRepository historyRepository;
  final SettingsRepository settingsRepository;
  final CoasterRepository coasterRepository;

  /// Compatibility with old isolated widgets; no intake gating remains.
  final bool isScaleTared;
  static const int basePriorXp = 0;
  StreamSubscription<List<SipEvent>>? _sipsSub;
  StreamSubscription<List<DailySummary>>? _summariesSub;
  StreamSubscription<UserSettings>? _settingsSub;
  StreamSubscription<SipEvent>? _coasterSipsSub;
  Timer? _quenchTimer;
  bool _isThirstQuenched = false;
  void updateScaleTared(bool _) {
    _recalculate();
  }

  static HydrationSnapshot _snapshot(
    HistoryRepository history,
    SettingsRepository settings, {
    bool quenched = false,
  }) {
    final sips = history.currentTodaySips;
    final raw = sips.fold<int>(0, (sum, sip) => sum + sip.volumeMl);
    final goal = settings.currentSettings.dailyGoalMl;
    final total = history.currentSummaries.fold<int>(
      0,
      (sum, day) => sum + day.totalMl,
    );
    final rewardXp = BossRaidStatus.earnedRewardXp(total);
    final xp = total ~/ 8 + rewardXp;
    final level = HydrationSnapshot.calculateLevelProgress(xp);
    final phase = quenched
        ? HydrationState.thirstQuenched
        : getHydrationState(raw, goal);
    return HydrationSnapshot(
      currentMl: raw,
      rawCurrentMl: raw,
      goalMl: goal,
      progress: goal > 0 ? (raw / goal).clamp(0.0, 1.0) : 0,
      hydrationState: phase,
      stateLabel: phase.label,
      isOverGoal: goal > 0 && raw >= goal,
      isThirstQuenched: quenched,
      lastSipMl: sips.isEmpty ? null : sips.first.volumeMl,
      lastSipTime: sips.isEmpty ? null : sips.first.timestamp,
      xpToday:
          total ~/ 8 -
          (total - raw) ~/ 8 +
          rewardXp -
          BossRaidStatus.earnedRewardXp(total - raw),
      totalXp: xp,
      currentLevelXp: level.currentLevelXp,
      nextLevelXp: level.nextLevelXp,
      level: level.level,
      isScaleTared: true,
      bossRaid: BossRaidStatus.calculate(total),
    );
  }

  void _recalculate() {
    if (mounted) {
      state = _snapshot(
        historyRepository,
        settingsRepository,
        quenched: _isThirstQuenched,
      );
    }
  }

  @override
  void dispose() {
    _sipsSub?.cancel();
    _summariesSub?.cancel();
    _settingsSub?.cancel();
    _coasterSipsSub?.cancel();
    _quenchTimer?.cancel();
    super.dispose();
  }
}

final hydrationViewModelProvider =
    StateNotifierProvider<HydrationViewModel, HydrationSnapshot>(
      (ref) {
        return HydrationViewModel(
          historyRepository: ref.watch(historyRepositoryProvider),
          settingsRepository: ref.watch(settingsRepositoryProvider),
          coasterRepository: ref.watch(coasterRepositoryProvider),
        );
      },
      dependencies: [
        historyRepositoryProvider,
        settingsRepositoryProvider,
        coasterRepositoryProvider,
      ],
    );
