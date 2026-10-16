import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/fake/seed_data.dart';
import '../../data/providers.dart';
import '../../domain/domain.dart';

/// Presentation tare ritual state machine phases (Pillar 4).
/// Preserved as legacy enum for test backwards-compatibility.
enum TareState {
  /// Normal idle state before user initiates calibration.
  idle,

  /// Prompt modal active: "Place your empty cup on the coaster".
  prompting,

  /// Actively taking zeroing/tare measurements with live settling animation.
  measuring,

  /// Calibration completed successfully ("Cup Tare Zeroed ✓ 350 g").
  success,

  /// Tare failed (unstable surface, cup out of range).
  failure,

  /// Tare timed out before finding stable reading.
  timeout,

  /// Coaster hardware disconnected.
  disconnected,
}

/// Declarative, pattern-matchable sealed hierarchy representing the tare ritual state machine.
/// This is the primary single source of truth for all calibration UI in Pillar 4.
@immutable
sealed class TareRitualState {
  const TareRitualState();

  /// Maps directly to the legacy [TareState] enum without maintaining dual state fields.
  TareState get legacyState;
}

/// Normal idle state: ready to calibrate.
class TareIdle extends TareRitualState {
  const TareIdle();

  @override
  TareState get legacyState => TareState.idle;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TareIdle;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'TareIdle()';
}

/// Prompt phase: instructing user to place empty cup on coaster.
class TarePrompt extends TareRitualState {
  const TarePrompt();

  @override
  TareState get legacyState => TareState.prompting;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TarePrompt;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'TarePrompt()';
}

/// Active measuring phase: live load cell readings converging to zero tare.
class TareMeasuring extends TareRitualState {
  const TareMeasuring({this.liveGrams});

  /// Live weight reading in grams while scale stabilizes.
  final double? liveGrams;

  @override
  TareState get legacyState => TareState.measuring;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TareMeasuring && other.liveGrams == liveGrams;

  @override
  int get hashCode => liveGrams.hashCode;

  @override
  String toString() => 'TareMeasuring(liveGrams: ${liveGrams}g)';
}

/// Calibration success phase: scale zeroed with confirmed empty cup weight.
class TareSuccess extends TareRitualState {
  const TareSuccess({required this.taredGrams});

  /// Final calibrated empty cup weight in grams.
  final double taredGrams;

  @override
  TareState get legacyState => TareState.success;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TareSuccess && other.taredGrams == taredGrams;

  @override
  int get hashCode => taredGrams.hashCode;

  @override
  String toString() => 'TareSuccess(taredGrams: ${taredGrams}g)';
}

/// Calibration failed: unstable surface, weight out of bounds, etc.
class TareFailure extends TareRitualState {
  const TareFailure({required this.errorMessage});

  final String errorMessage;

  @override
  TareState get legacyState => TareState.failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TareFailure && other.errorMessage == errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;

  @override
  String toString() => 'TareFailure($errorMessage)';
}

/// Calibration timed out before receiving a stable reading.
class TareTimeout extends TareRitualState {
  const TareTimeout({required this.errorMessage});

  final String errorMessage;

  @override
  TareState get legacyState => TareState.timeout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TareTimeout && other.errorMessage == errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;

  @override
  String toString() => 'TareTimeout($errorMessage)';
}

/// Coaster hardware disconnected.
class TareDisconnected extends TareRitualState {
  const TareDisconnected();

  @override
  TareState get legacyState => TareState.disconnected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TareDisconnected;

  @override
  int get hashCode => 6;

  @override
  String toString() => 'TareDisconnected()';
}

/// Presentation state for the Settings screen.
@immutable
class SettingsViewState {
  const SettingsViewState({
    required this.dailyGoalMl,
    required this.inactivityThresholdMinutes,
    required this.adaptiveRemindersEnabled,
    this.portionLimitMl = UserSettings.defaultPortionLimitMl,
    this.ritualState = const TareIdle(),
    this.isConnected = true,
    this.isScaleTared = false,
    this.calibratedCupWeightGrams,
  });

  /// Target water goal in ml (1000..4000).
  final int dailyGoalMl;

  /// Reminder threshold in minutes (15..120).
  final int inactivityThresholdMinutes;

  /// Whether smart adaptive nudges are enabled.
  final bool adaptiveRemindersEnabled;

  /// Quick sip volume and portion limit in ml (50..500).
  final int portionLimitMl;

