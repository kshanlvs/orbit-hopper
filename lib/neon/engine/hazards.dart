import 'dart:math' as math;

// ------------------------------------------------------------------ geometry

/// Distance from a point to a rectangle (negative inside).
double distToRect(double px, double py, double x0, double y0, double x1, double y1) {
  final dx = math.max(x0 - px, px - x1);
  final dy = math.max(y0 - py, py - y1);
  if (dx <= 0 && dy <= 0) return math.max(dx, dy);
  final ex = math.max(dx, 0.0);
  final ey = math.max(dy, 0.0);
  return math.sqrt(ex * ex + ey * ey);
}

double distToSeg(double px, double py, double ax, double ay, double bx, double by) {
  final vx = bx - ax, vy = by - ay;
  final len2 = vx * vx + vy * vy;
  var t = len2 <= 1e-12 ? 0.0 : ((px - ax) * vx + (py - ay) * vy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + vx * t - px, cy = ay + vy * t - py;
  return math.sqrt(cx * cx + cy * cy);
}

double _cross(double ax, double ay, double bx, double by, double px, double py) =>
    (bx - ax) * (py - ay) - (by - ay) * (px - ax);

/// Distance from a point to a triangle (0 inside).
double distToTri(double px, double py, double ax, double ay, double bx, double by, double cx, double cy) {
  final d1 = _cross(ax, ay, bx, by, px, py);
  final d2 = _cross(bx, by, cx, cy, px, py);
  final d3 = _cross(cx, cy, ax, ay, px, py);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  if (!(hasNeg && hasPos)) return 0;
  return math.min(
    distToSeg(px, py, ax, ay, bx, by),
    math.min(distToSeg(px, py, bx, by, cx, cy), distToSeg(px, py, cx, cy, ax, ay)),
  );
}

double _frac(double v) => v - v.floorToDouble();

// ------------------------------------------------------------------- hazards

enum HazardKind { spike, block, laser, mover, rotor, nose }

/// Something that ends the run on contact.
///
/// Moving hazards are functions of the scroll distance `s` (the orb's x).
/// The orb always moves at a known speed, so this is the same as being a
/// function of time, and it lets the validator reproduce the game exactly.
///
/// [dashable] hazards (drawn magenta) can be passed through with Pulse
/// Dash; the others (cyan) are always solid.
abstract class Hazard {
  Hazard({required this.dashable});

  final bool dashable;

  HazardKind get kind;

  /// Horizontal extent, including any motion.
  double get left;
  double get right;

  /// Distance from a point to the solid shape at scroll [s].
  /// `double.infinity` when the hazard is switched off.
  double distance(double px, double py, double s);

  // Per-run bookkeeping (near misses, dash).
  double minClear = double.infinity;
  bool passed = false;
  bool pierced = false;
}

/// A triangular spike standing on the floor or hanging from the ceiling.
class Spike extends Hazard {
  Spike({required this.x, required this.width, required this.height, required this.baseY, required this.onFloor})
      : super(dashable: true);

  final double x, width, height, baseY;
  final bool onFloor;

  double get apexY => onFloor ? baseY - height : baseY + height;

  @override
  HazardKind get kind => HazardKind.spike;
  @override
  double get left => x;
  @override
  double get right => x + width;

  @override
  double distance(double px, double py, double s) =>
      distToTri(px, py, x, baseY, x + width, baseY, x + width / 2, apexY);
}

/// A solid rectangle (a floating block, or a wall chunk).
class Block extends Hazard {
  Block({required this.x0, required this.x1, required this.y0, required this.y1, super.dashable = true});

  final double x0, x1, y0, y1;

  @override
  HazardKind get kind => HazardKind.block;
  @override
  double get left => x0;
  @override
  double get right => x1;

  @override
  double distance(double px, double py, double s) => distToRect(px, py, x0, y0, x1, y1);
}

/// A vertical laser beam that switches on and off.
class Laser extends Hazard {
  Laser({
    required this.x,
    required this.y0,
    required this.y1,
    required this.period,
    required this.onFraction,
    required this.phase,
  }) : super(dashable: false);

  final double x, y0, y1;

  /// Cycle length in units of distance, and the share of it spent on.
  final double period, onFraction, phase;

  static const double halfWidth = 0.016;
  static const double warnShare = 0.2;

  double _f(double s) => _frac((s - phase) / period);

  bool active(double s) => _f(s) < onFraction;

  /// 0..1 while the beam is about to switch on (the warning flicker).
  double warning(double s) {
    final f = _f(s);
    final start = 1 - warnShare;
    return f > start ? (f - start) / warnShare : 0;
  }

  @override
  HazardKind get kind => HazardKind.laser;
  @override
  double get left => x - halfWidth;
  @override
  double get right => x + halfWidth;

  @override
  double distance(double px, double py, double s) =>
      active(s) ? distToRect(px, py, x - halfWidth, y0, x + halfWidth, y1) : double.infinity;
}

enum MoverMode { float, pistonFloor, pistonCeiling }

/// A block that slides up and down (float) or extends from a wall (piston).
class Mover extends Hazard {
  Mover({
    required this.x0,
    required this.x1,
    required this.mode,
    required this.period,
    required this.phase,
    this.center = 0.5,
    this.amplitude = 0.3,
    this.halfHeight = 0.18,
    this.wallY = 1,
    this.minLength = 0.05,
    this.maxLength = 0.5,
  }) : super(dashable: true);

  final double x0, x1;
  final MoverMode mode;
  final double period, phase;
  final double center, amplitude, halfHeight;
  final double wallY, minLength, maxLength;

  double wave(double s) => math.sin(2 * math.pi * (s - phase) / period);

  (double, double) span(double s) {
    switch (mode) {
      case MoverMode.float:
        final c = center + amplitude * wave(s);
        return (c - halfHeight, c + halfHeight);
      case MoverMode.pistonFloor:
        final len = minLength + (maxLength - minLength) * (0.5 + 0.5 * wave(s));
        return (wallY - len, wallY);
      case MoverMode.pistonCeiling:
        final len = minLength + (maxLength - minLength) * (0.5 + 0.5 * wave(s));
        return (wallY, wallY + len);
    }
  }

  @override
  HazardKind get kind => HazardKind.mover;
  @override
  double get left => x0;
  @override
  double get right => x1;

  @override
  double distance(double px, double py, double s) {
    final (a, b) = span(s);
    return distToRect(px, py, x0, a, x1, b);
  }
}

/// A spinning bar.
class Rotor extends Hazard {
  Rotor({
    required this.cx,
    required this.cy,
    required this.halfLength,
    required this.thickness,
    required this.angle0,
    required this.spin,
  }) : super(dashable: false);

  final double cx, cy, halfLength, thickness, angle0;

  /// Radians per unit of distance.
  final double spin;

  double angle(double s) => angle0 + spin * s;

  (double, double, double, double) ends(double s) {
    final a = angle(s);
    final dx = math.cos(a) * halfLength, dy = math.sin(a) * halfLength;
    return (cx - dx, cy - dy, cx + dx, cy + dy);
  }

  @override
  HazardKind get kind => HazardKind.rotor;
  @override
  double get left => cx - halfLength - thickness;
  @override
  double get right => cx + halfLength + thickness;

  @override
  double distance(double px, double py, double s) {
    final (ax, ay, bx, by) = ends(s);
    return distToSeg(px, py, ax, ay, bx, by) - thickness;
  }
}

/// The pointed front of a Risk Gate divider.
class Nose extends Hazard {
  Nose({required this.x, required this.y, required this.halfHeight}) : super(dashable: false);

  final double x, y, halfHeight;
  static const double length = 0.14;

  @override
  HazardKind get kind => HazardKind.nose;
  @override
  double get left => x - length;
  @override
  double get right => x + 0.01;

  @override
  double distance(double px, double py, double s) =>
      distToTri(px, py, x - length, y, x + 0.01, y - halfHeight, x + 0.01, y + halfHeight);
}

// --------------------------------------------------------------- surfaces

/// A harmless solid slab the orb can ride on (a Risk Gate divider).
/// Touching its front face side-on ends the run.
class Platform {
  const Platform({required this.x0, required this.x1, required this.y0, required this.y1});

  final double x0, x1, y0, y1;
}

/// A straight piece of corridor wall. Ramps make the corridor narrow and
/// widen smoothly; the orb rides along them.
class BoundSeg {
  const BoundSeg({
    required this.x0,
    required this.x1,
    required this.top0,
    required this.top1,
    required this.bot0,
    required this.bot1,
  });

  final double x0, x1, top0, top1, bot0, bot1;

  double _t(double x) => x1 <= x0 ? 1 : ((x - x0) / (x1 - x0)).clamp(0.0, 1.0);
  double top(double x) => top0 + (top1 - top0) * _t(x);
  double bot(double x) => bot0 + (bot1 - bot0) * _t(x);
}

/// An energy shard.
class Shard {
  Shard({required this.x, required this.y, required this.group, this.risk = false});

  final double x, y;
  final int group;
  final bool risk;
  bool collected = false;
}

// ------------------------------------------------------------------- chunk

enum BreakVariant { prism, flux, twist, squeeze }

extension BreakVariantInfo on BreakVariant {
  String get title => switch (this) {
        BreakVariant.prism => 'PRISM',
        BreakVariant.flux => 'FLUX',
        BreakVariant.twist => 'TWIST',
        BreakVariant.squeeze => 'SQUEEZE',
      };
}

enum ChunkRole { normal, breather, breakIntro, breakBody, breakOutro, chaseIntro, chaseBody, escape }

/// One generated piece of corridor: a pattern plus the empty run-in before
/// it. Hazards never extend outside [x0, x1].
class Chunk {
  Chunk({
    required this.x0,
    required this.x1,
    required this.speed,
    required this.patternId,
    required this.rating,
    required this.minReaction,
    required this.entryTop,
    required this.entryBot,
    required this.exitTop,
    required this.exitBot,
    this.role = ChunkRole.normal,
    this.variant,
    List<Hazard>? hazards,
    List<Platform>? platforms,
    List<BoundSeg>? bounds,
    List<Shard>? shards,
  })  : hazards = hazards ?? [],
        platforms = platforms ?? [],
        bounds = bounds ?? [],
        shards = shards ?? [];

  final double x0;
  double x1;
  final double speed;
  final String patternId;
  final int rating;
  final double minReaction;
  final double entryTop, entryBot, exitTop, exitBot;
  final ChunkRole role;
  final BreakVariant? variant;

  final List<Hazard> hazards;
  final List<Platform> platforms;
  final List<BoundSeg> bounds;
  final List<Shard> shards;

  /// Risk Gate layout: which channel is the dangerous one, and where the
  /// divider runs. Null when the chunk has no gate.
  bool? riskTop;
  double riskX0 = 0, riskX1 = 0;
  int riskShards = 0;

  /// Set by the generator.
  bool validated = false;
  bool fallback = false;

  // Per-run bookkeeping.
  bool entered = false;
  bool warned = false;

  bool contains(double x) => x >= x0 && x < x1;

  /// Corridor ceiling at [x]. Bound segments are sorted by x; between them
  /// the wall keeps the height the previous segment ended at.
  double top(double x) {
    var y = entryTop;
    for (final b in bounds) {
      if (x < b.x0) break;
      if (x <= b.x1) return b.top(x);
      y = b.top1;
    }
    return y;
  }

  double bot(double x) {
    var y = entryBot;
    for (final b in bounds) {
      if (x < b.x0) break;
      if (x <= b.x1) return b.bot(x);
      y = b.bot1;
    }
    return y;
  }

  int get shardGroups {
    var n = 0;
    for (final s in shards) {
      n = math.max(n, s.group + 1);
    }
    return n;
  }
}
