import 'dart:math' as math;

import 'generator.dart';
import 'hazards.dart';
import 'physics.dart';
import 'scoring.dart';
import 'tuning.dart';

enum NeonEventType {
  flip,
  land,
  shard,
  setComplete,
  nearMiss,
  chainBroken,
  dashReady,
  dashStart,
  dashPierce,
  dashEnd,
  breakWarn,
  breakStart,
  breakEnd,
  chaseWarn,
  chaseStart,
  escape,
  riskClear,
  milestone,
  death,
}

/// Something that happened this frame, for sound, particles and the HUD.
class NeonEvent {
  const NeonEvent(this.type, {this.x = 0, this.y = 0, this.value = 0, this.label});

  final NeonEventType type;
  final double x, y;
  final int value;
  final String? label;
}

class RunStats {
  double distance = 0;
  int shards = 0;
  int nearMisses = 0;
  int flips = 0;
  int dashes = 0;
  int pierces = 0;
  int breaks = 0;
  int escapes = 0;
  int riskClears = 0;
  int perfectSets = 0;
}

/// What a finished run reports to progression.
class RunSummary {
  const RunSummary({
    required this.score,
    required this.distance,
    required this.shards,
    required this.bestChain,
    required this.bestMultiplier,
    required this.nearMisses,
    required this.dashes,
    required this.breaks,
    required this.escapes,
    required this.riskClears,
    required this.perfectSets,
    required this.daily,
    required this.seed,
    required this.cause,
  });

  final int score;
  final int distance;
  final int shards;
  final int bestChain;
  final double bestMultiplier;
  final int nearMisses;
  final int dashes;
  final int breaks;
  final int escapes;
  final int riskClears;
  final int perfectSets;
  final bool daily;
  final int seed;
  final String cause;
}

/// The whole game simulation. Pure Dart: no Flutter, no Flame, so it runs
/// in tests and the renderer only reads from it.
///
/// It advances in fixed steps of [Tune.dt] (the same steps the validator
/// used to prove every chunk survivable).
class NeonWorld {
  NeonWorld({required this.seed, this.daily = false}) {
    reset();
  }

  final int seed;
  final bool daily;

  late LevelGenerator generator;
  final List<Chunk> chunks = [];
  final ScoreKeeper score = ScoreKeeper();
  late RunStats stats;
  late OrbState orb;

  /// Distance travelled = the orb's x.
  double s = 0;
  double time = 0;

  bool alive = true;
  Hazard? killer;
  String cause = '';
  bool grounded = true;

  int dashMeter = 0;
  bool dashing = false;
  double dashTime = 0;
  int dashPierced = 0;

  BreakVariant? activeBreak;
  bool chaseActive = false;
  double chaseStartedAt = 0;

  /// Freeze frames on big moments (consumed by [update]).
  double hitStop = 0;

  final List<NeonEvent> events = [];

  double _acc = 0;
  bool _flipQueued = false;
  double _nextMilestone = Tune.milestoneEvery;

  void reset() {
    generator = LevelGenerator(seed);
    chunks.clear();
    score.reset();
    stats = RunStats();
    s = 0;
    time = 0;
    alive = true;
    killer = null;
    cause = '';
    dashMeter = 0;
    dashing = false;
    dashTime = 0;
    dashPierced = 0;
    activeBreak = null;
    chaseActive = false;
    hitStop = 0;
    events.clear();
    _acc = 0;
    _flipQueued = false;
    _nextMilestone = Tune.milestoneEvery;
    _ensureChunks();
    final c = chunks.first;
    orb = OrbState(Physics.restY(c, 0, 1), 0, 1);
    grounded = true;
  }

  // ------------------------------------------------------------ input

  void flip() {
    if (alive) _flipQueued = true;
  }

  bool get dashReady => alive && !dashing && dashMeter >= Tune.dashCharge;

  double get dashCharge => (dashMeter / Tune.dashCharge).clamp(0.0, 1.0);

  bool dash() {
    if (!dashReady) return false;
    dashing = true;
    dashTime = Tune.dashDuration;
    dashPierced = 0;
    dashMeter = 0;
    stats.dashes++;
    events.add(NeonEvent(NeonEventType.dashStart, x: s, y: orb.y));
    return true;
  }

