class PlayerProgress {
  const PlayerProgress({
    required this.bestScore,
    required this.stardust,
    required this.gamesPlayed,
    required this.unlockedSkinIds,
    required this.selectedSkinId,
    this.soundOn = true,
    this.discoveredIds = const <String>{},
    this.launchFromId = 'sun',
  });

  factory PlayerProgress.initial() => const PlayerProgress(
        bestScore: 0,
        stardust: 0,
        gamesPlayed: 0,
        unlockedSkinIds: {'ice'},
        selectedSkinId: 'ice',
        soundOn: true,
      );

  final int bestScore;
  final int stardust;
  final int gamesPlayed;
  final Set<String> unlockedSkinIds;
  final String selectedSkinId;
  final bool soundOn;

  /// Real places (landmark ids) the player has landed on at least once.
  final Set<String> discoveredIds;

  /// Checkpoint the next run starts from (a discovered landmark id).
  final String launchFromId;

  PlayerProgress copyWith({
    int? bestScore,
    int? stardust,
    int? gamesPlayed,
    Set<String>? unlockedSkinIds,
    String? selectedSkinId,
    bool? soundOn,
    Set<String>? discoveredIds,
    String? launchFromId,
  }) {
    return PlayerProgress(
      bestScore: bestScore ?? this.bestScore,
      stardust: stardust ?? this.stardust,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      unlockedSkinIds: unlockedSkinIds ?? this.unlockedSkinIds,
      selectedSkinId: selectedSkinId ?? this.selectedSkinId,
      soundOn: soundOn ?? this.soundOn,
      discoveredIds: discoveredIds ?? this.discoveredIds,
      launchFromId: launchFromId ?? this.launchFromId,
    );
  }
}
