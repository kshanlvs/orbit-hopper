import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/neon_world.dart';
import 'profile.dart';
import 'rules.dart';

abstract class NeonRepository {
  Future<NeonProfile> load();
  Future<void> save(NeonProfile profile);
}

class SharedPrefsNeonRepository implements NeonRepository {
  SharedPrefsNeonRepository(this._prefs);

  static const key = 'neon_shift_profile_v1';

  final SharedPreferences _prefs;

  @override
  Future<NeonProfile> load() async => NeonProfile.decode(_prefs.getString(key));

  @override
  Future<void> save(NeonProfile profile) => _prefs.setString(key, profile.encode());
}

/// Holds the player's Neon Shift profile and writes every change through.
class NeonCubit extends Cubit<NeonProfile> {
  NeonCubit(this._repo, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const NeonProfile());

  final NeonRepository _repo;
  final DateTime Function() _clock;

  DailyChallenge get today => DailyChallenge.forDate(_clock());

  bool get dailyDoneToday => state.dailyDate == today.date && state.dailyDone;
  int get dailyBestToday => state.dailyDate == today.date ? state.dailyBest : 0;

  Future<void> load() async => emit(await _repo.load());

  Future<RunReward> recordRun(RunSummary run) async {
    final (next, reward) = NeonRules.applyRun(state, run, today: today);
    emit(next);
    await _repo.save(next);
    return reward;
  }

  Future<PurchaseResult> skin(String id) => _apply(NeonRules.buyOrEquipSkin(state, id));
  Future<PurchaseResult> trail(String id) => _apply(NeonRules.buyOrEquipTrail(state, id));
  Future<PurchaseResult> dimension(String id) => _apply(NeonRules.selectDimension(state, id));

  Future<void> settings(NeonSettings s) async {
    final next = state.copyWith(settings: s);
    emit(next);
    await _repo.save(next);
  }

  Future<PurchaseResult> _apply((NeonProfile, PurchaseResult) r) async {
    final (next, result) = r;
    if (result == PurchaseResult.bought || result == PurchaseResult.equipped) {
      emit(next);
      await _repo.save(next);
    }
    return result;
  }
}
