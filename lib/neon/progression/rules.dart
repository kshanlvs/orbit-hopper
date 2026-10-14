import 'dart:math' as math;

import '../engine/neon_world.dart';
import 'catalog.dart';
import 'profile.dart';

/// Today's challenge: everyone gets the same corridor for the date.
class DailyChallenge {
  const DailyChallenge({required this.date, required this.seed, required this.target});

  final String date;
  final int seed;
  final int target;

  factory DailyChallenge.forDate(DateTime day) {
    final date = dateKey(day);
    var h = 2166136261;
    for (final c in date.codeUnits) {
      h = ((h ^ c) * 16777619) & 0x7FFFFFFF;
    }
    return DailyChallenge(date: date, seed: h, target: 1500 + (h % 7) * 250);
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// What a finished run earned.
class RunReward {
  const RunReward({
    required this.energy,
    required this.energyFromRun,
    required this.newRecord,
    required this.previousBest,
    required this.achievements,
    required this.tiers,
    required this.dimensions,
    required this.dailyCompleted,
  });

  final int energy;
  final int energyFromRun;
  final bool newRecord;
  final int previousBest;
  final List<Achievement> achievements;
  final List<int> tiers;
  final List<Dimension> dimensions;
  final bool dailyCompleted;
}

T? _find<T>(List<T> items, bool Function(T) test) {
  for (final i in items) {
    if (test(i)) return i;
  }
  return null;
}

enum PurchaseResult { bought, equipped, tooExpensive, unknown }

abstract final class NeonRules {
  /// Energy for the run itself: every shard, plus survival and escapes.
  static int runEnergy(RunSummary r) => r.shards + r.distance ~/ 20 + r.escapes * 15;

  static Set<String> earnedAchievements(RunSummary r, NeonProfile after) => {
        'first_run',
        if (r.score >= 1000) 'score_1000',
        if (r.score >= 5000) 'score_5000',
        if (r.score >= 10000) 'score_10000',
        if (r.nearMisses >= 10) 'near_miss_10',
        if (r.bestChain >= 10) 'chain_x10',
        if (r.dashes >= 3) 'dash_3',
        if (r.escapes >= 1) 'escape_chase',
        if (r.riskClears >= 1) 'risk_taker',
        if (r.dashes == 0 && r.score >= 3000) 'no_dash_3000',
        if (r.breaks >= 3) 'break_3',
        if (after.lifetimeDistance >= 10000) 'lifetime_10k',
      };

  /// Applies a run to the profile. Pure, so it is easy to test.
  static (NeonProfile, RunReward) applyRun(NeonProfile p, RunSummary r, {required DailyChallenge today}) {
    final previousBest = p.best;
    final best = math.max(p.best, r.score);
    var next = p.copyWith(
      best: best,
      runs: p.runs + 1,
      lifetimeDistance: p.lifetimeDistance + r.distance,
    );

    // Daily challenge (resets when the date changes).
    var dailyDone = next.dailyDate == today.date && next.dailyDone;
    var dailyBest = next.dailyDate == today.date ? next.dailyBest : 0;
    var dailyCompleted = false;
    if (r.daily) {
      dailyBest = math.max(dailyBest, r.score);
      if (!dailyDone && r.score >= today.target) {
        dailyDone = true;
        dailyCompleted = true;
      }
    }
    next = next.copyWith(dailyDate: today.date, dailyBest: dailyBest, dailyDone: dailyDone);

    final earned = earnedAchievements(r, next);
    if (dailyCompleted) earned.add('daily_done');
    final fresh = [
      for (final a in NeonCatalog.achievements)
        if (earned.contains(a.id) && !p.achievements.contains(a.id)) a,
    ];

    final tiers = <int>[];
    var tierEnergy = 0;
    var claimed = p.tiersClaimed;
    while (claimed < NeonCatalog.bestTiers.length && best >= NeonCatalog.bestTiers[claimed]) {
      tiers.add(NeonCatalog.bestTiers[claimed]);
      tierEnergy += NeonCatalog.bestTierRewards[claimed];
      claimed++;
    }

    final unlocked = [
      for (final d in NeonCatalog.dimensions)
        if (d.unlockScore > previousBest && d.unlockScore <= best) d,
    ];

    final fromRun = runEnergy(r);
    final total = fromRun +
        fresh.fold<int>(0, (a, b) => a + b.reward) +
        tierEnergy +
        (dailyCompleted ? NeonCatalog.dailyReward : 0);

    next = next.copyWith(
      energy: p.energy + total,
      achievements: {...p.achievements, ...fresh.map((a) => a.id)},
      tiersClaimed: claimed,
    );
    return (
      next,
      RunReward(
        energy: total,
        energyFromRun: fromRun,
        newRecord: r.score > previousBest && previousBest > 0,
        previousBest: previousBest,
        achievements: fresh,
        tiers: tiers,
        dimensions: unlocked,
        dailyCompleted: dailyCompleted,
      ),
    );
  }

  static bool dimensionUnlocked(NeonProfile p, Dimension d) => p.best >= d.unlockScore;

  static (NeonProfile, PurchaseResult) selectDimension(NeonProfile p, String id) {
    final d = _find(NeonCatalog.dimensions, (Dimension x) => x.id == id);
    if (d == null) return (p, PurchaseResult.unknown);
    if (!dimensionUnlocked(p, d)) return (p, PurchaseResult.tooExpensive);
    return (p.copyWith(dimension: id), PurchaseResult.equipped);
  }

  static (NeonProfile, PurchaseResult) buyOrEquipSkin(NeonProfile p, String id) {
    final s = _find(NeonCatalog.skins, (OrbSkin x) => x.id == id);
    if (s == null) return (p, PurchaseResult.unknown);
    if (p.ownedSkins.contains(id)) return (p.copyWith(skin: id), PurchaseResult.equipped);
    if (p.energy < s.price) return (p, PurchaseResult.tooExpensive);
    return (
      p.copyWith(energy: p.energy - s.price, ownedSkins: {...p.ownedSkins, id}, skin: id),
      PurchaseResult.bought,
    );
  }

  static (NeonProfile, PurchaseResult) buyOrEquipTrail(NeonProfile p, String id) {
    final t = _find(NeonCatalog.trails, (TrailStyle x) => x.id == id);
    if (t == null) return (p, PurchaseResult.unknown);
    if (p.ownedTrails.contains(id)) return (p.copyWith(trail: id), PurchaseResult.equipped);
    if (p.energy < t.price) return (p, PurchaseResult.tooExpensive);
    return (
      p.copyWith(energy: p.energy - t.price, ownedTrails: {...p.ownedTrails, id}, trail: id),
      PurchaseResult.bought,
    );
  }
}
