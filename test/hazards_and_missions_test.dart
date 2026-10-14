import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_hopper/domain/entities/mission.dart';
import 'package:orbit_hopper/game/logic/cosmos.dart';
import 'package:orbit_hopper/game/logic/game_world.dart';
import 'package:orbit_hopper/game/logic/level_generator.dart';
import 'package:orbit_hopper/game/logic/models.dart';

const _dt = 1 / 60;

/// Launches and drops a still asteroid right in the comet's path.
GameWorld _worldWithRockAhead({required bool shield}) {
  final world = GameWorld(width: 390, height: 844, seed: 4);
  world.shield = shield;
  world.launch();
  final ahead = world.comet.position + world.comet.velocity * 0.04;
  world.asteroids.add(Asteroid(position: ahead, speed: 0, radius: 10, spin: 0, seed: 1));
  for (var i = 0; i < 6; i++) {
    world.update(_dt);
  }
  return world;
}

void main() {
  group('Hazards', () {
    test('an asteroid hit ends the run without a shield', () {
      final world = _worldWithRockAhead(shield: false);
      expect(world.isDead, isTrue);
      expect(world.deathCause, DeathCause.asteroid);
    });

    test('a shield absorbs one hit', () {
      final world = _worldWithRockAhead(shield: true);
      expect(world.isDead, isFalse);
      expect(world.shield, isFalse);
      expect(world.stats.shieldSaves, 1);
      expect(world.invulnerable, greaterThan(0));
    });

    test('asteroids only appear in asteroid regions, never next to a real place', () {
      final gen = LevelGenerator(width: 390, seed: 12);
      var p = gen.first(const Offset(195, 600));
      for (var i = 0; i < 110; i++) {
        final next = gen.next(p);
        final rocks = gen.asteroidsBetween(p, next);
        if (rocks.isNotEmpty) {
          expect(Cosmos.regionAt(next.index).asteroids, isTrue, reason: 'hop ${next.index}');
          expect(next.landmark, isNull);
          expect(p.landmark, isNull);
        }
        p = next;
      }
    });

    test('wormholes never warp past the next real place', () {
      final gen = LevelGenerator(width: 390, seed: 21);
      var p = gen.first(const Offset(195, 600));
      var seen = 0;
      for (var i = 0; i < 120; i++) {
        final next = gen.next(p);
        final w = gen.wormholeBetween(p, next);
        if (w != null) {
          seen++;
          final nextLandmark = (p.index ~/ hopsPerLandmark + 1) * hopsPerLandmark;
          expect(w.targetIndex, lessThanOrEqualTo(nextLandmark));
          expect(w.targetIndex, greaterThan(next.index));
        }
        p = next;
      }
      expect(seen, greaterThan(0));
    });

    test('flying into a wormhole warps ahead and scores the skipped hops', () {
      final world = GameWorld(width: 390, height: 844, seed: 6, startLandmark: 2);
      world.launch();
      final start = world.bestIndex;
      final hole = Wormhole(world.comet.position + world.comet.velocity * 0.03, start + 3, 0);
      // Make sure the target planet exists before warping.
      world.update(_dt * 0.01);
      world.wormholes.add(hole);
      for (var i = 0; i < 5 && world.bestIndex == start; i++) {
        world.update(_dt);
      }
      expect(world.bestIndex, start + 3);
      expect(world.stats.wormholes, 1);
      expect(world.comet.mode, CometMode.orbiting);
    });
  });

  group('Missions', () {
    test('encode and decode round-trip', () {
      const m = Mission(kind: MissionKind.perfects, target: 5, reward: 50);
      final back = Mission.decode(m.encode())!;
      expect(back.kind, m.kind);
      expect(back.target, 5);
      expect(back.reward, 50);
      expect(Mission.decode('garbage'), isNull);
    });

    test('generation avoids active kinds and gets harder', () {
      final easy = Mission.generate(serial: 3, completed: 0, exclude: {MissionKind.wormhole});
      expect(easy.kind, isNot(MissionKind.wormhole));
      const kind = MissionKind.hops;
      final others = MissionKind.values.where((k) => k != kind).toSet();
      final early = Mission.generate(serial: 1, completed: 0, exclude: others);
      final late = Mission.generate(serial: 1, completed: 12, exclude: others);
      expect(early.kind, kind);
      expect(late.target, greaterThan(early.target));
      expect(late.reward, greaterThan(early.reward));
    });

    test('progress is read from run stats', () {
      const m = Mission(kind: MissionKind.stardust, target: 9, reward: 25);
      final s = RunStats()..stardust = 8;
      expect(m.isDoneBy(s), isFalse);
      s.stardust = 9;
      expect(m.isDoneBy(s), isTrue);
    });
  });

  group('Save Earth', () {
    const config = DefenseConfig(level: 1);

    test('the countdown only starts after the first launch', () {
      final world = GameWorld(width: 390, height: 844, seed: 8, startLandmark: 3, defense: config);
      for (var i = 0; i < 120; i++) {
        world.update(_dt);
      }
      expect(world.defense!.timeLeft, config.timeLimit);
    });

    test('running out of time means impact', () {
      final world = GameWorld(width: 390, height: 844, seed: 8, startLandmark: 3, defense: config);
      world.launch();
      world.defense!.timeLeft = 0.01;
      world.update(_dt);
      expect(world.isDead, isTrue);
      expect(world.deathCause, DeathCause.impact);
      expect(world.defense!.failed, isTrue);
    });

    test('full charge spawns the killer asteroid; ramming it saves Earth', () {
      final world = GameWorld(width: 390, height: 844, seed: 8, startLandmark: 3, defense: config);
      world.defense!.charge = config.chargeNeeded - 1;
      // Land on the next planet via a wormhole placed right in front.
      world.launch();
      world.update(_dt * 0.01);
      world.wormholes.add(Wormhole(world.comet.position + world.comet.velocity * 0.03, world.bestIndex + 1, 0));
      for (var i = 0; i < 4 && world.defense!.killer == null; i++) {
        world.update(_dt);
      }
      final killer = world.defense!.killer;
      expect(killer, isNotNull);
      expect(world.defense!.charged, isTrue);

      // Fly straight into it.
      world.launch();
      world.comet.position = killer!.position + const Offset(0, 25);
      world.comet.velocity = const Offset(0, -600);
      for (var i = 0; i < 10 && !world.defense!.won; i++) {
        world.update(_dt);
      }
      if (!world.defense!.won) {
        print('STAT killer-test dead=${world.isDead} cause=${world.deathCause} mode=${world.comet.mode} '
            'dist=${(world.comet.position - killer.position).distance} killer=${world.defense!.killer?.position} '
            'comet=${world.comet.position}');
      }
      expect(world.defense!.won, isTrue);
      expect(world.defense!.killer, isNull);
      // Nothing can end the run after the save.
      world.defense!.timeLeft = 0;
      for (var i = 0; i < 300; i++) {
        world.update(_dt);
      }
      expect(world.isDead, isFalse);
    });

    test('threat levels get harder', () {
      const l1 = DefenseConfig(level: 1);
      const l4 = DefenseConfig(level: 4);
      expect(l4.chargeNeeded, greaterThan(l1.chargeNeeded));
      expect(l4.timeLimit, lessThan(l1.timeLimit));
      expect(l4.reward, greaterThan(l1.reward));
    });
  });

  test('ranks rise along the journey', () {
    expect(Cosmos.rankFor(0), 'Solar Cadet');
    expect(Cosmos.rankFor(journey.length - 1), 'Master of the Universe');
    expect(Cosmos.isRankUp(3), isTrue); // Earth
    expect(Cosmos.isRankUp(4), isFalse); // Mars
  });
}
