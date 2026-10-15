import 'dart:math' as math;

import 'hazards.dart';
import 'rng.dart';

/// What a pattern builder gets: where to start, how fast the orb is going,
/// how hard to be, and the chunk to fill.
class PatternCtx {
  PatternCtx({
    required this.rng,
    required this.chunk,
    required this.x,
    required this.speed,
    required this.difficulty,
    required this.top,
    required this.bot,
  });

  final NeonRng rng;
  final Chunk chunk;

  /// Where the pattern body starts.
  final double x;
  final double speed;

  /// 0 (first seconds) .. 1 (late game).
  final double difficulty;

  /// Corridor walls throughout the pattern body.
  final double top, bot;

  double get h => bot - top;
  double get mid => (top + bot) / 2;

  /// Distance covered in [seconds] at the current speed. Spacing is set in
  /// time, so patterns feel the same at any speed.
  double t(double seconds) => seconds * speed;

  /// Lerp by difficulty.
  double byD(double easy, double hard) => easy + (hard - easy) * difficulty;

  static const double spikeW = 0.15;

  /// A run of [n] spikes on one wall starting at [at]. Returns the end x.
  double spikes(double at, int n, {required bool onFloor, double? height, double? baseY}) {
    final hgt = height ?? h * 0.28;
    for (var i = 0; i < n; i++) {
      chunk.hazards.add(Spike(
        x: at + i * spikeW,
        width: spikeW,
        height: hgt,
        baseY: baseY ?? (onFloor ? bot : top),
        onFloor: onFloor,
      ));
    }
    return at + n * spikeW;
  }
}

typedef PatternBuilder = double Function(PatternCtx c);

enum Pool { normal, prism, flux, twist, squeeze, chase }

/// One entry in the obstacle pattern registry.
class PatternDef {
  const PatternDef({
    required this.id,
    required this.name,
    required this.rating,
    required this.minReaction,
    required this.pools,
    required this.build,
    this.weight = 1,
    this.shards = 4,
  });

  final String id;
  final String name;

  /// Difficulty rating 0 (breather) .. 9.
  final int rating;

  /// Shortest gap between taps (seconds) a player needs to get through.
  /// The validator proves a route exists with taps at least this far apart.
  final double minReaction;

  final Set<Pool> pools;
  final PatternBuilder build;
  final double weight;

  /// Shards placed along a proven route.
  final int shards;
}

// ------------------------------------------------------------------ builders

double _spikeRow(PatternCtx c) {
  final n = 2 + c.rng.nextInt(3);
  return c.spikes(c.x, n, onFloor: c.rng.chance(0.5), height: c.h * c.rng.range(0.24, 0.32));
}

double _alternator(PatternCtx c, {double? gap, int? groups, double? height}) {
  final k = groups ?? (3 + (c.difficulty * 3).round() + c.rng.nextInt(2));
  final tg = gap ?? c.byD(0.85, 0.5);
  var onFloor = c.rng.chance(0.5);
  var x = c.x;
  var end = x;
  for (var i = 0; i < k; i++) {
    final n = 1 + c.rng.nextInt(2);
    end = c.spikes(x, n, onFloor: onFloor, height: height ?? c.h * c.rng.range(0.24, 0.34));
    x += c.t(tg) + (n - 1) * PatternCtx.spikeW;
    onFloor = !onFloor;
  }
  return end;
}

double _floatTrap(PatternCtx c) {
  var x = c.x;
  var end = x;
  final reps = 1 + (c.difficulty > 0.4 ? 1 : 0);
  for (var i = 0; i < reps; i++) {
    final w = c.rng.range(0.22, 0.32);
    final cy = c.mid + c.h * c.rng.range(-0.05, 0.05);
    final hh = c.h * 0.13;
    c.chunk.hazards.add(Block(x0: x, x1: x + w, y0: cy - hh, y1: cy + hh));
    final sx = x + w + c.t(c.byD(0.6, 0.42));
    end = c.spikes(sx, 1 + c.rng.nextInt(2), onFloor: c.rng.chance(0.5));
    x = end + c.t(0.5);
  }
  return end;
}

