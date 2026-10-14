import 'dart:math' as math;
import 'dart:ui';

import '../../game/logic/cosmos.dart';
import 'size_scale.dart';

/// Something floating in space that the black hole might eat (or be hurt by).
/// Positions are relative to the hole, which always sits at the origin.
class SpaceThing {
  SpaceThing({
    required this.pos,
    required this.vel,
    required this.radius,
    required this.look,
    required this.seed,
  });

  Offset pos;
  Offset vel;
  final double radius;
  final BodyLook look;
  final int seed;
}

enum HoleEventType { eat, hurt, tierUp, death }

enum HoleDeath { evaporated, swallowed }

class HoleEvent {
  const HoleEvent(this.type, this.pos, {this.value = 0, this.argb = 0xFFFFFFFF});

  final HoleEventType type;

  /// Position relative to the hole (world metres).
  final Offset pos;
  final int value;
  final int argb;
}

/// Pure-Dart simulation of "Black Hole: Eat the Universe".
/// World units are metres; the hole is always at (0, 0) and everything else
/// moves around it. The camera keeps the hole about the same size on screen,
/// so the universe seems to shrink as you grow.
class HoleWorld {
  HoleWorld({required this.viewWidth, required this.viewHeight, int? seed}) : _rng = math.Random(seed) {
    scale = targetScreenRadius / radius;
    _fill(initial: true);
  }

  static const double startRadius = 0.001; // 2 mm across
  static const double targetScreenRadius = 24;
  static const double speedPx = 230; // hole speed on screen
  static const double edibleRatio = 0.9; // smaller than this × your size: food
  static const double lethalRatio = 2.0; // bigger than this × your size: swallows you
  static const double growth = 1.2;
  static const int population = 34;

  final double viewWidth;
  final double viewHeight;
  final math.Random _rng;

  double radius = startRadius;
  double maxRadius = startRadius;

  /// Pixels per metre (smoothed in log space).
  late double scale;
  int tier = 0;
  int eaten = 0;
  bool started = false;
  bool dead = false;
  HoleDeath? death;
  double invulnerable = 0;
  double sinceLastMeal = 0;

  /// Seconds since the first move.
  double elapsed = 0;

  /// No lethal objects at all for this long: let new players learn first.
  static const double safeStart = 25;

  /// Steering input from the player, length 0..1.
  Offset steer = Offset.zero;

  /// How far the camera has travelled on screen (for parallax stars).
  Offset cameraTravel = Offset.zero;

  final List<SpaceThing> things = [];
  final List<HoleEvent> events = [];

  double get diameter => radius * 2;

  /// Hawking radiation: small black holes evaporate faster (as in real
  /// physics), so the very start is the most urgent.
  double get evaporationRate => math.max(0.006, 0.03 * math.pow(0.85, tier).toDouble());

  double get viewRadius => math.sqrt(viewWidth * viewWidth + viewHeight * viewHeight) / 2 / scale;

  /// Danger level of a thing: 0 = food, 1 = hurts, 2 = swallows you.
  int dangerOf(SpaceThing t) {
    if (t.radius < radius * edibleRatio) return 0;
    if (t.radius > radius * lethalRatio) return 2;
    return 1;
  }

  void update(double rawDt) {
    if (dead || rawDt <= 0) return;
    final dt = math.min(rawDt, 1 / 30);
    if (steer.distance > 0.05) started = true;

    // Camera: keep the hole near its target size on screen.
    final target = targetScreenRadius / radius;
    final k = math.min(1.0, dt * 2.2);
    scale = math.exp(math.log(scale) + (math.log(target) - math.log(scale)) * k);

    // Move: everything slides past the hole.
    final s = steer.distance > 1 ? steer / steer.distance : steer;
    final v = s * (speedPx / scale);
    cameraTravel += s * (speedPx * dt);
    for (final t in things) {
      t.pos += (t.vel - v) * dt;
    }

    if (invulnerable > 0) invulnerable = math.max(0.0, invulnerable - dt);
    sinceLastMeal += dt;

    if (started) {
      elapsed += dt;
      radius *= 1 - evaporationRate * dt;
      if (radius < startRadius * 0.5) {
        _die(HoleDeath.evaporated);
        return;
      }
    }

    _interact(dt);
    if (dead) return;

    final newTier = tierOfRadius(radius);
    if (newTier > tier) {
      tier = newTier;
      events.add(HoleEvent(HoleEventType.tierUp, Offset.zero, value: tier));
    }
    maxRadius = math.max(maxRadius, radius);
    _fill();
  }

