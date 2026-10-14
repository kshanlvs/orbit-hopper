import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player_progress.dart';
import '../../domain/repositories/progress_repository.dart';

class SharedPrefsProgressRepository implements ProgressRepository {
  SharedPrefsProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kBest = 'oh_best_score';
  static const _kStardust = 'oh_stardust';
  static const _kGames = 'oh_games_played';
  static const _kUnlocked = 'oh_unlocked_skins';
  static const _kSelected = 'oh_selected_skin';
  static const _kSound = 'oh_sound_on';
  static const _kDiscovered = 'oh_discovered';
  static const _kLaunchFrom = 'oh_launch_from';

  @override
  Future<PlayerProgress> load() async {
    final initial = PlayerProgress.initial();
    final unlocked = _prefs.getStringList(_kUnlocked) ?? const <String>[];
    return PlayerProgress(
      bestScore: _prefs.getInt(_kBest) ?? 0,
      stardust: _prefs.getInt(_kStardust) ?? 0,
      gamesPlayed: _prefs.getInt(_kGames) ?? 0,
      unlockedSkinIds: {...initial.unlockedSkinIds, ...unlocked},
      selectedSkinId: _prefs.getString(_kSelected) ?? initial.selectedSkinId,
      soundOn: _prefs.getBool(_kSound) ?? true,
      discoveredIds: (_prefs.getStringList(_kDiscovered) ?? const <String>[]).toSet(),
      launchFromId: _prefs.getString(_kLaunchFrom) ?? 'sun',
    );
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    await Future.wait([
      _prefs.setInt(_kBest, progress.bestScore),
      _prefs.setInt(_kStardust, progress.stardust),
      _prefs.setInt(_kGames, progress.gamesPlayed),
      _prefs.setStringList(_kUnlocked, progress.unlockedSkinIds.toList()),
      _prefs.setString(_kSelected, progress.selectedSkinId),
      _prefs.setBool(_kSound, progress.soundOn),
      _prefs.setStringList(_kDiscovered, progress.discoveredIds.toList()),
      _prefs.setString(_kLaunchFrom, progress.launchFromId),
    ]);
  }
}