double _narrow(PatternCtx c) {
  final inset = c.h * 0.18;
  final ramp = c.t(0.4);
  final hold = c.t(c.byD(1.5, 1.1));
  final x0 = c.x, x1 = x0 + ramp, x2 = x1 + hold, x3 = x2 + ramp;
  final it = c.top + inset, ib = c.bot - inset;
  c.chunk.bounds.addAll([
    BoundSeg(x0: x0, x1: x1, top0: c.top, top1: it, bot0: c.bot, bot1: ib),
    BoundSeg(x0: x1, x1: x2, top0: it, top1: it, bot0: ib, bot1: ib),
    BoundSeg(x0: x2, x1: x3, top0: it, top1: c.top, bot0: ib, bot1: c.bot),
  ]);
  final inner = ib - it;
  var onFloor = c.rng.chance(0.5);
  final count = 2 + (c.difficulty > 0.5 ? 1 : 0);
  final spacing = (hold - c.t(0.3)) / count;
  for (var i = 0; i < count; i++) {
    c.spikes(x1 + c.t(0.25) + i * spacing, 1, onFloor: onFloor, height: inner * 0.3, baseY: onFloor ? ib : it);
    onFloor = !onFloor;
  }
  return x3;
}

double _laserGate(PatternCtx c, {int? gates}) {
  final n = gates ?? (2 + (c.difficulty > 0.5 ? 1 : 0));
  final period = c.t(c.byD(1.35, 0.95));
  var x = c.x + 0.05;
  for (var i = 0; i < n; i++) {
    final phase = c.rng.range(0, period);
    c.chunk.hazards
      ..add(Laser(x: x, y0: c.top, y1: c.mid, period: period, onFraction: 0.46, phase: phase))
      ..add(Laser(x: x, y0: c.mid, y1: c.bot, period: period, onFraction: 0.46, phase: phase + period / 2));
    x += c.t(c.byD(1.0, 0.75));
  }
  return x;
}

double _laserCascade(PatternCtx c) {
  final n = 3 + c.rng.nextInt(2);
  final period = c.t(c.byD(1.2, 0.9));
  var x = c.x + 0.05;
  var upper = c.rng.chance(0.5);
  for (var i = 0; i < n; i++) {
    c.chunk.hazards.add(Laser(
      x: x,
      y0: upper ? c.top : c.mid - c.h * 0.05,
      y1: upper ? c.mid + c.h * 0.05 : c.bot,
      period: period,
      onFraction: 0.55,
      phase: c.rng.range(0, period),
    ));
    upper = !upper;
    x += c.t(c.byD(0.6, 0.45));
  }
  return x;
}

double _movers(PatternCtx c) {
  final n = 1 + (c.difficulty > 0.35 ? 1 : 0) + (c.difficulty > 0.75 ? 1 : 0);
  final hh = c.h * 0.17;
  final period = c.t(c.byD(1.6, 1.15));
  var x = c.x;
  var end = x;
  for (var i = 0; i < n; i++) {
    final w = c.rng.range(0.18, 0.24);
    c.chunk.hazards.add(Mover(
      x0: x,
      x1: x + w,
      mode: MoverMode.float,
      period: period,
      phase: c.rng.range(0, period),
      center: c.mid,
      amplitude: c.h / 2 - hh,
      halfHeight: hh,
    ));
    end = x + w;
    x = end + c.t(c.byD(0.95, 0.7));
  }
  return end;
}

double _crusher(PatternCtx c) {
  final n = 3 + c.rng.nextInt(2);
  final period = c.t(c.byD(1.4, 1.0));
  var x = c.x;
  var end = x;
  var fromFloor = c.rng.chance(0.5);
  for (var i = 0; i < n; i++) {
    const w = 0.18;
    c.chunk.hazards.add(Mover(
      x0: x,
      x1: x + w,
      mode: fromFloor ? MoverMode.pistonFloor : MoverMode.pistonCeiling,
      period: period,
      phase: c.rng.range(0, period),
      wallY: fromFloor ? c.bot : c.top,
      minLength: 0,
      maxLength: c.h * 0.6,
    ));
    end = x + w;
    x = end + c.t(c.byD(0.62, 0.48));
    fromFloor = !fromFloor;
  }
  return end;
}