  void _interact(double dt) {
    final pullRange = radius * 3.2;
    final eatenNow = <SpaceThing>[];
    for (final t in things) {
      final d = t.pos.distance;
      if (d == 0) continue;
      final toHole = -t.pos / d;
      final danger = dangerOf(t);
      if (danger == 0) {
        // Gravity: food spirals in.
        if (d < pullRange) {
          final pull = radius * 9 * (1 - d / pullRange);
          final swirl = Offset(-toHole.dy, toHole.dx) * (pull * 0.35);
          t.vel += (toHole * pull + swirl) * dt;
        }
        if (d < radius * 0.95 + t.radius * 0.3) eatenNow.add(t);
      } else if (invulnerable <= 0 && d < radius + t.radius * 0.92) {
        if (danger == 2) {
          _die(HoleDeath.swallowed);
          return;
        }
        // Too big to eat: it knocks a chunk off you.
        radius *= 0.72;
        invulnerable = 1.4;
        t.vel += -toHole * (t.radius * 2.5);
        events.add(HoleEvent(HoleEventType.hurt, t.pos, argb: t.look.primary));
      }
    }
    for (final t in eatenNow) {
      things.remove(t);
      final f = t.radius / radius;
      radius *= math.sqrt(1 + growth * f * f);
      eaten++;
      sinceLastMeal = 0;
      events.add(HoleEvent(HoleEventType.eat, t.pos, value: eaten, argb: t.look.primary));
    }
  }

  void _die(HoleDeath cause) {
    dead = true;
    death = cause;
    events.add(HoleEvent(HoleEventType.death, Offset.zero, value: cause.index));
  }

  /// Keeps space full of things, spawning just off-screen and dropping
  /// anything that drifted far away.
  void _fill({bool initial = false}) {
    final view = viewRadius;
    things.removeWhere((t) => t.pos.distance > view * 2.2 || t.radius < radius * 0.02);
    while (things.length < population) {
      things.add(_spawn(view, initial: initial));
    }
  }

  double _logRange(double a, double b) => math.exp(math.log(a) + _rng.nextDouble() * (math.log(b) - math.log(a)));

  SpaceThing _spawn(double view, {required bool initial}) {
    // Danger rises as you grow; nothing lethal during the safe start.
    final lethal = initial || elapsed < safeStart ? 0.0 : math.min(0.12, 0.05 + 0.006 * tier);
    final hurts = math.min(0.30, 0.18 + 0.008 * tier);
    final roll = _rng.nextDouble();
    final f = roll < lethal
        ? _logRange(2.3, 3.4) // swallows you
        : roll < lethal + hurts
            ? _logRange(1.1, 1.9) // hurts
            : _logRange(0.2, 0.85); // food
    final r = radius * f;
    final angle = _rng.nextDouble() * math.pi * 2;
    // Initial fill covers the screen (but not right on top of you);
    // later spawns arrive from just outside it.
    final dist = initial ? view * (0.35 + _rng.nextDouble() * 0.75) : view * (1.15 + _rng.nextDouble() * 0.45);
    final dir = _rng.nextDouble() * math.pi * 2;
    final speed = (15 + _rng.nextDouble() * 45) / scale;
    final looks = tierInfo(tierOfRadius(r)).looks;
    return SpaceThing(
      pos: Offset(math.cos(angle), math.sin(angle)) * dist,
      vel: Offset(math.cos(dir), math.sin(dir)) * speed,
      radius: r,
      look: looks[_rng.nextInt(looks.length)],
      seed: _rng.nextInt(1000),
    );
  }
}
