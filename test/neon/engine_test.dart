import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_hopper/neon/engine/difficulty.dart';
import 'package:orbit_hopper/neon/engine/generator.dart';
import 'package:orbit_hopper/neon/engine/hazards.dart';
import 'package:orbit_hopper/neon/engine/neon_world.dart';
import 'package:orbit_hopper/neon/engine/patterns.dart';
import 'package:orbit_hopper/neon/engine/physics.dart';
import 'package:orbit_hopper/neon/engine/rng.dart';
import 'package:orbit_hopper/neon/engine/scoring.dart';
import 'package:orbit_hopper/neon/engine/tuning.dart';
import 'package:orbit_hopper/neon/engine/validator.dart';

import 'bot.dart';

void main() {
  group('scoring', () {
    test('multiplier grows 0.2 per chain step and caps at x5', () {
      expect(ScoreKeeper.multiplierFor(0), 1);
      expect(ScoreKeeper.multiplierFor(5), closeTo(2, 1e-9));
      expect(ScoreKeeper.multiplierFor(20), closeTo(5, 1e-9));
      expect(ScoreKeeper.multiplierFor(99), closeTo(5, 1e-9));
    });

    test('distance and bonuses are scaled by the multiplier', () {
      final k = ScoreKeeper();
      k.addDistance(10);
      expect(k.points, 100);
      expect(k.nearMiss(), 30); // chain 1 -> x1.2 * 25
      expect(k.chain, 1);
      k.addDistance(10);
      expect(k.score, closeTo(100 + 30 + 120, 1e-6));
    });

    test('chain breaks after the window with no good moves', () {
      final k = ScoreKeeper()
        ..nearMiss()
        ..nearMiss();
      expect(k.chain, 2);
      var broke = false;
      for (var i = 0; i < 1000 && !broke; i++) {
        broke = k.tick(0.01);
      }
      expect(broke, isTrue);
      expect(k.chain, 0);
      expect(k.bestChain, 2);
    });

    test('shards keep an active chain alive', () {
      final k = ScoreKeeper()..nearMiss();
      for (var i = 0; i < 10; i++) {
        k.tick(Tune.chainWindow * 0.8);
        k.shard();
      }
      expect(k.chain, 1);
    });

    test('risk shards are worth double, Reality Break doubles again', () {
      final k = ScoreKeeper();
      expect(k.shard(), 5);
      expect(k.shard(risk: true), 10);
      expect(k.shard(risk: true, doubled: true), 20);
    });
  });

  group('difficulty', () {
    test('speed rises monotonically and is capped', () {
      var last = 0.0;
      for (var s = 0.0; s < 5000; s += 25) {
        final v = Difficulty.speed(s);
        expect(v, greaterThanOrEqualTo(last));
        expect(v, lessThanOrEqualTo(Tune.maxSpeed + 1e-9));
        last = v;
      }
      expect(Difficulty.speed(0), Tune.baseSpeed);
      expect(Difficulty.speed(99999), closeTo(Tune.maxSpeed, 1e-9));
    });

    test('level, ratings and reaction floor stay in range', () {
      for (var s = 0.0; s < 5000; s += 50) {
        final d = Difficulty.level(s);
        expect(d, inInclusiveRange(0, 1));
        expect(Difficulty.maxRating(d, peak: true), lessThanOrEqualTo(9));
        expect(Difficulty.reactionFloor(d), greaterThanOrEqualTo(0.19));
      }
      expect(Difficulty.maxRating(0), 2);
    });

    test('later patterns unlock gradually', () {
      final gen = LevelGenerator(11);
      final firstSeen = <String, double>{};
      while (gen.cursor < 1500) {
        final c = gen.next();
        firstSeen.putIfAbsent(c.patternId, () => c.x0);
      }
      expect(firstSeen['spike_row'], lessThan(20));
      expect(firstSeen['zigzag'] ?? 9999, greaterThan(300));
      print('STAT first-seen ${firstSeen.map((k, v) => MapEntry(k, v.round()))}');
    });
  });

  group('generation', () {
    test('same seed gives the same corridor', () {
      String sig(int seed) {
        final g = LevelGenerator(seed);
        final b = StringBuffer();
        while (g.cursor < 400) {
          final c = g.next();
          b.write('${c.patternId}:${c.hazards.length}:${c.x1.toStringAsFixed(3)};');
        }
        return b.toString();
      }

      expect(sig(42), sig(42));
      expect(sig(42), isNot(sig(43)));
    });

    test('every chunk is validated, fallbacks are rare', () {
      final sw = Stopwatch()..start();
      var chunks = 0, fallbacks = 0, validations = 0, retries = 0, peak = 0, gates = 0, richGates = 0;
      final roles = <ChunkRole, int>{};
      for (var seed = 1; seed <= 12; seed++) {
        final g = LevelGenerator(seed * 7919);
        while (g.cursor < 1800) {
          final c = g.next();
          expect(c.validated, isTrue, reason: 'seed $seed ${c.patternId} at ${c.x0}');
          expect(c.x1, greaterThan(c.x0));
          for (final h in c.hazards) {
            expect(h.left, greaterThanOrEqualTo(c.x0), reason: c.patternId);
            expect(h.right, lessThanOrEqualTo(c.x1), reason: c.patternId);
          }
          roles[c.role] = (roles[c.role] ?? 0) + 1;
          if (c.riskTop != null) {
            gates++;
            if (c.riskShards > 0) richGates++;
          }
        }
        chunks += g.stats.chunks;
        fallbacks += g.stats.fallbacks;
        validations += g.stats.validations;
        retries += g.stats.retries;
        if (g.stats.peakStates > peak) peak = g.stats.peakStates;
      }
      sw.stop();
      print('STAT chunks=$chunks validations=$validations retries=$retries fallbacks=$fallbacks '
          'peakStates=$peak riskGates=$gates withRiskShards=$richGates msPerValidation=${(sw.elapsedMilliseconds / validations).toStringAsFixed(2)} roles=$roles');
      expect(fallbacks / chunks, lessThan(0.05));
      expect(richGates, greaterThan(gates * 0.7), reason: 'risk lanes should usually carry a proven shard trail');
      expect(roles[ChunkRole.breakIntro] ?? 0, greaterThan(0));
      expect(roles[ChunkRole.chaseIntro] ?? 0, greaterThan(0));
    });

    test('per-pattern validation pass rate', () {
      final rng = NeonRng(5);
      final report = <String>[];
      for (final def in [...PatternRegistry.all, PatternRegistry.riskGate]) {
        var ok = 0;
        const n = 30;
        for (var i = 0; i < n; i++) {
          final d = i / (n - 1);
          final v = Difficulty.speed(d * 1600);
          final c = Chunk(
            x0: 0,
            x1: 0,
            speed: v,
            patternId: def.id,
            rating: def.rating,
            minReaction: def.minReaction,
            entryTop: 0,
            entryBot: 1,
            exitTop: 0,
            exitBot: 1,
          );
          final ctx = PatternCtx(rng: rng.fork(), chunk: c, x: v * 0.45, speed: v, difficulty: d, top: 0, bot: 1);
          c.x1 = def.build(ctx) + 0.3;
          c.hazards.sort((a, b) => a.left.compareTo(b.left));
          if (RouteValidator.validate(c, minGap: def.minReaction).ok) ok++;
        }
        report.add('${def.id}=${(100 * ok / n).round()}%');
        expect(ok, greaterThan(n * 0.5), reason: '${def.id} passes too rarely ($ok/$n)');
      }
      print('STAT pattern-pass ${report.join(' ')}');
    });

    test('an impossible wall is rejected', () {
      final c = Chunk(
        x0: 0,
        x1: 2,
        speed: 2,
        patternId: 'wall',
        rating: 9,
        minReaction: 0.2,
        entryTop: 0,
        entryBot: 1,
        exitTop: 0,
        exitBot: 1,
        hazards: [
          Spike(x: 1, width: 0.15, height: 0.55, baseY: 1, onFloor: true),
          Spike(x: 1, width: 0.15, height: 0.55, baseY: 0, onFloor: false),
        ],
      );
      expect(RouteValidator.validate(c, minGap: 0.2).ok, isFalse);
    });

    test('a spike on one wall needs a flip from that side only', () {
      final c = Chunk(
        x0: 0,
        x1: 2,
        speed: 2,
        patternId: 'one',
        rating: 1,
        minReaction: 0.3,
        entryTop: 0,
        entryBot: 1,
        exitTop: 0,
        exitBot: 1,
        hazards: [Spike(x: 1.2, width: 0.15, height: 0.3, baseY: 1, onFloor: true)],
      );
      final res = RouteValidator.validate(c, minGap: 0.3, rng: NeonRng(1));
      expect(res.ok, isTrue);
      expect(res.path!.flips, isNotEmpty);
    });
  });

  group('physics', () {
    test('a flip crosses the corridor in about 0.2 s', () {
      final c = Chunk(
        x0: 0,
        x1: 10,
        speed: 2,
        patternId: 'e',
        rating: 0,
        minReaction: 0.4,
        entryTop: 0,
        entryBot: 1,
        exitTop: 0,
        exitBot: 1,
      );
      final o = OrbState(Physics.restY(c, 0, 1), 0, -1);
      var t = 0;
      var s = 0.0;
      while (!Physics.grounded(o, c, s) || t == 0) {
        s += 2 * Tune.dt;
        expect(Physics.step(o, c, s), isTrue);
        t++;
        if (t > 200) break;
      }
      final seconds = t * Tune.dt;
      print('STAT flip-time=${seconds.toStringAsFixed(3)}s');
      expect(seconds, inInclusiveRange(0.15, 0.26));
      expect(o.y, closeTo(Tune.orbRadius, 1e-6));
    });

    test('a ramp pushes a resting orb along it without killing it', () {
      final c = Chunk(
        x0: 0,
        x1: 4,
        speed: 2,
        patternId: 'r',
        rating: 0,
        minReaction: 0.4,
        entryTop: 0,
        entryBot: 1,
        exitTop: 0,
        exitBot: 1,
        bounds: [const BoundSeg(x0: 1, x1: 2, top0: 0, top1: 0.2, bot0: 1, bot1: 0.8)],
      );
      final o = OrbState(Physics.restY(c, 0, 1), 0, 1);
      for (var s = 0.0; s < 3; s += 2 * Tune.dt) {
        expect(Physics.step(o, c, s), isTrue);
      }
      expect(o.y, closeTo(0.8 - Tune.orbRadius, 1e-3));
    });
  });

  group('world', () {
    test('game over fires exactly once and stops the run', () {
      final w = NeonWorld(seed: 3);
      var deaths = 0;
      for (var i = 0; i < 120 * 120 && w.alive; i++) {
        w.update(Tune.dt);
        deaths += w.events.where((e) => e.type == NeonEventType.death).length;
        w.events.clear();
      }
      expect(w.alive, isFalse, reason: 'never flipping must eventually hit a spike');
      for (var i = 0; i < 100; i++) {
        w.flip();
        w.update(Tune.dt);
        deaths += w.events.where((e) => e.type == NeonEventType.death).length;
        w.events.clear();
      }
      expect(deaths, 1);
      final dist = w.s;
      w.update(1);
      expect(w.s, dist);
    });

    test('reset clears every transient value', () {
      final w = NeonWorld(seed: 4);
      for (var i = 0; i < 2000 && w.alive; i++) {
        if (i % 50 == 0) w.flip();
        w.update(Tune.dt);
      }
      w.reset();
      expect(w.alive, isTrue);
      expect(w.s, 0);
      expect(w.score.points, 0);
      expect(w.score.chain, 0);
      expect(w.dashMeter, 0);
      expect(w.stats.shards, 0);
      expect(w.events, isEmpty);
      expect(w.chunks.first.x0, 0);
    });

    test('Pulse Dash pierces magenta hazards but not cyan ones', () {
      final w = NeonWorld(seed: 5);
      w.dashMeter = Tune.dashCharge;
      expect(w.dash(), isTrue);
      expect(w.dashing, isTrue);
      expect(w.dash(), isFalse);
      final spike = Spike(x: 0, width: 0.15, height: 0.3, baseY: 1, onFloor: true);
      final laser = Laser(x: 0, y0: 0, y1: 1, period: 1, onFraction: 1, phase: 0);
      expect(spike.dashable, isTrue);
      expect(laser.dashable, isFalse);
    });

    test('a route-following bot survives long runs on many seeds', () {
      final sw = Stopwatch()..start();
      var total = 0.0;
      for (final seed in [1, 2, 3, 2026, 77777]) {
        final w = NeonWorld(seed: seed);
        final bot = NeonBot(w);
        final events = <NeonEventType, int>{};
        while (w.alive && w.s < 1400) {
          bot.tick();
          if (w.dashReady) w.dash();
          for (final e in w.events) {
            events[e.type] = (events[e.type] ?? 0) + 1;
          }
          w.events.clear();
        }
        total += w.s;
        print('STAT bot seed=$seed dist=${w.s.round()} alive=${w.alive} cause=${w.cause} '
            'score=${w.score.points} bestChain=${w.score.bestChain} shards=${w.stats.shards} '
            'nearMiss=${w.stats.nearMisses} breaks=${w.stats.breaks} escapes=${w.stats.escapes} '
            'dashes=${w.stats.dashes} risk=${w.stats.riskClears} failedPlans=${bot.failedPlans}/${bot.replans}');
        expect(w.alive, isTrue, reason: 'seed $seed died at ${w.s} (${w.cause}) in ${w.current.patternId}');
      }
      print('STAT bot total=${total.round()} ms=${sw.elapsedMilliseconds}');
    });
  });
}