  // ------------------------------------------------------------ queries

  Chunk chunkAt(double x) {
    for (final c in chunks) {
      if (c.contains(x)) return c;
    }
    return chunks.last;
  }

  Chunk get current => chunkAt(s);
  double get speed => current.speed;

  /// Fraction of a step since the last update (for smooth rendering).
  double get alpha => (_acc / Tune.dt).clamp(0.0, 1.0);

  // ------------------------------------------------------------ update

  void update(double frameDt) {
    if (!alive) return;
    if (hitStop > 0) {
      hitStop -= frameDt;
      return;
    }
    _acc += math.min(frameDt, 0.1);
    var steps = 0;
    while (_acc >= Tune.dt && alive && steps < 14) {
      _acc -= Tune.dt;
      _step();
      steps++;
    }
    if (steps == 14) _acc = 0; // fell far behind (debugger, slow device)
  }

  void _ensureChunks() {
    while (chunks.isEmpty || chunks.last.x1 < s + 9) {
      chunks.add(generator.next());
    }
    while (chunks.length > 2 && chunks.first.x1 < s - 3) {
      chunks.removeAt(0);
    }
  }

  void _step() {
    _ensureChunks();
    final before = chunkAt(s);
    if (_flipQueued) {
      _flipQueued = false;
      orb.g = -orb.g;
      stats.flips++;
      events.add(NeonEvent(NeonEventType.flip, x: s, y: orb.y, value: orb.g));
    }

    final v = before.speed;
    final ns = s + v * Tune.dt;
    final c = chunkAt(ns);
    if (!c.entered) {
      c.entered = true;
      _enter(c);
    }
    final ok = Physics.step(orb, c, ns);
    s = ns;
    time += Tune.dt;
    if (!ok) {
      _die(null, 'HIT THE WALL');
      return;
    }
    score.addDistance(v * Tune.dt);
    stats.distance = s;

    final nowGrounded = Physics.grounded(orb, c, s);
    if (nowGrounded && !grounded) events.add(NeonEvent(NeonEventType.land, x: s, y: orb.y, value: orb.g));
    grounded = nowGrounded;

    // Hazards.
    final h = Physics.hit(c, s, orb.y, Tune.hitRadius);
    if (h != null) {
      if (dashing && h.dashable) {
        h.pierced = true;
        dashPierced++;
        stats.pierces++;
        events.add(NeonEvent(NeonEventType.dashPierce, x: s, y: orb.y, value: dashPierced));
        if (dashPierced >= Tune.dashMaxPierce) _endDash();
      } else {
        _die(h, _causeOf(h));
        return;
      }
    }
    _nearMisses(c);
    _shards(c);
    _lookAhead();

    if (dashing) {
      dashTime -= Tune.dt;
      if (dashTime <= 0) _endDash();
    }
    if (score.tick(Tune.dt)) events.add(NeonEvent(NeonEventType.chainBroken, x: s, y: orb.y));
    if (s >= _nextMilestone) {
      events.add(NeonEvent(NeonEventType.milestone, x: s, y: orb.y, value: _nextMilestone.round()));
      _nextMilestone += Tune.milestoneEvery;
    }
  }

  void _enter(Chunk c) {
    switch (c.role) {
      case ChunkRole.breakIntro:
        activeBreak = c.variant;
        events.add(NeonEvent(NeonEventType.breakStart, x: s, label: c.variant?.title));
      case ChunkRole.breakOutro:
        if (activeBreak != null) {
          stats.breaks++;
          events.add(NeonEvent(NeonEventType.breakEnd, x: s));
        }
        activeBreak = null;
      case ChunkRole.chaseIntro:
        chaseActive = true;
        chaseStartedAt = s;
        events.add(NeonEvent(NeonEventType.chaseStart, x: s));
      case ChunkRole.escape:
        if (chaseActive) {
          chaseActive = false;
          stats.escapes++;
          final pts = score.escape();
          events.add(NeonEvent(NeonEventType.escape, x: s, y: orb.y, value: pts));
        }
      case ChunkRole.normal:
      case ChunkRole.breather:
      case ChunkRole.breakBody:
      case ChunkRole.chaseBody:
        break;
    }
  }

