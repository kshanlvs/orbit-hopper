import 'dart:math' as math;
import 'dart:ui';

import 'cosmos.dart';
import 'difficulty.dart';
import 'level_generator.dart';
import 'models.dart';

enum WorldEventType {
  launch,
  capture,
  perfect,
  stardust,
  death,
  warning,
  region,
  discovery,
  depart,
  wormhole,
  shieldGet,
  shieldBreak,
  killerSpawn,
  deflect,
}

class WorldEvent {
  const WorldEvent(this.type, this.position, {this.value = 0, this.argb = 0xFFFFFFFF});

  final WorldEventType type;
  final Offset position;
  final int value;

  /// Colour of the body involved (for effects).
  final int argb;
}

/// Pure-Dart simulation of Orbit Hopper. No Flame, no rendering —
/// fully unit-testable. World coordinates: x right, y down; the camera
/// scrolls upward (cameraY becomes more negative).
class GameWorld {
  GameWorld({
    required this.width,
    required this.height,
    int? seed,
    int startLandmark = 0,
    DefenseConfig? defense,
  })  : startLandmark = math.max(0, startLandmark),
        defense = defense == null ? null : DefenseState(defense),
        _generator = LevelGenerator(width: width, seed: seed, asteroidsEverywhere: defense != null) {
    _reset();
  }

  /// Non-null in "Save Earth" mode.
  final DefenseState? defense;

  /// Checkpoint the run starts from (index into [journey]).
  final int startLandmark;
  int get startIndex => startLandmark * hopsPerLandmark;

  static const double cometRadius = 7;
  static const double captureBand = 26;
  static const double stardustPickupRadius = 20;
  static const double shieldPickupRadius = 24;
  static const double maxFlightTime = 2.4;

  /// Entry with a radial share below this counts as a "perfect" skim.
  static const double perfectRadialLimit = 0.45;

  final double width;
  final double height;
  final LevelGenerator _generator;

  final List<Planet> planets = [];
  final List<Stardust> stardust = [];
  final List<Asteroid> asteroids = [];
  final List<Wormhole> wormholes = [];
  final List<ShieldPickup> shields = [];
  final RunStats stats = RunStats();

  /// True while the comet carries a shield bubble.
  bool shield = false;

  /// Seconds of invulnerability left after a shield breaks.
  double invulnerable = 0;

  /// Events since the last time the consumer cleared this list.
  final List<WorldEvent> events = [];
  final Comet comet = Comet();

  double cameraY = 0;
  int score = 0;
  int combo = 0;
  int bestIndex = 0;
  int stardustCollected = 0;
  bool started = false;
  DeathCause? deathCause;

  bool get isDead => comet.mode == CometMode.dead;
  Region get region => Cosmos.regionAt(bestIndex);

  /// Real distance from the Sun at the furthest planet reached.
  double get distanceAu => Cosmos.distanceAuAt(bestIndex);

  /// Hops climbed in this run.
  int get hopsThisRun => bestIndex - startIndex;

  /// Fractional journey position: [bestIndex] plus how far the comet has
  /// climbed toward the next planet. Drives the live distance odometer.
  double get travelIndex {
    final from = comet.lastPlanet;
    if (comet.mode != CometMode.flying || from == null || from.index != bestIndex) {
      return bestIndex.toDouble();
    }
    for (final p in planets) {
      if (p.index == bestIndex + 1) {
        final span = from.center.dy - p.center.dy;
        if (span <= 0) break;
        final f = ((from.center.dy - comet.position.dy) / span).clamp(0.0, 0.95).toDouble();
        return bestIndex + f;
      }
    }
    return bestIndex.toDouble();
  }

  /// Direction the comet would fly if launched right now.
  Offset get launchDirection =>
      Offset(-math.sin(comet.angle), math.cos(comet.angle)) * comet.orbitDirection;

  void _reset() {
    final first = _generator.first(Offset(width / 2, height * 0.68), landmark: startLandmark);
    bestIndex = first.index;
    planets.add(first);
    _fillAhead();
    comet
      ..mode = CometMode.orbiting
      ..planet = first
      ..angle = -math.pi / 2
      ..radius = first.orbitRadius
      ..orbitDirection = 1
      ..orbitSpeed = Difficulty(first.index).orbitSpeed;
    comet.position = first.center + _unit(comet.angle) * comet.radius;
    events.add(WorldEvent(WorldEventType.depart, first.center, value: startLandmark, argb: first.look.primary));
  }

