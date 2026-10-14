import '../entities/player_progress.dart';

abstract interface class ProgressRepository {
  Future<PlayerProgress> load();
  Future<void> save(PlayerProgress progress);
}
