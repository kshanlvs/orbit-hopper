import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/comet_skin.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/player_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../game/audio/game_audio.dart';
import '../../game/logic/cosmos.dart';
import '../../game/logic/models.dart';

/// Long-lived player progress: best score, stardust wallet, skins.
class ProgressCubit extends Cubit<PlayerProgress> {
  ProgressCubit(this._repository) : super(PlayerProgress.initial());

  final ProgressRepository _repository;

  Future<void> load() async {
    emit(await _repository.load());
    await _topUpMissions();
  }

  static const missionSlots = 3;

  /// Keeps three active missions, generating new ones as needed.
  Future<void> _topUpMissions() async {
    if (state.missions.length >= missionSlots) return;
    final missions = [...state.missions];
    var serial = state.missionSerial;
    while (missions.length < missionSlots) {
      missions.add(_newMission(serial++, missions));
    }
    final next = state.copyWith(missions: missions, missionSerial: serial);
    emit(next);
    await _repository.save(next);
  }

  Mission _newMission(int serial, List<Mission> active) {
    final exclude = {for (final m in active) m.kind};
    return Mission.generate(serial: serial, completed: state.missionsCompleted, exclude: exclude);
  }

  /// Marks [mission] done: pays its reward and replaces it with a new one.
  Future<void> completeMission(Mission mission) async {
    final i = state.missions.indexWhere((m) => m.encode() == mission.encode());
    if (i < 0) return;
    final missions = [...state.missions]..removeAt(i);
    final replacement = _newMission(state.missionSerial, missions);
    missions.insert(i, replacement);
    final next = state.copyWith(
      missions: missions,
      missionSerial: state.missionSerial + 1,
      missionsCompleted: state.missionsCompleted + 1,
      stardust: state.stardust + mission.reward,
    );
    emit(next);
    await _repository.save(next);
  }

  /// Earth saved: pays the reward and raises the threat level.
  /// Returns the reward that was paid.
  Future<int> defenseWon(int level) async {
    final reward = DefenseConfig(level: level).reward;
    final next = state.copyWith(
      stardust: state.stardust + reward,
      defenseLevel: state.defenseLevel + 1,
      earthsSaved: state.earthsSaved + 1,
    );
    emit(next);
    await _repository.save(next);
    return reward;
  }

  /// Black Hole run finished. Returns true if it was the biggest ever.
  Future<bool> recordHoleRun({required double maxRadius, required int stardustEarned}) async {
    final isNewBest = maxRadius > state.holeBestRadius;
    final next = state.copyWith(
      holeBestRadius: math.max(maxRadius, state.holeBestRadius),
      stardust: state.stardust + stardustEarned,
    );
    emit(next);
    await _repository.save(next);
    return isNewBest;
  }

  /// Furthest real place ever discovered (journey index).
  int get furthestDiscovered {
    var best = 0;
    for (final id in state.discoveredIds) {
      final k = Cosmos.indexOfId(id);
      if (k > best) best = k;
    }
    return best;
  }

  /// Signal fragments decoded (the alien story).
  int get fragmentsDecoded => Cosmos.fragmentsDecoded(isDiscovered);

  /// Uncharted worlds found beyond the edge.
  int get unchartedFound => state.discoveredIds.where((id) => id.startsWith('beyond_')).length;

  /// Pays a milestone reward when [landmarkIndex] completes a chapter.
  /// Call once, on the first discovery of that place.
  Future<Chapter?> claimMilestone(int landmarkIndex) async {
    final c = Cosmos.chapterEndingAt(landmarkIndex);
    if (c == null) return null;
    final next = state.copyWith(stardust: state.stardust + c.reward);
    emit(next);
    await _repository.save(next);
    return c;
  }

  String get rank => Cosmos.rankFor(furthestDiscovered);

  /// Saves a finished run. Returns true when it set a new best score.
  Future<bool> recordRun({required int score, required int stardustEarned}) async {
    final isNewBest = score > state.bestScore;
    final next = state.copyWith(
      bestScore: math.max(score, state.bestScore),
      stardust: state.stardust + stardustEarned,
      gamesPlayed: state.gamesPlayed + 1,
    );
    emit(next);
    await _repository.save(next);
    return isNewBest;
  }

  Future<void> toggleSound() async {
    final next = state.copyWith(soundOn: !state.soundOn);
    emit(next);
    await GameAudio.instance.setEnabled(next.soundOn);
    await _repository.save(next);
  }

  /// Stardust bonus for landing somewhere real for the first time.
  static const discoveryBonus = 10;

  /// Records a real place. Returns true the first time it is ever reached.
  /// A newly discovered place also becomes the launch checkpoint when it is
  /// further than the current one, so the journey always moves forward.
  Future<bool> discover(String landmarkId) async {
    if (state.discoveredIds.contains(landmarkId)) return false;
    final further = Cosmos.indexOfId(landmarkId) > launchIndex;
    final next = state.copyWith(
      discoveredIds: {...state.discoveredIds, landmarkId},
      stardust: state.stardust + discoveryBonus,
      launchFromId: further ? landmarkId : null,
    );
    emit(next);
    await _repository.save(next);
    return true;
  }

  /// Journey index of the current launch checkpoint.
  int get launchIndex {
    final id = state.launchFromId;
    if (id != 'sun' && !state.discoveredIds.contains(id)) return 0;
    return Cosmos.indexOfId(id);
  }

  bool isDiscovered(int landmarkIndex) =>
      landmarkIndex == 0 || state.discoveredIds.contains(Cosmos.place(landmarkIndex).id);

  Future<void> setLaunchFrom(int landmarkIndex) async {
    if (!isDiscovered(landmarkIndex)) return;
    final next = state.copyWith(launchFromId: Cosmos.place(landmarkIndex).id);
    emit(next);
    await _repository.save(next);
  }

  bool owns(CometSkin skin) => state.unlockedSkinIds.contains(skin.id);

  Future<void> select(CometSkin skin) async {
    if (!owns(skin)) return;
    final next = state.copyWith(selectedSkinId: skin.id);
    emit(next);
    await _repository.save(next);
  }

  /// Buys (and equips) a skin. Returns false if the player can't afford it.
  Future<bool> purchase(CometSkin skin) async {
    if (owns(skin)) {
      await select(skin);
      return true;
    }
    if (state.stardust < skin.cost) return false;
    final next = state.copyWith(
      stardust: state.stardust - skin.cost,
      unlockedSkinIds: {...state.unlockedSkinIds, skin.id},
      selectedSkinId: skin.id,
    );
    emit(next);
    await _repository.save(next);
    return true;
  }
}