  /// Tare ritual workflow state (primary single source of truth).
  final TareRitualState ritualState;

  /// Whether the coaster scale is currently connected.
  final bool isConnected;

  /// Whether the empty cup has been tared/zeroed by the user.
  final bool isScaleTared;

  /// Persisted empty cup weight in grams from calibration.
  final double? calibratedCupWeightGrams;

  /// Pure computed getter deriving legacy [TareState] enum directly from [ritualState].
  TareState get tareState =>
      isConnected ? ritualState.legacyState : TareState.disconnected;

  /// Measured empty cup weight in grams on tare success, falling back to default 350g.
  double get calibratedGrams =>
      calibratedCupWeightGrams ??
      switch (ritualState) {
        TareSuccess(:final taredGrams) => taredGrams,
        _ => SeedData.defaultCupWeightGrams,
      };

  /// Error message on tare failure or timeout.
  String? get tareErrorMessage => switch (ritualState) {
    TareFailure(:final errorMessage) => errorMessage,
    TareTimeout(:final errorMessage) => errorMessage,
    _ => null,
  };

  /// Live weight reading during active calibration.
  double? get liveMeasuringWeight => switch (ritualState) {
    TareMeasuring(:final liveGrams) => liveGrams,
    _ => null,
  };

  SettingsViewState copyWith({
    int? dailyGoalMl,
    int? inactivityThresholdMinutes,
    bool? adaptiveRemindersEnabled,
    int? portionLimitMl,
    TareRitualState? ritualState,
    TareState? tareState,
    double? calibratedGrams,
    String? tareErrorMessage,
    bool? isConnected,
    bool? isScaleTared,
    double? calibratedCupWeightGrams,
  }) {
    TareRitualState resolvedRitual = ritualState ?? this.ritualState;
    if (ritualState == null && tareState != null) {
      switch (tareState) {
        case TareState.idle:
          resolvedRitual = const TareIdle();
        case TareState.prompting:
          resolvedRitual = const TarePrompt();
        case TareState.measuring:
          resolvedRitual = TareMeasuring(liveGrams: liveMeasuringWeight);
        case TareState.success:
          resolvedRitual = TareSuccess(
            taredGrams: calibratedGrams ?? this.calibratedGrams,
          );
        case TareState.failure:
          resolvedRitual = TareFailure(
            errorMessage:
                tareErrorMessage ??
                this.tareErrorMessage ??
                'Calibration failed. Please retry.',
          );
        case TareState.timeout:
          resolvedRitual = TareTimeout(
            errorMessage:
                tareErrorMessage ??
                this.tareErrorMessage ??
                'Calibration timed out.',
          );
        case TareState.disconnected:
          resolvedRitual = const TareDisconnected();
      }
    }

    return SettingsViewState(
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      inactivityThresholdMinutes:
          inactivityThresholdMinutes ?? this.inactivityThresholdMinutes,
      adaptiveRemindersEnabled:
          adaptiveRemindersEnabled ?? this.adaptiveRemindersEnabled,
      portionLimitMl: portionLimitMl ?? this.portionLimitMl,
      ritualState: resolvedRitual,
      isConnected: isConnected ?? this.isConnected,
      isScaleTared: isScaleTared ?? this.isScaleTared,
      calibratedCupWeightGrams:
          calibratedCupWeightGrams ?? this.calibratedCupWeightGrams,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsViewState &&
          runtimeType == other.runtimeType &&
          dailyGoalMl == other.dailyGoalMl &&
          inactivityThresholdMinutes == other.inactivityThresholdMinutes &&
          adaptiveRemindersEnabled == other.adaptiveRemindersEnabled &&
          portionLimitMl == other.portionLimitMl &&
          ritualState == other.ritualState &&
          isConnected == other.isConnected &&
          isScaleTared == other.isScaleTared &&
          calibratedCupWeightGrams == other.calibratedCupWeightGrams;

  @override
  int get hashCode => Object.hash(
    dailyGoalMl,
    inactivityThresholdMinutes,
    adaptiveRemindersEnabled,
    portionLimitMl,
    ritualState,
    isConnected,
    isScaleTared,
    calibratedCupWeightGrams,
  );
}

/// Reactive ViewModel managing user settings and the empty cup tare ritual.
class SettingsViewModel extends StateNotifier<SettingsViewState> {
  SettingsViewModel({
    required this.settingsRepository,
    required this.coasterRepository,
    bool isScaleTared = false,
  }) : super(
         SettingsViewState(
           dailyGoalMl: settingsRepository.currentSettings.dailyGoalMl,
           inactivityThresholdMinutes:
               settingsRepository.currentSettings.inactivityThresholdMinutes,
           adaptiveRemindersEnabled:
               settingsRepository.currentSettings.adaptiveRemindersEnabled,
           portionLimitMl: settingsRepository.currentSettings.portionLimitMl,
           isConnected: coasterRepository.currentConnection.isConnected,
           isScaleTared: isScaleTared,
           ritualState: coasterRepository.currentConnection.isConnected
               ? const TareIdle()
               : const TareDisconnected(),
         ),
       ) {
    _init();
  }

  final SettingsRepository settingsRepository;
  final CoasterRepository coasterRepository;

  StreamSubscription<UserSettings>? _settingsSub;
  StreamSubscription<CoasterConnection>? _connSub;
  StreamSubscription<CupWeightReading>? _weightSub;
  Timer? _autoRevertTimer;
  bool _isCalibrating = false;

  void _init() {
    _settingsSub = settingsRepository.watchSettings().listen((settings) {
      if (!mounted) return;
      state = state.copyWith(
        dailyGoalMl: settings.dailyGoalMl,
        inactivityThresholdMinutes: settings.inactivityThresholdMinutes,
        adaptiveRemindersEnabled: settings.adaptiveRemindersEnabled,
        portionLimitMl: settings.portionLimitMl,
      );
    });

    _connSub = coasterRepository.connectionStream.listen((conn) {
      if (!mounted) return;
      final connected = conn.isConnected;
      if (!connected) {
        // Connection dropped mid-session: cancel active measuring/prompt
        _cancelActiveCalibrationRoutine();
        state = state.copyWith(
          isConnected: false,
          ritualState: const TareDisconnected(),
        );
      } else {
        final wasDisconnected = !state.isConnected;
        state = state.copyWith(
          isConnected: true,
          ritualState: wasDisconnected && state.ritualState is TareDisconnected
              ? const TareIdle()
              : state.ritualState,
        );
      }
    });
  }

  /// Adjusts portion limit by [delta] ml, clamped to valid bounds [50, 500],
  /// and persists to disk.
  Future<void> adjustPortionLimit(int delta) async {
    final current = settingsRepository.currentSettings;
    final newLimit = (current.portionLimitMl + delta).clamp(
      UserSettings.minPortionLimitMl,
      UserSettings.maxPortionLimitMl,
    );
    state = state.copyWith(portionLimitMl: newLimit);
    await settingsRepository.updateSettings(
      current.copyWith(portionLimitMl: newLimit),
    );
  }

  /// Ephemeral preview update during live drag: updates UI readout at 60/120 fps
  /// without triggering disk I/O or downstream screen re-tweens.
  void previewDailyGoal(int goalMl) {
    final clamped = goalMl.clamp(
      UserSettings.minDailyGoalMl,
      UserSettings.maxDailyGoalMl,
    );
    state = state.copyWith(dailyGoalMl: clamped);
  }

  /// Commits daily water goal to disk via [SettingsRepository] on drag release.
  Future<void> updateDailyGoal(int goalMl) async {
    final clamped = goalMl.clamp(
      UserSettings.minDailyGoalMl,
      UserSettings.maxDailyGoalMl,
    );
    state = state.copyWith(dailyGoalMl: clamped);
    final current = settingsRepository.currentSettings;
    try {
      await settingsRepository.updateSettings(
        current.copyWith(dailyGoalMl: clamped),
      );
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          dailyGoalMl: settingsRepository.currentSettings.dailyGoalMl,
        );
      }
      rethrow;
    }
  }

