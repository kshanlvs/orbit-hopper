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
    // The journey never ends: past the edge come uncharted worlds.
    expect(Cosmos.nextLandmark(last).real, isFalse);
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

  test('uncharted worlds are endless, stable and named', () {
    final a = Cosmos.place(realPlaces + 5);
    final b = Cosmos.place(realPlaces + 5);
    expect(identical(a, b), isTrue);
    expect(a.real, isFalse);
    expect(a.id, 'beyond_5');
    expect(Cosmos.indexOfId(a.id), realPlaces + 5);
    expect(Cosmos.place(realPlaces + 500).name, isNotEmpty);
    expect(Cosmos.indexOfId('nonsense'), 0);
  });

  test('every chapter ends on a real place, in journey order', () {
    var last = 0;
    for (final c in chapters) {
      final k = Cosmos.indexOfId(c.endId);
      expect(k, greaterThan(last), reason: c.title);
      expect(Cosmos.chapterEndingAt(k)?.title, c.title);
      last = k;
    }
    expect(Cosmos.chapterEndingAt(realPlaces + unchartedPerExpedition - 1), isNotNull);
    expect(Cosmos.chapterEndingAt(realPlaces + 1), isNull);
  });

  test('next milestone is always ahead', () {
    for (final f in [0, 5, 20, realPlaces - 1, realPlaces + 3, realPlaces + 30]) {
      final (chapter, left) = Cosmos.nextChapter(f);
      expect(left, greaterThan(0), reason: 'from $f: ${chapter.title}');
    }
  });

  test('the signal is decoded in order along the journey', () {
    var lastIndex = -1;
    var lastFragment = 0;
    for (final e in transmissions.entries) {
      final k = Cosmos.indexOfId(e.key);
      expect(k, greaterThanOrEqualTo(lastIndex), reason: e.key);
      lastIndex = k;
      final f = e.value.fragment;
      if (f != null) {
        expect(f, lastFragment + 1);
        lastFragment = f;
      }
    }
    expect(lastFragment, signalFragments);
    expect(Cosmos.fragmentsDecoded((k) => true), signalFragments);
    expect(Cosmos.fragmentsDecoded((k) => k == 0), 0);
  });
}