  /// Player tap. Returns true if the comet launched.
  bool launch() {
    if (comet.mode != CometMode.orbiting) return false;
    final planet = comet.planet!;
    started = true;
    comet.speed = Difficulty(bestIndex).launchSpeed;
    comet.velocity = launchDirection * comet.speed;
    comet
      ..lastPlanet = planet
      ..planet = null
      ..mode = CometMode.flying
      ..flightTime = 0;
    events.add(WorldEvent(WorldEventType.launch, comet.position));
    return true;
  }

  void update(double rawDt) {
    if (rawDt <= 0) return;
    final dt = math.min(rawDt, 1 / 30); // avoid tunnelling on frame drops

    for (final p in planets) {
      p.update(dt);
    }
    for (final a in asteroids) {
      final x = a.position.dx + a.speed * dt;
      // Wrap around the screen edges.
      final wrapped = x < -24 ? x + width + 48 : (x > width + 24 ? x - width - 48 : x);
      a.position = Offset(wrapped, a.position.dy);
      a.angle += a.spin * dt;
    }
    if (invulnerable > 0) invulnerable = math.max(0.0, invulnerable - dt);
    _updateDefense(dt);

    if (comet.mode == CometMode.orbiting) {
      _updateOrbit(dt);
    } else if (comet.mode == CometMode.flying) {
      _updateFlight(dt);
    }

    _updateCamera(dt);
    _fillAhead();
    _cull();
  }

  void _updateOrbit(double dt) {
    final p = comet.planet!;
    final omega = comet.orbitSpeed / math.max(comet.radius, 1.0) * comet.orbitDirection;
    comet.angle += omega * dt;
    // Ease into the ideal orbit — looks like being "pulled in".
    comet.radius += (p.orbitRadius - comet.radius) * math.min(1.0, dt * 6);
    comet.position = p.center + _unit(comet.angle) * comet.radius;

    if (started && p.stability.isFinite) {
      final before = p.stabilityLeft;
      p.timeHeld += dt;
      if (before > 0.3 && p.stabilityLeft <= 0.3) {
        events.add(WorldEvent(WorldEventType.warning, p.center, argb: p.look.primary));
      }
      if (p.timeHeld >= p.stability) {
        p.collapsed = true;
        _die(DeathCause.collapse);
      }
    }
  }

  void _updateFlight(double dt) {
    comet.flightTime += dt;

    // Gentle gravity assist toward nearby planets: forgiving, feels magnetic.
    var v = comet.velocity;
    for (final p in planets) {
      if (identical(p, comet.lastPlanet) || p.collapsed) continue;
      final delta = p.center - comet.position;
      final d = delta.distance;
      final reach = p.orbitRadius * 2.2;
      if (d > 0 && d < reach) {
        final strength = 1600 * (1 - d / reach);
        v += delta / d * (strength * dt);
      }
    }
    final len = v.distance;
    comet.velocity = len == 0 ? v : v / len * comet.speed;
    comet.position += comet.velocity * dt;

    // Ramming the killer asteroid comes first: if you touch it and a rock
    // in the same frame, Earth is saved.
    final def = defense;
    final killer = def?.killer;
    if (def != null && killer != null &&
        (killer.position - comet.position).distance < cometRadius + KillerAsteroid.radius) {
      def.killer = null;
      def.won = true;
      invulnerable = double.infinity; // nothing can hurt you after saving Earth
      events.add(WorldEvent(WorldEventType.deflect, killer.position));
    }

    // Moons and asteroids are deadly (unless shielded).
    for (final p in planets) {
      for (final m in p.moons) {
        if ((p.moonPosition(m) - comet.position).distance < cometRadius + m.radius) {
          if (_hit(DeathCause.moon, p.moonPosition(m))) return;
        }
      }
    }
    for (final a in asteroids) {
      if ((a.position - comet.position).distance < cometRadius + a.radius) {
        if (_hit(DeathCause.asteroid, a.position)) return;
      }
    }

    for (final s in shields) {
      if (!s.collected && (s.position - comet.position).distance < shieldPickupRadius) {
        s.collected = true;
        shield = true;
        events.add(WorldEvent(WorldEventType.shieldGet, s.position));
      }
    }

    // Find first, warp after: warping generates planets (and wormholes),
    // which must not happen while iterating the list.
    Wormhole? entered;
    for (final w in wormholes) {
      if (!w.used && (w.position - comet.position).distance < Wormhole.radius) {
        entered = w;
        break;
      }
    }
    if (entered != null) {
      entered.used = true;
      if (_warp(entered)) return;
    }

    for (final s in stardust) {
      if (!s.collected && (s.position - comet.position).distance < stardustPickupRadius) {
        s.collected = true;
        stardustCollected++;
        stats.stardust = stardustCollected;
        events.add(WorldEvent(WorldEventType.stardust, s.position));
      }
    }

    for (final p in planets) {
      if (identical(p, comet.lastPlanet) || p.collapsed) continue;
      final d = (comet.position - p.center).distance;
      if (d <= p.orbitRadius + captureBand) {
        _capture(p, d);
        return;
      }
    }

    final pos = comet.position;
    if (pos.dx < -30 ||
        pos.dx > width + 30 ||
        pos.dy > cameraY + height + 40 ||
        comet.flightTime > maxFlightTime) {
      _die(DeathCause.lost);
    }
  }

