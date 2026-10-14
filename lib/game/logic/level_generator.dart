import 'dart:math' as math;
import 'dart:ui';

import 'difficulty.dart';
import 'models.dart';
import 'cosmos.dart';

/// Builds the endless chain of planets, one above the other.
/// Every planet is placed so it never overlaps its neighbour and stays on screen.
class LevelGenerator {
  LevelGenerator({required this.width, int? seed}) : _rng = math.Random(seed);

  final double width;
  final math.Random _rng;

  double _range(double a, double b) => a + _rng.nextDouble() * (b - a);

  Planet first(Offset center, {int landmark = 0}) => _landmark(landmark, center);

  /// Real places are calm rest stops: big, stable, no moons, no drift.
  Planet _landmark(int k, Offset center) {
    final l = journey[k];
    return Planet(
      index: k * hopsPerLandmark,
      baseCenter: center,
      radius: l.radius,
      orbitRadius: l.radius + 30,
      stability: double.infinity,
      look: l.look,
      landmark: k,
    );
  }

  Planet next(Planet prev) {
    final index = prev.index + 1;
    final d = Difficulty(index);
    final landmarkIndex = Cosmos.landmarkAt(index);
    if (landmarkIndex != null) return _nextLandmark(prev, landmarkIndex);

    final radius = _range(d.minRadius, d.maxRadius);
    final orbitRadius = radius + _range(24, 32);

    final moons = <Moon>[];
    if (_rng.nextDouble() < d.moonChance) {
      final count = index >= 14 && _rng.nextDouble() < 0.35 ? 2 : 1;
      final speed = _range(d.moonSpeedMin, d.moonSpeedMax) * (_rng.nextBool() ? 1 : -1);
      final start = _range(0, math.pi * 2);
      for (var i = 0; i < count; i++) {
        moons.add(Moon(angle: start + math.pi * i, angularSpeed: speed, radius: 8));
      }
    }
    final outer = moons.isEmpty ? orbitRadius : orbitRadius + Planet.moonRingGap + 8;

    final drifts = _rng.nextDouble() < d.driftChance;
    final driftAmplitude = drifts ? _range(30, 70) : 0.0;

    // Horizontal position: keep the whole system (incl. drift) inside the screen.
    final margin = outer + driftAmplitude + 8;
    final minX = margin;
    final maxX = width - margin;
    final x = maxX > minX ? _range(minX, maxX) : width / 2;

    // Vertical position: random gap, pushed further up if systems would overlap.
    final minDistance = prev.outerRadius + outer + prev.driftAmplitude + driftAmplitude + 36;
    final dx = (x - prev.baseCenter.dx).abs();
    var dy = _range(d.minGap, d.maxGap);
    if (math.sqrt(dx * dx + dy * dy) < minDistance) {
      final neededDy = dx >= minDistance ? 0.0 : math.sqrt(minDistance * minDistance - dx * dx);
      dy = math.max(dy, neededDy);
    }

    final fillers = Cosmos.regionAt(index).fillers;
    final look = fillers[_rng.nextInt(fillers.length)];

    return Planet(
      index: index,
      baseCenter: Offset(x, prev.baseCenter.dy - dy),
      radius: radius,
      orbitRadius: orbitRadius,
      stability: d.stability,
      look: look,
      moons: moons,
      driftAmplitude: driftAmplitude,
      driftSpeed: _range(0.6, 1.2),
      driftPhase: _range(0, math.pi * 2),
    );
  }

  Planet _nextLandmark(Planet prev, int k) {
    final l = journey[k];
    final outer = l.radius + 30.0;
    final margin = outer + 8;
    final x = width - margin > margin ? _range(margin, width - margin) : width / 2;
    final minDistance = prev.outerRadius + outer + prev.driftAmplitude + 36;
    final dx = (x - prev.baseCenter.dx).abs();
    final d = Difficulty(prev.index + 1);
    var dy = _range(d.minGap, d.maxGap);
    if (math.sqrt(dx * dx + dy * dy) < minDistance) {
      final neededDy = dx >= minDistance ? 0.0 : math.sqrt(minDistance * minDistance - dx * dx);
      dy = math.max(dy, neededDy);
    }
    return _landmark(k, Offset(x, prev.baseCenter.dy - dy));
  }

  /// Sometimes places a short line of stardust between two planets,
  /// rewarding a clean, direct jump.
  List<Stardust> stardustBetween(Planet a, Planet b) {
    if (b.index < 2 || _rng.nextDouble() > 0.55) return const <Stardust>[];
    return [
      for (final t in const [0.4, 0.5, 0.6])
        Stardust(Offset.lerp(a.baseCenter, b.baseCenter, t)!, _range(0, math.pi * 2)),
    ];
  }
}
