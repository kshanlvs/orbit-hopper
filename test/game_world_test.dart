import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_hopper/game/logic/cosmos.dart';
import 'package:orbit_hopper/game/logic/difficulty.dart';
import 'package:orbit_hopper/game/logic/game_world.dart';
import 'package:orbit_hopper/game/logic/level_generator.dart';
import 'package:orbit_hopper/game/logic/models.dart';

const _dt = 1 / 60;

/// Steps [world] until the comet is no longer flying (or 3 s pass).
void _flyOut(GameWorld world) {
  for (var i = 0; i < 180 && world.comet.mode == CometMode.flying; i++) {
    world.update(_dt);
  }
}

void main() {
  group('LevelGenerator', () {
    test('planets never overlap and stay on screen', () {
      const width = 390.0;
      final gen = LevelGenerator(width: width, seed: 42);
      var prev = gen.first(const Offset(width / 2, 600));
      for (var i = 0; i < 400; i++) {
        final next = gen.next(prev);
        final dist = (next.baseCenter - prev.baseCenter).distance;
        expect(
          dist,
          greaterThanOrEqualTo(prev.outerRadius + next.outerRadius + prev.driftAmplitude + next.driftAmplitude),
          reason: 'planet ${next.index} overlaps its neighbour',
        );
        expect(next.baseCenter.dy, lessThan(prev.baseCenter.dy));
        expect(next.baseCenter.dx - next.driftAmplitude - next.orbitRadius, greaterThanOrEqualTo(0));
        expect(next.baseCenter.dx + next.driftAmplitude + next.orbitRadius, lessThanOrEqualTo(width));
        prev = next;
      }
    });
  });

  group('Difficulty', () {
    test('ramps up and then plateaus', () {
      expect(const Difficulty(0).orbitSpeed, lessThan(const Difficulty(40).orbitSpeed));
      expect(const Difficulty(80).orbitSpeed, const Difficulty(500).orbitSpeed);
      expect(const Difficulty(0).stability, double.infinity);
      expect(const Difficulty(20).stability.isFinite, isTrue);
    });
  });

  group('GameWorld', () {
    test('first planet is safe to orbit forever before the first tap', () {
      final world = GameWorld(width: 390, height: 844, seed: 1);
      for (var i = 0; i < 60 * 30; i++) {
        world.update(_dt);
      }
      expect(world.isDead, isFalse);
      expect(world.comet.mode, CometMode.orbiting);
    });

    test('some launch timing reaches planet 1 and scores', () {
      var reached = false;
      for (var wait = 0; wait < 240 && !reached; wait += 2) {
        final world = GameWorld(width: 390, height: 844, seed: 3);
        for (var i = 0; i < wait; i++) {
          world.update(_dt);
        }
        world.launch();
        _flyOut(world);
        if (world.bestIndex >= 1) {
          reached = true;
          expect(world.score, greaterThanOrEqualTo(1));
          expect(world.comet.mode, CometMode.orbiting);
        }
      }
      expect(reached, isTrue);
    });

    test('a run can start from a checkpoint landmark', () {
      final world = GameWorld(width: 390, height: 844, seed: 2, startLandmark: 7); // Saturn
      expect(world.bestIndex, 7 * hopsPerLandmark);
      expect(world.comet.planet!.landmark, 7);
      expect(world.hopsThisRun, 0);
      expect(world.events.first.type, WorldEventType.depart);
      expect(world.events.first.value, 7);
      expect(world.travelIndex, world.bestIndex.toDouble());
    });

    test('travel index grows during flight but stays below the next hop', () {
      for (var wait = 0; wait < 240; wait += 4) {
        final world = GameWorld(width: 390, height: 844, seed: 3);
        for (var i = 0; i < wait; i++) {
          world.update(_dt);
        }
        world.launch();
        for (var i = 0; i < 12 && world.comet.mode == CometMode.flying; i++) {
          world.update(_dt);
          expect(world.travelIndex, inInclusiveRange(0.0, 0.95));
        }
      }
    });

    test('flying off into nothing ends the run', () {
      final world = GameWorld(width: 390, height: 844, seed: 5);
      // Launch straight away to the right (comet starts at the top, clockwise).
      world.launch();
      for (var i = 0; i < 60 * 4 && !world.isDead && world.bestIndex == 0; i++) {
        world.update(_dt);
      }
      expect(world.isDead || world.bestIndex > 0, isTrue);
    });
  });
}