  /// Warn about Reality Breaks and Chases a couple of seconds early.
  void _lookAhead() {
    for (final c in chunks) {
      if (c.warned || c.x0 < s) continue;
      if (c.x0 - s > c.speed * 2.2) break;
      c.warned = true;
      if (c.role == ChunkRole.breakIntro) {
        events.add(NeonEvent(NeonEventType.breakWarn, x: c.x0, label: c.variant?.title));
      } else if (c.role == ChunkRole.chaseIntro) {
        events.add(NeonEvent(NeonEventType.chaseWarn, x: c.x0));
      }
    }
  }

  void _nearMisses(Chunk c) {
    const r = Tune.orbRadius;
    for (final h in c.hazards) {
      if (h.left - 0.1 > s + r) break;
      if (h.passed || h.pierced) continue;
      if (h.right + 0.1 < s - r) {
        h.passed = true;
        if (h.minClear < Tune.nearMiss) {
          stats.nearMisses++;
          final pts = score.nearMiss();
          events.add(NeonEvent(NeonEventType.nearMiss, x: s, y: orb.y, value: pts));
        }
        continue;
      }
      final d = h.distance(s, orb.y, s) - Tune.hitRadius;
      if (d < h.minClear) h.minClear = d;
    }
  }

  void _shards(Chunk c) {
    const reach = Tune.shardPickup + Tune.orbRadius;
    for (final sh in c.shards) {
      if (sh.collected) continue;
      final dx = sh.x - s;
      if (dx > reach) break;
      if (dx < -reach) continue;
      final dy = sh.y - orb.y;
      if (dx * dx + dy * dy > reach * reach) continue;
      sh.collected = true;
      stats.shards++;
      final wasReady = dashMeter >= Tune.dashCharge;
      dashMeter = math.min(Tune.dashCharge, dashMeter + 1);
      final pts = score.shard(risk: sh.risk, doubled: activeBreak != null);
      events.add(NeonEvent(NeonEventType.shard, x: sh.x, y: sh.y, value: pts, label: sh.risk ? 'risk' : null));
      if (!wasReady && dashMeter >= Tune.dashCharge && !dashing) {
        events.add(NeonEvent(NeonEventType.dashReady, x: s, y: orb.y));
      }
      if (c.shards.every((o) => o.group != sh.group || o.collected)) {
        final groupSize = c.shards.where((o) => o.group == sh.group).length;
        if (sh.risk) {
          stats.riskClears++;
          events.add(NeonEvent(NeonEventType.riskClear, x: s, y: orb.y, value: groupSize));
        }
        if (groupSize >= 3) {
          stats.perfectSets++;
          final bonus = score.perfectSet();
          events.add(NeonEvent(NeonEventType.setComplete, x: s, y: orb.y, value: bonus));
        }
      }
    }
  }

  void _endDash() {
    if (!dashing) return;
    dashing = false;
    dashTime = 0;
    events.add(NeonEvent(NeonEventType.dashEnd, x: s, y: orb.y));
  }

  void _die(Hazard? h, String why) {
    if (!alive) return;
    alive = false;
    killer = h;
    cause = why;
    _flipQueued = false;
    events.add(NeonEvent(NeonEventType.death, x: s, y: orb.y, label: why));
  }

  static String _causeOf(Hazard h) => switch (h.kind) {
        HazardKind.spike => 'SPIKED',
        HazardKind.block => 'SMASHED',
        HazardKind.laser => 'LASERED',
        HazardKind.mover => 'CRUSHED',
        HazardKind.rotor => 'SLICED',
        HazardKind.nose => 'SPLIT',
      };

  RunSummary summary() => RunSummary(
        score: score.points,
        distance: s.floor(),
        shards: stats.shards,
        bestChain: score.bestChain,
        bestMultiplier: score.bestMultiplier,
        nearMisses: stats.nearMisses,
        dashes: stats.dashes,
        breaks: stats.breaks,
        escapes: stats.escapes,
        riskClears: stats.riskClears,
        perfectSets: stats.perfectSets,
        daily: daily,
        seed: seed,
        cause: cause,
      );
}
