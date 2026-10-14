import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_hopper/game/logic/cosmos.dart';
import 'package:orbit_hopper/hole/logic/hole_world.dart';
import 'package:orbit_hopper/hole/logic/size_scale.dart';

const _dt = 1 / 60;
const _rock = BodyLook(BodyStyle.rocky, 0xFF9C7A5B, 0xFF5A4232);

HoleWorld _emptyWorld() {
  final w = HoleWorld(viewWidth: 390, viewHeight: 844, seed: 1);
  w.things.clear();
  return w;
}

SpaceThing _thing(HoleWorld w, double ratio, Offset at) =>
    SpaceThing(pos: at, vel: Offset.zero, radius: w.radius * ratio, look: _rock, seed: 0);

void main() {
  group('Size scale', () {
    test('tiers rise with size and keep counting past the last one', () {
      var last = -1;
      for (final r in [0.001, 0.01, 1.0, 10.0, 1e3, 1e5, 1e6, 5e6, 5e7, 5e8, 5e10, 5e15, 5e19, 5e22, 5e24]) {
        final t = tierOfRadius(r);
        expect(t, greaterThan(last), reason: 'r=$r');
        last = t;
      }
      final edge = sizeTiers.last.minRadius;
      expect(tierOfRadius(edge * 150), sizeTiers.length);
      expect(tierName(sizeTiers.length), startsWith('Universe'));
      for (var i = 0; i < sizeTiers.length + 3; i++) {
        expect(tierOfRadius(tierStart(i) * 1.01), i, reason: 'tier $i');
      }
    });

    test('lengths are readable', () {
      expect(formatLength(0.002), '2.0 mm');
      expect(formatLength(0.5), '50.0 cm');
      expect(formatLength(330), '330 m');
      expect(formatLength(8849000), '8,849 km');
      expect(formatLength(1.3927e9), '1.4 million km');
      expect(formatLength(9.4607e15 * 2), '2.0 light-years');
    });

    test('comparisons pick the biggest thing you beat', () {
      expect(comparisonFor(0.001), 'Smaller than a grain of sand');
      expect(comparisonFor(9000), 'Bigger than Mount Everest');
      expect(comparisonFor(1.4e9), 'Bigger than the Sun');
    });
  });

  group('Black hole', () {
    test('eating something smaller makes you grow', () {
      final w = _emptyWorld();
      final before = w.radius;
      w.things.add(_thing(w, 0.5, Offset(w.radius * 0.5, 0)));
      w.update(_dt);
      expect(w.eaten, 1);
      expect(w.radius, greaterThan(before));
    });

    test('food is pulled in by gravity', () {
      final w = _emptyWorld();
      w.things.add(_thing(w, 0.4, Offset(w.radius * 2.5, 0)));
      for (var i = 0; i < 240 && w.eaten == 0; i++) {
        w.update(_dt);
      }
      expect(w.eaten, 1);
    });

    test('something too big hurts and shrinks you, once', () {
      final w = _emptyWorld();
      final before = w.radius;
      w.things.add(_thing(w, 1.5, Offset(w.radius * 2.0, 0)));
      w.update(_dt);
      expect(w.radius, lessThan(before * 0.8));
      expect(w.invulnerable, greaterThan(0));
      expect(w.dead, isFalse);
    });

    test('something more than twice your size swallows you', () {
      final w = _emptyWorld();
      w.things.add(_thing(w, 2.5, Offset(w.radius * 2.5, 0)));
      w.update(_dt);
      expect(w.dead, isTrue);
      expect(w.death, HoleDeath.swallowed);
    });

    test('without food you evaporate (Hawking radiation)', () {
      final w = _emptyWorld();
      w.steer = const Offset(0.1, 0); // starts the clock
      final before = w.radius;
      for (var i = 0; i < 60 * 3; i++) {
        w.things.clear();
        w.update(_dt);
      }
      expect(w.radius, lessThan(before));
      for (var i = 0; i < 60 * 120 && !w.dead; i++) {
        w.things.clear();
        w.update(_dt);
      }
      expect(w.death, HoleDeath.evaporated);
    });

    test('nothing lethal appears during the safe start', () {
      final w = HoleWorld(viewWidth: 390, viewHeight: 844, seed: 4);
      w.steer = const Offset(0.01, 0);
      for (var i = 0; i < 60 * 10; i++) {
        w.update(_dt);
        for (final t in w.things) {
          expect(w.dangerOf(t), lessThan(2));
        }
        if (w.dead) break;
      }
    });

    test('space stays populated', () {
      final w = HoleWorld(viewWidth: 390, viewHeight: 844, seed: 6);
      w.update(_dt);
      expect(w.things.length, HoleWorld.population);
    });
  });
}
