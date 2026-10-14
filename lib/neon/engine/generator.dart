import 'dart:math' as math;

import 'difficulty.dart';
import 'hazards.dart';
import 'patterns.dart';
import 'rng.dart';
import 'tuning.dart';
import 'validator.dart';

class GenStats {
  int chunks = 0;
  int validations = 0;
  int retries = 0;
  int fallbacks = 0;
  int peakStates = 0;
}

enum _Phase { normal, breakTime, chase }

/// Endless, seeded corridor generator.
///
/// It strings handcrafted patterns together along a tension curve: waves of
/// rising difficulty separated by shard-trail breathers, with Reality
/// Breaks and Chase sequences at set distances. Every chunk is checked by
/// [RouteValidator] before it is handed out; a pattern that fails is
/// rebuilt (up to three times) and finally replaced by a simple one.
class LevelGenerator {
  LevelGenerator(this.seed) : _rng = NeonRng(seed);

  final int seed;
  final NeonRng _rng;
  final GenStats stats = GenStats();

  double cursor = 0;
  double _top = 0, _bot = 1;

  _Phase _phase = _Phase.normal;
  double _phaseEnd = 0;
  BreakVariant? _variant;
  double _nextBreak = Tune.firstBreakAt;
  int _chaseIndex = 0;
  double _nextChase = Tune.chaseAt.first;

  int _intro = 0;
  int _waveStep = 0;
  int _waveLen = 4;
  String? _lastId;

  static const double _tail = 0.3;

  Chunk next() {
    final c = _next();
    cursor = c.x1;
    stats.chunks++;
    return c;
  }

  Chunk _next() {
    // A gentle, fixed opening: collect, then learn to flip both ways.
    if (_intro < 3) {
      final i = _intro++;
      if (i == 0) return _breather(lead: 2.2);
      return _patternChunk(PatternRegistry.simplest, forceSide: i == 1 ? 1 : -1);
    }

    switch (_phase) {
      case _Phase.chase:
        if (cursor >= _phaseEnd) {
          _phase = _Phase.normal;
          _chaseIndex++;
          _nextChase = _chaseIndex < Tune.chaseAt.length
              ? Tune.chaseAt[_chaseIndex]
              : cursor + Tune.chaseEveryAfter;
          _nextBreak = math.max(_nextBreak, cursor + 35);
          _waveStep = 0;
          return _breather(role: ChunkRole.escape);
        }
        return _patternChunk(_choose(Pool.chase, peak: true), role: ChunkRole.chaseBody, dBoost: 0.15, speedMul: Tune.chaseBoost);
      case _Phase.breakTime:
        if (cursor >= _phaseEnd) {
          _phase = _Phase.normal;
          _nextBreak = cursor + Tune.breakEvery;
          _waveStep = 0;
          return _breakEdge(intro: false);
        }
        return _patternChunk(_choose(_poolFor(_variant!)), role: ChunkRole.breakBody);
      case _Phase.normal:
        if (cursor >= _nextChase) {
          _phase = _Phase.chase;
          final intro = _empty(ChunkRole.chaseIntro, Difficulty.speed(cursor) * 1.6);
          _phaseEnd = intro.x1 + Tune.chaseLength;
          return intro;
        }
        if (cursor >= _nextBreak) {
          _phase = _Phase.breakTime;
          _variant = BreakVariant.values[_rng.nextInt(BreakVariant.values.length)];
          final intro = _breakEdge(intro: true);
          _phaseEnd = intro.x1 + Tune.breakLength;
          return intro;
        }
        if (_waveStep >= _waveLen) {
          _waveStep = 0;
          _waveLen = 3 + _rng.nextInt(3);
          return _breather();
        }
        final peak = _waveStep == _waveLen - 1;
        _waveStep++;
        final d = Difficulty.level(cursor);
        if (d > 0.12 && _lastId != PatternRegistry.riskGate.id && _rng.chance(0.15)) {
          return _riskGateChunk();
        }
        return _patternChunk(_choose(Pool.normal, peak: peak));
    }
  }

  static Pool _poolFor(BreakVariant v) => switch (v) {
        BreakVariant.prism => Pool.prism,
        BreakVariant.flux => Pool.flux,
        BreakVariant.twist => Pool.twist,
        BreakVariant.squeeze => Pool.squeeze,
      };

