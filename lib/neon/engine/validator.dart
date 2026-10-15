import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'hazards.dart';
import 'physics.dart';
import 'rng.dart';
import 'tuning.dart';

/// A route through a chunk: the orb's y at each simulation step.
class RoutePath {
  RoutePath(this.s, this.y, this.flips);

  final List<double> s;
  final List<double> y;

  /// Step indices where the route flips gravity.
  final List<int> flips;
}

class ValidationResult {
  const ValidationResult({required this.ok, this.path, this.peakStates = 0, this.failSide});

  final bool ok;

  /// One surviving route from a floor start (for placing shards).
  final RoutePath? path;

  /// Largest frontier seen; a cost measure for tuning.
  final int peakStates;

  /// +1 floor / -1 ceiling start that had no route.
  final int? failSide;
}

/// Proves a chunk can be survived before the player ever sees it.
///
/// It runs the real physics forward from a resting orb on the floor and on
/// the ceiling, trying "flip" or "don't flip" at every input frame, with
/// taps at least [minGap] seconds apart (the pattern's reaction-time
/// requirement). Equivalent states are merged, so this is a breadth-first
/// search over everything a player could do. Hazards are checked with an
/// enlarged hitbox, so accepted routes always have some slack.
abstract final class RouteValidator {
  static ValidationResult validate(
    Chunk c, {
    required double minGap,
    NeonRng? rng,
    bool Function(RoutePath path)? pathFilter,
    int maxStates = 1600,
  }) {
    var peak = 0;
    RoutePath? path;
    for (final side in const [1, -1]) {
      final start = OrbState(Physics.restY(c, c.x0, side), 0, side);
      final r = _run(c, start, c.x0, minGap, rng, side == 1, pathFilter, maxStates);
      peak = math.max(peak, r.$2);
      if (!r.$1) return ValidationResult(ok: false, peakStates: peak, failSide: side);
      if (side == 1) path = r.$3;
    }
    return ValidationResult(ok: true, path: path, peakStates: peak);
  }

  /// A route from an exact orb state at [startS] to the end of [c], or
  /// null if there is none. Used by the test bot and the menu demo.
  static RoutePath? plan(Chunk c, OrbState start, double startS, {double minGap = 0.12, NeonRng? rng}) {
    final r = _run(c, start, startS, minGap, rng, true, null, 1600);
    return r.$1 ? r.$3 : null;
  }

  static int _key(double y, double vy, int g) =>
      (((y * 360).round() + 400) * 512 + ((vy * 6).round() + 256)) * 2 + (g > 0 ? 1 : 0);

  static (bool, int, RoutePath?) _run(
    Chunk c,
    OrbState start,
    double startS,
    double minGap,
    NeonRng? rng,
    bool wantPath,
    bool Function(RoutePath)? filter,
    int maxStates,
  ) {
    final v = c.speed;
    final steps = math.max(1, ((c.x1 - startS) / (v * Tune.dt)).ceil());
    const radius = Tune.hitRadius + Tune.validatorMargin;
    final gapSteps = (minGap / Tune.dt).ceil();

    var ys = Float64List(1)..[0] = start.y;
    var vys = Float64List(1)..[0] = start.vy;
    var gs = Int8List(1)..[0] = start.g;
    var cds = Int32List(1); // steps until another flip is allowed
    var n = 1;
    var peak = 1;

    // History for path extraction.
    final parents = <Int32List>[];
    final layerY = <Float32List>[];
    final layerFlip = <Uint8List>[];

    final probe = OrbState(0, 0, 1);
    final index = HashMap<int, int>();

    for (var k = 0; k < steps; k++) {
      final s = startS + (k + 1) * v * Tune.dt;
      final decide = k % Tune.decisionEvery == 0;
      final cap = n * 2;
      final ny = Float64List(cap), nvy = Float64List(cap), ncd = Int32List(cap);
      final ng = Int8List(cap);
      final par = Int32List(cap);
      final flip = Uint8List(cap);
      var m = 0;
      index.clear();

      for (var i = 0; i < n; i++) {
        for (var a = 0; a < 2; a++) {
          final flipNow = a == 1;
          if (flipNow && !(decide && cds[i] <= 0)) continue;
          probe
            ..y = ys[i]
            ..vy = vys[i]
            ..g = flipNow ? -gs[i] : gs[i];
          if (!Physics.step(probe, c, s)) continue;
          if (Physics.hit(c, s, probe.y, radius) != null) continue;
          final cd = flipNow ? gapSteps : math.max(0, cds[i] - 1);
          final key = _key(probe.y, probe.vy, probe.g);
          final at = index[key];
          if (at != null) {
            // Keep the state with the most freedom (shortest tap cooldown).
            // Replace the whole state, not just its parent, so every stored
            // state is exactly what its recorded parent + action produce:
            // extracted routes are then exact replays of the real physics.
            if (cd < ncd[at]) {
              ny[at] = probe.y;
              nvy[at] = probe.vy;
              ng[at] = probe.g;
              ncd[at] = cd;
              par[at] = i;
              flip[at] = flipNow ? 1 : 0;
            }
            continue;
          }
          index[key] = m;
          ny[m] = probe.y;
          nvy[m] = probe.vy;
          ng[m] = probe.g;
          ncd[m] = cd;
          par[m] = i;
          flip[m] = flipNow ? 1 : 0;
          m++;
        }
      }
      if (m == 0) return (false, peak, null);

      // Too many distinct states: keep an even spread of them.
      if (m > maxStates) {
        final keep = Int32List(maxStates);
        for (var j = 0; j < maxStates; j++) {
          keep[j] = (j * m) ~/ maxStates;
        }
        final ky = Float64List(maxStates), kvy = Float64List(maxStates);
        final kcd = Int32List(maxStates), kpar = Int32List(maxStates);
        final kg = Int8List(maxStates);
        final kflip = Uint8List(maxStates);
        for (var j = 0; j < maxStates; j++) {
          final src = keep[j];
          ky[j] = ny[src];
          kvy[j] = nvy[src];
          kcd[j] = ncd[src];
          kpar[j] = par[src];
          kg[j] = ng[src];
          kflip[j] = flip[src];
        }
        ys = ky;
        vys = kvy;
        cds = kcd;
        gs = kg;
        m = maxStates;
        if (wantPath) {
          parents.add(kpar);
          layerY.add(Float32List.fromList(ky));
          layerFlip.add(kflip);
        }
      } else {
        ys = ny;
        vys = nvy;
        cds = ncd;
        gs = ng;
        if (wantPath) {
          parents.add(par);
          layerY.add(Float32List.fromList(ny.sublist(0, m)));
          layerFlip.add(flip);
        }
      }
      n = m;
      peak = math.max(peak, n);
    }

    if (!wantPath) return (true, peak, null);

    RoutePath build(int end) {
      final yOut = List<double>.filled(steps, 0);
      final sOut = List<double>.filled(steps, 0);
      final flips = <int>[];
      var idx = end;
      for (var k = steps - 1; k >= 0; k--) {
        yOut[k] = layerY[k][idx];
        sOut[k] = startS + (k + 1) * v * Tune.dt;
        if (layerFlip[k][idx] == 1) flips.add(k);
        idx = parents[k][idx];
      }
      return RoutePath(sOut, yOut, flips.reversed.toList());
    }

    final pick = rng ?? NeonRng(steps * 31 + n);
    RoutePath? chosen;
    for (var attempt = 0; attempt < 24; attempt++) {
      final p = build(pick.nextInt(n));
      if (filter == null || filter(p)) {
        chosen = p;
        break;
      }
    }
    return (true, peak, chosen);
  }
}