double _rotor(PatternCtx c, {int? count}) {
  final n = count ?? (1 + (c.difficulty > 0.6 ? 1 : 0));
  final hl = c.h * 0.4;
  var x = c.x + hl;
  var end = x;
  var dir = c.rng.chance(0.5) ? 1.0 : -1.0;
  for (var i = 0; i < n; i++) {
    final spin = dir * 2 * math.pi / c.t(c.byD(1.7, 1.2));
    c.chunk.hazards.add(Rotor(
      cx: x,
      cy: c.mid,
      halfLength: hl,
      thickness: 0.03,
      angle0: c.rng.range(0, math.pi),
      spin: spin,
    ));
    end = x + hl + 0.03;
    x = end + c.t(0.85) + hl;
    dir = -dir;
  }
  return end;
}

double _doubleRotor(PatternCtx c) {
  final hl = c.h * 0.21;
  final spin = 2 * math.pi / c.t(c.byD(1.4, 1.1));
  final x = c.x + hl + 0.05;
  final a0 = c.rng.range(0, math.pi);
  c.chunk.hazards
    ..add(Rotor(cx: x, cy: c.top + c.h * 0.27, halfLength: hl, thickness: 0.028, angle0: a0, spin: spin))
    ..add(Rotor(cx: x + c.t(0.55), cy: c.bot - c.h * 0.27, halfLength: hl, thickness: 0.028, angle0: a0, spin: -spin));
  return x + c.t(0.55) + hl + 0.03;
}

double _spikeTunnel(PatternCtx c) => _alternator(
      c,
      gap: c.byD(0.6, 0.42),
      groups: 4 + c.rng.nextInt(3),
    );

double _zigzag(PatternCtx c) => _alternator(
      c,
      gap: c.byD(0.44, 0.33),
      groups: 5 + c.rng.nextInt(3),
      height: c.h * 0.3,
    );

double _mixer(PatternCtx c) {
  var end = _alternator(c, groups: 3, gap: c.byD(0.55, 0.42));
  final c2 = PatternCtx(
    rng: c.rng,
    chunk: c.chunk,
    x: end + c.t(0.55),
    speed: c.speed,
    difficulty: c.difficulty,
    top: c.top,
    bot: c.bot,
  );
  end = c.rng.chance(0.5) ? _laserGate(c2, gates: 1) : _movers(c2);
  return end;
}

/// A slab splits the corridor: one channel is clear, the other is packed
/// with spikes and double-value shards. The generator marks which.
double _riskGate(PatternCtx c) {
  const half = 0.022;
  final xa = c.x + c.t(0.45);
  final len = c.t(c.byD(2.3, 1.8));
  final xb = xa + len;
  final y = c.mid;
  c.chunk.platforms.add(Platform(x0: xa, x1: xb, y0: y - half, y1: y + half));
  c.chunk.hazards.add(Nose(x: xa, y: y, halfHeight: half + 0.03));

  final riskTop = c.rng.chance(0.5);
  c.chunk.riskTop = riskTop;
  c.chunk.riskX0 = xa;
  c.chunk.riskX1 = xb;
  final chTop = riskTop ? c.top : y + half;
  final chBot = riskTop ? y - half : c.bot;
  final chH = chBot - chTop;
  var onFloor = c.rng.chance(0.5);
  final count = 3 + (c.difficulty > 0.5 ? 1 : 0);
  final spacing = (len - c.t(0.6)) / count;
  for (var i = 0; i < count; i++) {
    c.spikes(xa + c.t(0.45) + i * spacing, 1, onFloor: onFloor, height: chH * 0.3, baseY: onFloor ? chBot : chTop);
    onFloor = !onFloor;
  }
  return xb + 0.05;
}

