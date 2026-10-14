import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/comet_skin.dart';
import '../../domain/entities/player_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../game/audio/game_audio.dart';
import '../../game/logic/cosmos.dart';

/// Long-lived player progress: best score, stardust wallet, skins.
class ProgressCubit extends Cubit<PlayerProgress> {
  ProgressCubit(this._repository) : super(PlayerProgress.initial());

  final ProgressRepository _repository;

  Future<void> load() async => emit(await _repository.load());

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
      landmarkIndex == 0 || state.discoveredIds.contains(journey[landmarkIndex].id);

  Future<void> setLaunchFrom(int landmarkIndex) async {
    if (!isDiscovered(landmarkIndex)) return;
    final next = state.copyWith(launchFromId: journey[landmarkIndex].id);
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
