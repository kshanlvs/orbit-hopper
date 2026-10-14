import 'package:flutter_bloc/flutter_bloc.dart';

import '../../game/logic/cosmos.dart';

enum RunStatus { playing, paused, over }

/// A real place the player just landed on (or departs from), shown as a card.
class Discovery {
  const Discovery({
    required this.landmarkIndex,
    required this.isNew,
    required this.factIndex,
    required this.id,
    this.isDeparture = false,
  });

  final int landmarkIndex;
  final bool isNew;
  final int factIndex;
  final bool isDeparture;

  /// Unique per discovery so the UI can tell two cards apart.
  final int id;
}

class RunState {
  const RunState({
    this.status = RunStatus.playing,
    this.score = 0,
    this.combo = 0,
    this.stardust = 0,
    this.bestIndex = 0,
    this.travelIndex = 0,
    this.startLandmark = 0,
    this.discovery,
    this.isNewBest = false,
    this.earnedStardust = 0,
    this.bestScore = 0,
    this.deathReason = '',
  });

  final RunStatus status;
  final int score;
  final int combo;
  final int stardust;

  /// Furthest planet reached this run (drives distance / journey HUD).
  final int bestIndex;

  /// Live, fractional journey position (updates during flight).
  final double travelIndex;

  /// Checkpoint this run started from.
  final int startLandmark;
  final Discovery? discovery;
  final bool isNewBest;
  final int earnedStardust;
  final int bestScore;
  final String deathReason;

  RunState copyWith({
    RunStatus? status,
    int? score,
    int? combo,
    int? stardust,
    int? bestIndex,
    double? travelIndex,
    int? startLandmark,
    Discovery? discovery,
    bool clearDiscovery = false,
    bool? isNewBest,
    int? earnedStardust,
    int? bestScore,
    String? deathReason,
  }) {
    return RunState(
      status: status ?? this.status,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      stardust: stardust ?? this.stardust,
      bestIndex: bestIndex ?? this.bestIndex,
      travelIndex: travelIndex ?? this.travelIndex,
      startLandmark: startLandmark ?? this.startLandmark,
      discovery: clearDiscovery ? null : (discovery ?? this.discovery),
      isNewBest: isNewBest ?? this.isNewBest,
      earnedStardust: earnedStardust ?? this.earnedStardust,
      bestScore: bestScore ?? this.bestScore,
      deathReason: deathReason ?? this.deathReason,
    );
  }
}

/// State of the current run, fed by callbacks from the Flame game.
class RunCubit extends Cubit<RunState> {
  RunCubit() : super(const RunState());

  int _discoveryCounter = 0;

  void scoreChanged(int score, int combo) => emit(state.copyWith(score: score, combo: combo));

  void stardustChanged(int stardust) => emit(state.copyWith(stardust: stardust));

  void journeyChanged(int bestIndex) => emit(state.copyWith(bestIndex: bestIndex));

  void travelChanged(double travelIndex) {
    if ((travelIndex - state.travelIndex).abs() > 0.004) emit(state.copyWith(travelIndex: travelIndex));
  }

  void departed(int landmarkIndex) {
    emit(state.copyWith(
      discovery: Discovery(
        landmarkIndex: landmarkIndex,
        isNew: false,
        factIndex: 0,
        id: ++_discoveryCounter,
        isDeparture: true,
      ),
    ));
  }

  void discovered({required int landmarkIndex, required bool isNew, required int factIndex}) {
    emit(state.copyWith(
      discovery: Discovery(
        landmarkIndex: landmarkIndex,
        isNew: isNew,
        factIndex: factIndex,
        id: ++_discoveryCounter,
      ),
    ));
  }

  void dismissDiscovery(int id) {
    if (state.discovery?.id == id) emit(state.copyWith(clearDiscovery: true));
  }

  void pause() {
    if (state.status == RunStatus.playing) emit(state.copyWith(status: RunStatus.paused));
  }

  void resume() {
    if (state.status == RunStatus.paused) emit(state.copyWith(status: RunStatus.playing));
  }

  void restart({required int startLandmark}) {
    final start = startLandmark * hopsPerLandmark;
    emit(RunState(
      startLandmark: startLandmark,
      bestIndex: start,
      travelIndex: start.toDouble(),
    ));
  }

  void finish({
    required bool isNewBest,
    required int earnedStardust,
    required int bestScore,
    required String deathReason,
  }) {
    emit(state.copyWith(
      status: RunStatus.over,
      clearDiscovery: true,
      isNewBest: isNewBest,
      earnedStardust: earnedStardust,
      bestScore: bestScore,
      deathReason: deathReason,
    ));
  }
}
