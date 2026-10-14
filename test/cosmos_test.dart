import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_hopper/game/logic/cosmos.dart';
import 'package:orbit_hopper/game/logic/level_generator.dart';

void main() {
  test('journey is ordered by real distance from the Sun', () {
    for (var k = 1; k < journey.length; k++) {
      expect(journey[k].distanceAu, greaterThan(journey[k - 1].distanceAu), reason: journey[k].name);
    }
  });

  test('landmarks have unique ids and at least one fact', () {
    expect(journey.map((l) => l.id).toSet().length, journey.length);
    for (final l in journey) {
      expect(l.facts, isNotEmpty);
    }
    expect(journey.first.region, isNotNull);
  });

  test('distance grows hop by hop until the edge of the map', () {
    final last = (journey.length - 1) * hopsPerLandmark;
    for (var i = 1; i <= last; i++) {
      expect(Cosmos.distanceAuAt(i), greaterThan(Cosmos.distanceAuAt(i - 1)), reason: 'hop $i');
    }
    expect(Cosmos.distanceAuAt(3 * hopsPerLandmark), 1.0); // Earth
    expect(Cosmos.isBeyondMap(last + 1), isTrue);
    expect(Cosmos.nextLandmark(last), isNull);
  });

  test('distances are formatted in AU, then light-years', () {
    expect(Cosmos.formatDistance(0), 'At the Sun');
    expect(Cosmos.formatDistance(5.2), '5.20 AU');
    expect(Cosmos.formatDistance(39.5), '39.5 AU');
    expect(Cosmos.formatDistance(2000), '2,000 AU');
    expect(Cosmos.formatDistance(4.24 * auPerLightYear), '4.2 light-years');
    expect(Cosmos.formatDistance(26000 * auPerLightYear), '26,000 light-years');
    expect(Cosmos.formatDistance(2.5e6 * auPerLightYear), '2.5 million light-years');
  });

  test('generator places real landmarks every few hops, in order', () {
    final gen = LevelGenerator(width: 390, seed: 9);
    var p = gen.first(const Offset(195, 600));
    expect(p.landmark, 0);
    for (var i = 1; i <= (journey.length - 1) * hopsPerLandmark; i++) {
      p = gen.next(p);
      expect(p.index, i);
      if (i % hopsPerLandmark == 0) {
        expect(p.landmark, i ~/ hopsPerLandmark);
        expect(p.stability, double.infinity);
        expect(p.moons, isEmpty);
      } else {
        expect(p.landmark, isNull);
      }
    }
  });
}
