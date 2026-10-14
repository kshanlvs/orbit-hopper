import 'mission.dart';

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
    this.missions = const <Mission>[],
    this.missionSerial = 0,
    this.missionsCompleted = 0,
    this.defenseLevel = 1,
    this.earthsSaved = 0,
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

  /// The three active missions.
  final List<Mission> missions;
  final int missionSerial;
  final int missionsCompleted;

  /// "Save Earth" threat level (goes up after each win) and total wins.
  final int defenseLevel;
  final int earthsSaved;

  PlayerProgress copyWith({
    int? bestScore,
    int? stardust,
    int? gamesPlayed,
    Set<String>? unlockedSkinIds,
    String? selectedSkinId,
    bool? soundOn,
    Set<String>? discoveredIds,
    String? launchFromId,
    List<Mission>? missions,
    int? missionSerial,
    int? missionsCompleted,
    int? defenseLevel,
    int? earthsSaved,
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
      missions: missions ?? this.missions,
      missionSerial: missionSerial ?? this.missionSerial,
      missionsCompleted: missionsCompleted ?? this.missionsCompleted,
      defenseLevel: defenseLevel ?? this.defenseLevel,
      earthsSaved: earthsSaved ?? this.earthsSaved,
    );
  }
}