  void _capture(Planet p, double d) {
    final rel = comet.position - p.center;
    final v = comet.velocity;
    final cross = rel.dx * v.dy - rel.dy * v.dx;
    final radialShare =
        d == 0 || comet.speed == 0 ? 1.0 : ((rel.dx * v.dx + rel.dy * v.dy) / (d * comet.speed)).abs();

    comet
      ..mode = CometMode.orbiting
      ..planet = p
      ..angle = math.atan2(rel.dy, rel.dx)
      ..radius = math.max(d, p.radius + cometRadius + 2)
      ..orbitDirection = cross >= 0 ? 1.0 : -1.0
      ..orbitSpeed = Difficulty(p.index).orbitSpeed
      ..flightTime = 0;

    if (p.index <= bestIndex) {
      events.add(WorldEvent(WorldEventType.capture, comet.position, argb: p.look.primary));
      return;
    }

    final skipped = p.index - bestIndex; // jumping over planets pays extra
    final perfect = radialShare < perfectRadialLimit;
    combo = perfect ? combo + 1 : 0;
    final int bonus = perfect ? math.min(combo, 5) : 0;
    final points = skipped + bonus;
    final oldRegion = region;
    bestIndex = p.index;
    score += points;
    stats.hops = hopsThisRun;
    if (perfect) stats.perfects++;
    final def = defense;
    if (def != null && def.active && !def.charged) {
      def.charge = math.min(def.config.chargeNeeded, def.charge + skipped + (perfect ? 1 : 0));
      if (def.charged) _spawnKiller();
    }
    stats.maxCombo = math.max(stats.maxCombo, combo);

    events.add(WorldEvent(WorldEventType.capture, comet.position, value: points, argb: p.look.primary));
    if (perfect) {
      events.add(WorldEvent(WorldEventType.perfect, comet.position, value: combo, argb: p.look.primary));
    }
    if (!identical(region, oldRegion)) {
      events.add(WorldEvent(WorldEventType.region, comet.position, value: bestIndex));
    }
    final landmark = p.landmark;
    if (landmark != null) {
      events.add(WorldEvent(WorldEventType.discovery, p.center, value: landmark, argb: p.look.primary));
    }
  }

  /// A collision. Returns true if it ended the run.
  bool _hit(DeathCause cause, Offset at) {
    if (invulnerable > 0) return false;
    if (shield) {
      shield = false;
      invulnerable = 1.2;
      stats.shieldSaves++;
      events.add(WorldEvent(WorldEventType.shieldBreak, at));
      return false;
    }
    _die(cause);
    return true;
  }

  /// Teleports the comet into orbit around the wormhole's target planet.
  bool _warp(Wormhole w) {
    _fillAhead();
    Planet? target;
    for (final p in planets) {
      if (p.index == w.targetIndex) target = p;
    }
    if (target == null || target.collapsed) return false;
    final from = comet.position;
    // Arrive on the near side of the orbit, moving tangentially: a clean,
    // perfect entry.
    final angle = math.pi / 2 + (from.dx < target.center.dx ? 0.35 : -0.35);
    comet.position = target.center + _unit(angle) * target.orbitRadius;
    comet.velocity = Offset(-math.sin(angle), math.cos(angle)) * comet.speed;
    stats.wormholes++;
    events.add(WorldEvent(WorldEventType.wormhole, from, value: target.index - bestIndex));
    _capture(target, target.orbitRadius);
    return true;
  }

  void _updateDefense(double dt) {
    final d = defense;
    if (d == null || !d.active) return;
    if (started && comet.mode != CometMode.dead) {
      d.timeLeft = math.max(0.0, d.timeLeft - dt);
      if (d.timeLeft <= 0) {
        d.failed = true;
        _die(DeathCause.impact);
        return;
      }
    }
    final k = d.killer;
    if (k == null) return;
    _swayKiller(d, k);
    k.angle += dt * 0.8;
    // Fell behind the camera? It slips ahead again — keep chasing.
    if (k.position.dy > cameraY + height + 60) _spawnKiller();
  }