  PatternDef _choose(Pool pool, {bool peak = false}) {
    final d = Difficulty.level(cursor);
    final maxRating = Difficulty.maxRating(d, peak: peak) + (pool == Pool.normal ? 0 : 1);
    final floor = Difficulty.reactionFloor(d);
    final options = PatternRegistry.all
        .where((p) => p.pools.contains(pool) && p.rating <= maxRating && p.minReaction >= floor - 1e-9)
        .toList();
    if (options.isEmpty) return PatternRegistry.simplest;
    final weights = [
      for (final p in options) p.weight * (0.5 + p.rating / maxRating) * (p.id == _lastId ? 0.25 : 1),
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = _rng.next() * total;
    for (var i = 0; i < options.length; i++) {
      r -= weights[i];
      if (r <= 0) return options[i];
    }
    return options.last;
  }

  Chunk _newChunk(PatternDef def, double v, {ChunkRole role = ChunkRole.normal, double? exitTop, double? exitBot}) =>
      Chunk(
        x0: cursor,
        x1: cursor,
        speed: v,
        patternId: def.id,
        rating: def.rating,
        minReaction: def.minReaction,
        entryTop: _top,
        entryBot: _bot,
        exitTop: exitTop ?? _top,
        exitBot: exitBot ?? _bot,
        role: role,
        variant: _phase == _Phase.breakTime ? _variant : null,
      );

  Chunk _patternChunk(
    PatternDef def, {
    ChunkRole role = ChunkRole.normal,
    double dBoost = 0,
    double speedMul = 1,
    int? forceSide,
  }) {
    final v = Difficulty.speed(cursor) * speedMul;
    final d = (Difficulty.level(cursor) + dBoost).clamp(0.0, 1.0);
    for (var attempt = 0; attempt < 3; attempt++) {
      final c = _newChunk(def, v, role: role);
      final ctx = PatternCtx(
        rng: _rng.fork(),
        chunk: c,
        x: cursor + v * 0.45,
        speed: v,
        difficulty: d,
        top: _top,
        bot: _bot,
      );
      final end = forceSide != null ? ctx.spikes(ctx.x, 3, onFloor: forceSide > 0) : def.build(ctx);
      c.x1 = end + _tail;
      if (_finish(c, def)) {
        _lastId = def.id;
        return c;
      }
      stats.retries++;
    }
    stats.fallbacks++;
    final fb = PatternRegistry.simplest;
    final c = _newChunk(fb, v, role: role);
    final ctx = PatternCtx(rng: _rng.fork(), chunk: c, x: cursor + v * 0.6, speed: v, difficulty: 0, top: _top, bot: _bot);
    c.x1 = ctx.spikes(ctx.x, 2, onFloor: _rng.chance(0.5)) + _tail;
    c.fallback = true;
    if (!_finish(c, fb)) {
      // Cannot happen with a 2-spike row, but never hand out an unproven
      // chunk: an empty corridor is always survivable.
      c.hazards.clear();
      c.validated = true;
    }
    _lastId = fb.id;
    return c;
  }

  /// Sorts, validates and decorates a built chunk.
  bool _finish(Chunk c, PatternDef def, {bool Function(RoutePath)? pathFilter}) {
    c.hazards.sort((a, b) => a.left.compareTo(b.left));
    c.bounds.sort((a, b) => a.x0.compareTo(b.x0));
    stats.validations++;
    final res = RouteValidator.validate(c, minGap: def.minReaction, rng: _rng.fork(), pathFilter: pathFilter);
    stats.peakStates = math.max(stats.peakStates, res.peakStates);
    if (!res.ok) return false;
    c.validated = true;
    final path = res.path;
    if (path != null && def.shards > 0) {
      _shardsAlong(c, path, def.shards, group: 0, from: c.x0 + c.speed * 0.3, to: c.x1 - _tail);
    }
    return true;
  }

  Chunk _riskGateChunk() {
    final def = PatternRegistry.riskGate;
    final v = Difficulty.speed(cursor);
    final d = Difficulty.level(cursor);
    for (var attempt = 0; attempt < 3; attempt++) {
      final c = _newChunk(def, v);
      final ctx = PatternCtx(rng: _rng.fork(), chunk: c, x: cursor + v * 0.45, speed: v, difficulty: d, top: _top, bot: _bot);
      c.x1 = def.build(ctx) + _tail;
      final mid = (_top + _bot) / 2;
      final riskTop = c.riskTop!;
      bool throughRisk(RoutePath p) {
        for (var k = 0; k < p.s.length; k++) {
          final s = p.s[k];
          if (s < c.riskX0 + 0.1 || s > c.riskX1 - 0.1) continue;
          if (riskTop ? p.y[k] > mid : p.y[k] < mid) return false;
        }
        return true;
      }

      c.hazards.sort((a, b) => a.left.compareTo(b.left));
      stats.validations++;
      final res = RouteValidator.validate(c, minGap: def.minReaction, rng: _rng.fork(), pathFilter: throughRisk);
      stats.peakStates = math.max(stats.peakStates, res.peakStates);
      if (!res.ok) {
        stats.retries++;
        continue;
      }
      c.validated = true;
      // Two easy shards in the safe channel, against its outer wall...
      final safeY = riskTop ? _bot - 0.062 : _top + 0.062;
      for (var i = 0; i < 2; i++) {
        c.shards.add(Shard(x: c.riskX0 + (c.riskX1 - c.riskX0) * (0.35 + 0.3 * i), y: safeY, group: 0));
      }
      // ...and a rich trail along a proven route through the risky one.
      final path = res.path;
      if (path != null) {
        _shardsAlong(c, path, 7, group: 1, risk: true, from: c.riskX0 + 0.1, to: c.riskX1 - 0.05);
      }
      c.riskShards = c.shards.where((s) => s.risk).length;
      _lastId = def.id;
      return c;
    }
    stats.fallbacks++;
    return _patternChunk(PatternRegistry.simplest);
  }

  void _shardsAlong(Chunk c, RoutePath p, int count, {required int group, bool risk = false, required double from, required double to}) {
    if (to <= from || count <= 0) return;
    final spacing = math.max(0.16, (to - from) / (count + 0.5));
    var nextX = from + spacing * 0.5;
    var placed = 0;
    for (var k = 0; k < p.s.length && placed < count; k++) {
      final s = p.s[k];
      if (s < nextX) continue;
      if (s > to) break;
      final y = p.y[k];
      var clear = true;
      for (final h in c.hazards) {
        if (h.left > s + 0.2) break;
        if (h.right < s - 0.2) continue;
        if (h.distance(s, y, s) < 0.09) {
          clear = false;
          break;
        }
      }
      if (!clear) continue;
      c.shards.add(Shard(x: s, y: y, group: group, risk: risk));
      placed++;
      nextX = s + spacing;
    }
  }

  Chunk _breather({double lead = 0.45, ChunkRole role = ChunkRole.breather}) {
    final v = Difficulty.speed(cursor);
    final def = PatternRegistry.breather;
    final c = _newChunk(def, v, role: role);
    final ctx = PatternCtx(
      rng: _rng.fork(),
      chunk: c,
      x: cursor + v * lead,
      speed: v,
      difficulty: Difficulty.level(cursor),
      top: _top,
      bot: _bot,
    );
    c.x1 = def.build(ctx) + _tail;
    _finish(c, def);
    _lastId = def.id;
    return c;
  }

  Chunk _empty(ChunkRole role, double length) {
    final v = Difficulty.speed(cursor);
    final c = _newChunk(PatternRegistry.breather, v, role: role)..x1 = cursor + length;
    c.validated = true;
    return c;
  }

  /// Entering or leaving a Reality Break. SQUEEZE ramps the walls in/out.
  Chunk _breakEdge({required bool intro}) {
    final v = Difficulty.speed(cursor);
    final squeeze = _variant == BreakVariant.squeeze;
    final toTop = intro && squeeze ? 0.12 : 0.0;
    final toBot = intro && squeeze ? 0.88 : 1.0;
    final c = _newChunk(PatternRegistry.breather, v,
        role: intro ? ChunkRole.breakIntro : ChunkRole.breakOutro, exitTop: toTop, exitBot: toBot);
    final len = v * 1.5;
    c.x1 = cursor + len;
    if (toTop != _top || toBot != _bot) {
      c.bounds.add(BoundSeg(
        x0: cursor + v * 0.35,
        x1: cursor + v * 1.0,
        top0: _top,
        top1: toTop,
        bot0: _bot,
        bot1: toBot,
      ));
    }
    _top = toTop;
    _bot = toBot;
    c.validated = true;
    if (!intro) _variant = null;
    return c;
  }
}
