import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_hopper/neon/engine/neon_world.dart';
import 'package:orbit_hopper/neon/progression/catalog.dart';
import 'package:orbit_hopper/neon/progression/neon_cubit.dart';
import 'package:orbit_hopper/neon/progression/profile.dart';
import 'package:orbit_hopper/neon/progression/rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

RunSummary run({
  int score = 800,
  int distance = 300,
  int shards = 40,
  int bestChain = 3,
  int nearMisses = 2,
  int dashes = 1,
  int breaks = 1,
  int escapes = 0,
  int riskClears = 0,
  bool daily = false,
}) =>
    RunSummary(
      score: score,
      distance: distance,
      shards: shards,
      bestChain: bestChain,
      bestMultiplier: 1 + bestChain * 0.2,
      nearMisses: nearMisses,
      dashes: dashes,
      breaks: breaks,
      escapes: escapes,
      riskClears: riskClears,
      perfectSets: 0,
      daily: daily,
      seed: 1,
      cause: 'SPIKED',
    );

void main() {
  final today = DailyChallenge.forDate(DateTime(2026, 10, 14));
  final tomorrow = DailyChallenge.forDate(DateTime(2026, 10, 15));

  group('save / load', () {
    test('profile survives a JSON round trip', () {
      const p = NeonProfile(
        best: 4321,
        runs: 12,
        lifetimeDistance: 9000,
        energy: 777,
        ownedSkins: {'pulse', 'nova'},
        ownedTrails: {'streak', 'dots'},
        skin: 'nova',
        trail: 'dots',
        dimension: 'sunset',
        achievements: {'first_run', 'score_1000'},
        tiersClaimed: 3,
        dailyDate: '2026-10-14',
        dailyBest: 1200,
        dailyDone: true,
        settings: NeonSettings(music: false, haptics: false, reducedEffects: true, highContrast: true),
      );
      final back = NeonProfile.decode(p.encode());
      expect(back.encode(), p.encode());
      expect(back.settings, p.settings);
      expect(back.ownedSkins, {'pulse', 'nova'});
    });

    test('a corrupt or missing save gives a fresh profile', () {
      expect(NeonProfile.decode(null).best, 0);
      expect(NeonProfile.decode('{not json').energy, 0);
      expect(NeonProfile.decode('[1,2,3]').skin, 'pulse');
      expect(NeonProfile.decode('{"best": "oops", "ownedSkins": 5}').ownedSkins, {'pulse'});
    });

    test('the cubit persists runs, purchases and settings across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = NeonCubit(SharedPrefsNeonRepository(prefs), clock: () => DateTime(2026, 10, 14));
      await a.load();
      await a.recordRun(run(score: 1500, shards: 200, distance: 600));
      expect(await a.skin('nova'), PurchaseResult.bought);
      await a.settings(a.state.settings.copyWith(sfx: false));
      final saved = a.state;
      await a.close();

      final b = NeonCubit(SharedPrefsNeonRepository(prefs), clock: () => DateTime(2026, 10, 14));
      await b.load();
      expect(b.state.encode(), saved.encode());
      expect(b.state.best, 1500);
      expect(b.state.skin, 'nova');
      expect(b.state.settings.sfx, isFalse);
      await b.close();
    });
  });

  group('currency', () {
    test('a run pays shards + distance/20 + escapes', () {
      expect(NeonRules.runEnergy(run(shards: 30, distance: 400, escapes: 2)), 30 + 20 + 30);
    });

    test('buying needs enough energy and equips; owned items just equip', () {
      const p = NeonProfile(energy: 200);
      final (after, r) = NeonRules.buyOrEquipSkin(p, 'nova');
      expect(r, PurchaseResult.bought);
      expect(after.energy, 50);
      expect(after.skin, 'nova');
      expect(after.ownedSkins, contains('nova'));

      final (poor, r2) = NeonRules.buyOrEquipSkin(after, 'prism');
      expect(r2, PurchaseResult.tooExpensive);
      expect(poor.energy, 50);

      final (back, r3) = NeonRules.buyOrEquipSkin(after, 'pulse');
      expect(r3, PurchaseResult.equipped);
      expect(back.energy, 50);

      final (t, r4) = NeonRules.buyOrEquipTrail(const NeonProfile(energy: 99), 'dots');
      expect(r4, PurchaseResult.tooExpensive);
      expect(t.ownedTrails, {'streak'});
      expect(NeonRules.buyOrEquipSkin(p, 'nope').$2, PurchaseResult.unknown);
    });

    test('dimensions unlock by best score, not by paying', () {
      const p = NeonProfile(best: 2000, energy: 99999);
      expect(NeonRules.selectDimension(p, 'sunset').$2, PurchaseResult.equipped);
      expect(NeonRules.selectDimension(p, 'toxic').$2, PurchaseResult.tooExpensive);
      expect(NeonRules.selectDimension(p, 'toxic').$1.energy, 99999);
    });
  });

  group('runs and achievements', () {
    test('first run: achievement, stats, no fake record', () {
      final (p, r) = NeonRules.applyRun(const NeonProfile(), run(score: 600), today: today);
      expect(p.runs, 1);
      expect(p.best, 600);
      expect(r.newRecord, isFalse);
      expect(r.achievements.map((a) => a.id), contains('first_run'));
      expect(r.tiers, [500]);
      expect(p.tiersClaimed, 1);
      expect(r.energy, NeonRules.runEnergy(run(score: 600)) + 10 + 15);
    });

    test('records, tiers and achievements pay out only once', () {
      var (p, _) = NeonRules.applyRun(const NeonProfile(), run(score: 600), today: today);
      final (p2, r2) = NeonRules.applyRun(p, run(score: 5200, nearMisses: 12, bestChain: 11, dashes: 0), today: today);
      expect(r2.newRecord, isTrue);
      expect(r2.previousBest, 600);
      expect(r2.tiers, [1000, 2500, 5000]);
      expect(r2.achievements.map((a) => a.id).toSet(),
          containsAll(['score_1000', 'score_5000', 'near_miss_10', 'chain_x10', 'no_dash_3000']));
      expect(r2.dimensions.map((d) => d.id), ['sunset', 'toxic']);
      p = p2;
      final (p3, r3) = NeonRules.applyRun(p, run(score: 5300, nearMisses: 12, bestChain: 11, dashes: 0), today: today);
      expect(r3.achievements, isEmpty);
      expect(r3.tiers, isEmpty);
      expect(r3.dimensions, isEmpty);
      expect(p3.energy - p.energy, NeonRules.runEnergy(run(score: 5300)));
    });

    test('skill achievements need the skill', () {
      final ids = NeonRules.earnedAchievements(
        run(score: 3500, dashes: 2, escapes: 1, riskClears: 1, breaks: 3),
        const NeonProfile(lifetimeDistance: 12000),
      );
      expect(ids, containsAll(['escape_chase', 'risk_taker', 'break_3', 'lifetime_10k']));
      expect(ids, isNot(contains('no_dash_3000')));
      expect(ids, isNot(contains('dash_3')));
    });

    test('every achievement id in the rules exists in the catalog', () {
      final ids = NeonCatalog.achievements.map((a) => a.id).toSet();
      final earned = NeonRules.earnedAchievements(
        run(score: 20000, nearMisses: 99, bestChain: 20, dashes: 0, escapes: 3, riskClears: 2, breaks: 9),
        const NeonProfile(lifetimeDistance: 99999),
      );
      expect(ids, containsAll(earned));
      expect(ids, contains('daily_done'));
    });
  });

  group('daily challenge', () {
    test('seed and target are stable per date and differ between dates', () {
      expect(DailyChallenge.forDate(DateTime(2026, 10, 14, 23, 59)).seed, today.seed);
      expect(tomorrow.seed, isNot(today.seed));
      expect(today.target, inInclusiveRange(1500, 3000));
      expect(today.date, '2026-10-14');
    });

    test('completing the daily pays once per day and resets tomorrow', () {
      final hit = run(score: today.target + 10, daily: true);
      final (p1, r1) = NeonRules.applyRun(const NeonProfile(), hit, today: today);
      expect(r1.dailyCompleted, isTrue);
      expect(r1.achievements.map((a) => a.id), contains('daily_done'));
      expect(p1.dailyDone, isTrue);

      final (p2, r2) = NeonRules.applyRun(p1, hit, today: today);
      expect(r2.dailyCompleted, isFalse);
      expect(p2.dailyBest, hit.score);

      final (p3, r3) = NeonRules.applyRun(p2, run(score: 10, daily: true), today: tomorrow);
      expect(r3.dailyCompleted, isFalse);
      expect(p3.dailyDone, isFalse);
      expect(p3.dailyDate, tomorrow.date);
      expect(p3.dailyBest, 10);
    });

    test('a normal run never completes the daily', () {
      final (_, r) = NeonRules.applyRun(const NeonProfile(), run(score: 99999), today: today);
      expect(r.dailyCompleted, isFalse);
    });
  });
}
