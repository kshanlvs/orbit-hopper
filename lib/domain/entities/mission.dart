import 'dart:math' as math;

import '../../game/logic/models.dart';

enum MissionKind { perfects, combo, stardust, hops, wormhole, shieldSave, discover }

/// A goal for a single run, e.g. "Make 3 PERFECT landings in one run".
class Mission {
  const Mission({required this.kind, required this.target, required this.reward});

  final MissionKind kind;
  final int target;
  final int reward;

  String get description => switch (kind) {
        MissionKind.perfects => 'Make $target PERFECT landings in one run',
        MissionKind.combo => 'Reach a ×$target PERFECT combo',
        MissionKind.stardust => 'Collect $target stardust in one run',
        MissionKind.hops => 'Travel $target hops in one run',
        MissionKind.wormhole => target == 1 ? 'Fly through a wormhole' : 'Use $target wormholes in one run',
        MissionKind.shieldSave => 'Survive a hit with a shield',
        MissionKind.discover => 'Discover a new place',
      };

  /// How far the given run got toward this mission.
  int progress(RunStats s) => switch (kind) {
        MissionKind.perfects => s.perfects,
        MissionKind.combo => s.maxCombo,
        MissionKind.stardust => s.stardust,
        MissionKind.hops => s.hops,
        MissionKind.wormhole => s.wormholes,
        MissionKind.shieldSave => s.shieldSaves,
        MissionKind.discover => s.newDiscoveries,
      };

  bool isDoneBy(RunStats s) => progress(s) >= target;

  /// Stored as "kind:target:reward".
  String encode() => '${kind.name}:$target:$reward';

  static Mission? decode(String raw) {
    final parts = raw.split(':');
    if (parts.length != 3) return null;
    final kind = MissionKind.values.where((k) => k.name == parts[0]);
    final target = int.tryParse(parts[1]);
    final reward = int.tryParse(parts[2]);
    if (kind.isEmpty || target == null || reward == null) return null;
    return Mission(kind: kind.first, target: target, reward: reward);
  }

  /// Creates a fresh mission. Gets harder as the player completes more.
  /// Never repeats a kind that is already active.
  static Mission generate({required int serial, required int completed, required Set<MissionKind> exclude}) {
    final rng = math.Random(serial * 7919 + 17);
    final tier = math.min(3, completed ~/ 3); // 0..3
    final kinds = MissionKind.values.where((k) => !exclude.contains(k)).toList();
    final kind = kinds[rng.nextInt(kinds.length)];
    final (target, reward) = switch (kind) {
      MissionKind.perfects => (const [3, 5, 7, 10][tier], const [30, 50, 80, 120][tier]),
      MissionKind.combo => (const [2, 3, 4, 5][tier], const [30, 50, 80, 120][tier]),
      MissionKind.stardust => (const [9, 15, 24, 36][tier], const [25, 40, 60, 90][tier]),
      MissionKind.hops => (const [8, 12, 18, 25][tier], const [30, 45, 70, 110][tier]),
      MissionKind.wormhole => (tier < 2 ? 1 : 2, tier < 2 ? 40 : 90),
      MissionKind.shieldSave => (1, 50),
      MissionKind.discover => (1, 60),
    };
    return Mission(kind: kind, target: target, reward: reward);
  }
}