double _trail(PatternCtx c) => c.x + c.t(c.byD(2.0, 1.4));

// ------------------------------------------------------------------ registry

abstract final class PatternRegistry {
  static const breather = PatternDef(
    id: 'trail',
    name: 'Shard Trail',
    rating: 0,
    minReaction: 0.45,
    pools: {},
    build: _trail,
    shards: 10,
  );

  static const simplest = PatternDef(
    id: 'spike_row',
    name: 'Spike Row',
    rating: 1,
    minReaction: 0.42,
    pools: {Pool.normal, Pool.squeeze},
    build: _spikeRow,
    shards: 3,
  );

  static const riskGate = PatternDef(
    id: 'risk_gate',
    name: 'Risk Gate',
    rating: 3,
    minReaction: 0.3,
    pools: {},
    build: _riskGate,
    shards: 2,
  );

  static const List<PatternDef> all = [
    simplest,
    PatternDef(
      id: 'alternator',
      name: 'Alternator',
      rating: 2,
      minReaction: 0.34,
      pools: {Pool.normal, Pool.twist, Pool.squeeze, Pool.chase},
      build: _alternator,
      weight: 1.4,
    ),
    PatternDef(
      id: 'float_trap',
      name: 'Float Trap',
      rating: 3,
      minReaction: 0.32,
      pools: {Pool.normal, Pool.flux, Pool.squeeze},
      build: _floatTrap,
    ),
    PatternDef(
      id: 'narrow',
      name: 'Narrowing',
      rating: 3,
      minReaction: 0.32,
      pools: {Pool.normal},
      build: _narrow,
    ),
    PatternDef(
      id: 'laser_gate',
      name: 'Laser Gate',
      rating: 3,
      minReaction: 0.32,
      pools: {Pool.normal, Pool.prism, Pool.squeeze},
      build: _laserGate,
    ),
    PatternDef(
      id: 'movers',
      name: 'Sliders',
      rating: 4,
      minReaction: 0.3,
      pools: {Pool.normal, Pool.flux},
      build: _movers,
    ),
    PatternDef(
      id: 'rotor',
      name: 'Rotor',
      rating: 5,
      minReaction: 0.3,
      pools: {Pool.normal, Pool.prism, Pool.chase},
      build: _rotor,
    ),
    PatternDef(
      id: 'spike_tunnel',
      name: 'Spike Tunnel',
      rating: 5,
      minReaction: 0.27,
      pools: {Pool.normal, Pool.twist, Pool.chase},
      build: _spikeTunnel,
      shards: 5,
    ),
    PatternDef(
      id: 'laser_cascade',
      name: 'Laser Cascade',
      rating: 6,
      minReaction: 0.25,
      pools: {Pool.normal, Pool.prism, Pool.chase},
      build: _laserCascade,
    ),
    PatternDef(
      id: 'crusher',
      name: 'Crushers',
      rating: 6,
      minReaction: 0.25,
      pools: {Pool.normal, Pool.flux, Pool.chase},
      build: _crusher,
    ),
    PatternDef(
      id: 'zigzag',
      name: 'Zigzag',
      rating: 7,
      minReaction: 0.21,
      pools: {Pool.normal, Pool.twist, Pool.chase},
      build: _zigzag,
      shards: 5,
    ),
    PatternDef(
      id: 'double_rotor',
      name: 'Twin Rotors',
      rating: 8,
      minReaction: 0.24,
      pools: {Pool.normal, Pool.prism},
      build: _doubleRotor,
    ),
    PatternDef(
      id: 'mixer',
      name: 'Mixer',
      rating: 8,
      minReaction: 0.22,
      pools: {Pool.normal, Pool.chase},
      build: _mixer,
      shards: 5,
    ),
  ];

  static PatternDef byId(String id) {
    if (id == breather.id) return breather;
    if (id == riskGate.id) return riskGate;
    return all.firstWhere((p) => p.id == id, orElse: () => simplest);
  }
}