  /// Ephemeral preview update during live drag for inactivity threshold.
  void previewInactivityThreshold(int minutes) {
    final safeMinutes = minutes.clamp(15, 120);
    state = state.copyWith(inactivityThresholdMinutes: safeMinutes);
  }

  /// Commits inactivity threshold slider value to disk on drag release.
  Future<void> updateInactivityThreshold(int minutes) async {
    final safeMinutes = minutes.clamp(15, 120);
    state = state.copyWith(inactivityThresholdMinutes: safeMinutes);
    final current = settingsRepository.currentSettings;
    await settingsRepository.updateSettings(
      current.copyWith(inactivityThresholdMinutes: safeMinutes),
    );
  }

  /// Toggles adaptive smart reminders and persists to disk.
  Future<void> toggleAdaptiveReminders(bool enabled) async {
    final current = settingsRepository.currentSettings;
    await settingsRepository.updateSettings(
      current.copyWith(adaptiveRemindersEnabled: enabled),
    );
  }

  /// Enters prompting state: "Place your empty cup on the coaster".
  void promptCalibration() {
    if (!state.isConnected) return;
    _clearAutoRevertTimer();
    state = state.copyWith(ritualState: const TarePrompt());
  }

  /// Alias for [promptCalibration] in the modal workflow.
  void promptTare() => promptCalibration();

