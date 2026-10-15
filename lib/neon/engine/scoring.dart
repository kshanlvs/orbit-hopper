import 'dart:math' as math;

import 'tuning.dart';

/// Score, Perfect Chain and multiplier.
///
/// The chain grows on near misses, perfectly collected shard sets and
/// escaped chases. Any shard refreshes the chain timer; if nothing good
/// happens for [Tune.chainWindow] seconds the chain breaks. The multiplier
/// scales everything, including distance, so keeping a chain alive is the
/// heart of a high score.
class ScoreKeeper {
  double score = 0;
  int chain = 0;
  int bestChain = 0;
  double chainTimer = 0;

  static double multiplierFor(int chain) => 1 + math.min(chain, Tune.maxChain) * Tune.perChain;

  double get multiplier => multiplierFor(chain);
  double get bestMultiplier => multiplierFor(bestChain);

  /// Share of the chain window left (for the HUD bar).
  double get chainLeft => chain == 0 ? 0 : (chainTimer / Tune.chainWindow).clamp(0.0, 1.0);

  int get points => score.floor();

  void addDistance(double units) {
    if (units > 0) score += units * Tune.scorePerUnit * multiplier;
  }

  /// Returns the points awarded.
  int nearMiss() {
    _grow();
    return _award(Tune.nearMissScore);
  }

  int shard({bool risk = false, bool doubled = false}) {
    chainTimer = math.max(chainTimer, chain > 0 ? Tune.chainWindow : 0);
    var base = Tune.shardScore * (risk ? 2 : 1) * (doubled ? 2 : 1);
    return _award(base);
  }

  int perfectSet() {
    _grow();
    return _award(Tune.perfectPatternScore);
  }

  int escape() {
    _grow();
    return _award(Tune.escapeScore);
  }

  /// Advances the chain timer. Returns true if the chain just broke.
  bool tick(double dt) {
    if (chain == 0) return false;
    chainTimer -= dt;
    if (chainTimer > 0) return false;
    chain = 0;
    chainTimer = 0;
    return true;
  }

  void _grow() {
    chain++;
    bestChain = math.max(bestChain, chain);
    chainTimer = Tune.chainWindow;
  }

  int _award(double base) {
    final pts = base * multiplier;
    score += pts;
    return pts.round();
  }

  void reset() {
    score = 0;
    chain = 0;
    bestChain = 0;
    chainTimer = 0;
  }
}