  /// Sways the killer side to side as it hurtles toward Earth.
  void _swayKiller(DefenseState d, KillerAsteroid k) {
    final x = (k.base.dx + math.sin(d.timeLeft * 0.9 + k.phase) * k.sway)
        .clamp(KillerAsteroid.radius + 8, width - KillerAsteroid.radius - 8)
        .toDouble();
    k.position = Offset(x, k.base.dy);
  }

  /// Places the killer asteroid in the first gap ahead (after the next
  /// planet) that has clear space, away from every planet's pull.
  void _spawnKiller() {
    final d = defense;
    if (d == null) return;
    _fillAhead();
    const margin = KillerAsteroid.radius + 12;
    Offset? spot;
    var spotSlack = double.negativeInfinity;
    for (var gap = 1; gap <= 3; gap++) {
      Planet? a;
      Planet? b;
      for (final p in planets) {
        if (p.index == bestIndex + gap) a = p;
        if (p.index == bestIndex + gap + 1) b = p;
      }
      if (a == null || b == null) break;
      final midY = (a.baseCenter.dy + b.baseCenter.dy) / 2;
      double clearance(Planet p, double x) {
        final pull = math.max(p.outerRadius, p.orbitRadius + captureBand) + p.driftAmplitude;
        return (Offset(x, midY) - p.baseCenter).distance - pull - KillerAsteroid.radius - 16;
      }

      for (var i = 0; i <= 12; i++) {
        final x = margin + (width - 2 * margin) * i / 12;
        final slack = math.min(clearance(a, x), clearance(b, x));
        if (slack > spotSlack) {
          spotSlack = slack;
          spot = Offset(x, midY);
        }
      }
      if (spotSlack >= 0) break; // good enough — nearest clear gap wins
    }
    if (spot == null) return;
    final killer = KillerAsteroid(spot, _rngPhase(), sway: spotSlack.clamp(0.0, 45.0).toDouble());
    _swayKiller(d, killer); // place it where it will be drawn, from frame one
    d.killer = killer;
    // Clear debris near it so the intercept is fair.
    final y = spot.dy;
    asteroids.removeWhere((r) => (r.position.dy - y).abs() < 80);
    events.add(WorldEvent(WorldEventType.killerSpawn, spot));
  }

  double _phaseSeed = 0;
  double _rngPhase() => _phaseSeed += 1.7;

  void _die(DeathCause cause) {
    if (isDead) return;
    if (defense?.won ?? false) return; // the victory lap can't fail
    deathCause = cause;
    comet.mode = CometMode.dead;
    events.add(WorldEvent(
      WorldEventType.death,
      comet.position,
      value: cause.index,
      argb: comet.planet?.look.primary ?? 0xFFFFFFFF,
    ));
  }

  void _updateCamera(double dt) {
    var target = cameraY;
    if (comet.mode == CometMode.orbiting) {
      target = comet.planet!.center.dy - height * 0.66;
    } else if (comet.mode == CometMode.flying) {
      final topZone = cameraY + height * 0.35;
      if (comet.position.dy < topZone) target = comet.position.dy - height * 0.35;
    }
    cameraY += (target - cameraY) * math.min(1.0, dt * 3);
  }

  void _fillAhead() {
    while (planets.last.baseCenter.dy > cameraY - height * 1.5) {
      final prev = planets.last;
      final next = _generator.next(prev);
      planets.add(next);
      final hole = _generator.wormholeBetween(prev, next);
      if (hole != null) {
        wormholes.add(hole);
      } else {
        stardust.addAll(_generator.stardustBetween(prev, next));
        final s = _generator.shieldBetween(prev, next);
        if (s != null) shields.add(s);
      }
      asteroids.addAll(_generator.asteroidsBetween(prev, next));
    }
  }

  void _cull() {
    final limit = cameraY + height + 500;
    planets.removeWhere((p) =>
        p.baseCenter.dy > limit && !identical(p, comet.planet) && !identical(p, comet.lastPlanet));
    stardust.removeWhere((s) => s.position.dy > limit);
    asteroids.removeWhere((a) => a.position.dy > limit);
    wormholes.removeWhere((w) => w.position.dy > limit);
    shields.removeWhere((s) => s.position.dy > limit);
  }

  static Offset _unit(double angle) => Offset(math.cos(angle), math.sin(angle));
}