  /// Confirms the prompt modal and triggers hardware tare measurement.
  Future<void> confirmTare() => startCalibration();

  /// Executes calibration on coaster hardware and steps through the state machine.
  /// Debounces rapid multiple taps to prevent concurrent hardware calls.
  Future<void> startCalibration() async {
    if (!state.isConnected) {
      state = state.copyWith(ritualState: const TareDisconnected());
      return;
    }

    if (_isCalibrating) return; // Debounce rapid consecutive taps
    _isCalibrating = true;
    _clearAutoRevertTimer();

    state = state.copyWith(ritualState: const TareMeasuring());

    // Listen to live load cell weight updates during calibration
    _weightSub?.cancel();
    _weightSub = coasterRepository.weightStream.listen((reading) {
      if (!mounted) return;
      if (state.ritualState is TareMeasuring) {
        state = state.copyWith(
          ritualState: TareMeasuring(liveGrams: reading.grams),
        );
      }
    });

    try {
      final result = await coasterRepository.calibrate();

      if (!mounted) return;

      // If connection dropped during calibration, state has already transitioned to TareDisconnected
      if (!state.isConnected) return;

      _weightSub?.cancel();
      _weightSub = null;

      switch (result.status) {
        case CalibrationStatus.success:
          state = state.copyWith(
            isScaleTared: true,
            calibratedCupWeightGrams:
                result.measuredGrams ?? SeedData.defaultCupWeightGrams,
            ritualState: TareSuccess(taredGrams: result.measuredGrams ?? 0.0),
          );
          _scheduleAutoRevertToIdle();
          break;
        case CalibrationStatus.failure:
          state = state.copyWith(
            ritualState: TareFailure(
              errorMessage:
                  result.errorMessage ?? 'Calibration failed. Please retry.',
            ),
          );
          break;
        case CalibrationStatus.timeout:
          state = state.copyWith(
            ritualState: TareTimeout(
              errorMessage: result.errorMessage ?? 'Calibration timed out.',
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted && state.isConnected) {
        state = state.copyWith(
          ritualState: TareFailure(errorMessage: e.toString()),
        );
      }
    } finally {
      _isCalibrating = false;
      _weightSub?.cancel();
      _weightSub = null;
    }
  }

  /// Direct trigger that starts measuring without showing the prompt modal.
  Future<void> startDirectCalibration() => startCalibration();

  /// Resets tare ritual back to idle.
  void resetCalibration() {
    _clearAutoRevertTimer();
    _cancelActiveCalibrationRoutine();
    state = state.copyWith(
      ritualState: state.isConnected
          ? const TareIdle()
          : const TareDisconnected(),
    );
  }

  /// Aliases for [resetCalibration].
  void resetTare() => resetCalibration();
  void cancelTare() => resetCalibration();

  void _scheduleAutoRevertToIdle() {
    _clearAutoRevertTimer();
    _autoRevertTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && state.ritualState is TareSuccess) {
        resetCalibration();
      }
    });
  }

  void _clearAutoRevertTimer() {
    _autoRevertTimer?.cancel();
    _autoRevertTimer = null;
  }

  void _cancelActiveCalibrationRoutine() {
    _isCalibrating = false;
    _weightSub?.cancel();
    _weightSub = null;
  }

  @override
  void dispose() {
    _clearAutoRevertTimer();
    _cancelActiveCalibrationRoutine();
    _settingsSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}

/// Provider exposing [SettingsViewState].
final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsViewState>((ref) {
      final settingsRepo = ref.watch(settingsRepositoryProvider);
      final coasterRepo = ref.watch(coasterRepositoryProvider);

      return SettingsViewModel(
        settingsRepository: settingsRepo,
        coasterRepository: coasterRepo,
      );
    }, dependencies: [settingsRepositoryProvider, coasterRepositoryProvider]);
