import 'dart:math' as math;
import 'dart:ui';

import 'cosmos.dart';

class Moon {
  Moon({required this.angle, required this.angularSpeed, required this.radius});

  double angle;
  final double angularSpeed;
  final double radius;
}

class Planet {
  Planet({
    required this.index,
    required this.baseCenter,
    required this.radius,
    required this.orbitRadius,
    required this.stability,
    required this.look,
    this.landmark,
    this.moons = const <Moon>[],
    this.driftAmplitude = 0,
    this.driftSpeed = 0,
    this.driftPhase = 0,
  }) : center = baseCenter;

  /// Gap between the comet's orbit and the moon ring.
  static const double moonRingGap = 34;

  final int index;
  final Offset baseCenter;
  final double radius;
  final double orbitRadius;

  /// Seconds the comet may orbit before collapse. Infinity = stable.
  final double stability;

  /// How the body is drawn.
  final BodyLook look;

  /// Index into [journey] if this is a real place, otherwise null.
  final int? landmark;
  final List<Moon> moons;
  final double driftAmplitude;
  final double driftSpeed;
  final double driftPhase;

  Offset center;
  double age = 0;
  double timeHeld = 0;
  bool collapsed = false;

  double get moonRingRadius => orbitRadius + moonRingGap;

  /// Furthest extent of anything dangerous/occupied around this planet.
  double get outerRadius => moons.isEmpty ? orbitRadius : moonRingRadius + 8;

  /// 1 = fully stable, 0 = collapsing.
  double get stabilityLeft =>
      stability.isInfinite ? 1.0 : (1 - timeHeld / stability).clamp(0.0, 1.0).toDouble();

  void update(double dt) {
    age += dt;
    if (driftAmplitude > 0) {
      center = Offset(
        baseCenter.dx + driftAmplitude * math.sin(age * driftSpeed + driftPhase),
        baseCenter.dy,
      );
    }
    for (final m in moons) {
      m.angle += m.angularSpeed * dt;
    }
  }

  Offset moonPosition(Moon m) =>
      center + Offset(math.cos(m.angle), math.sin(m.angle)) * moonRingRadius;
}

class Stardust {
  Stardust(this.position, this.phase);

  final Offset position;
  final double phase;
  bool collected = false;
}

/// A rock drifting sideways across a gap (Asteroid Belt, Kuiper Belt).
class Asteroid {
  Asteroid({required this.position, required this.speed, required this.radius, required this.spin, required this.seed});

  Offset position;

  /// Horizontal speed in px/s (negative = moving left). Wraps around the screen.
  final double speed;
  final double radius;
  final double spin;
  final int seed;
  double angle = 0;
}

/// A rare portal: fly through it to warp straight to planet [targetIndex].
class Wormhole {
  Wormhole(this.position, this.targetIndex, this.phase);

  static const double radius = 24;

  final Offset position;
  final int targetIndex;
  final double phase;
  bool used = false;
}

/// A bubble that absorbs one moon or asteroid hit.
class ShieldPickup {
  ShieldPickup(this.position);

  final Offset position;
  bool collected = false;
}

/// What happened in a run — feeds missions and the game-over screen.
class RunStats {
  int hops = 0;
  int perfects = 0;
  int maxCombo = 0;
  int stardust = 0;
  int wormholes = 0;
  int shieldSaves = 0;
  int newDiscoveries = 0;
}

enum CometMode { orbiting, flying, dead }

enum DeathCause { moon, collapse, lost, asteroid }

class Comet {
  CometMode mode = CometMode.orbiting;
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  Planet? planet;
  Planet? lastPlanet;
  double angle = 0;
  double radius = 0;

  /// +1 or -1: which way the comet circles its planet.
  double orbitDirection = 1;
  double orbitSpeed = 200;
  double speed = 0;
  double flightTime = 0;
}
