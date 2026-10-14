import 'dart:math' as math;

import 'hazards.dart';
import 'tuning.dart';

/// The orb's vertical state. Its x is always the scroll distance.
class OrbState {
  OrbState(this.y, this.vy, this.g);

  double y;
  double vy;

  /// +1 = gravity pulls to the floor, -1 = to the ceiling.
  int g;

  OrbState copy() => OrbState(y, vy, g);
}

/// Shared by the game and the route validator, so they can never disagree.
abstract final class Physics {
  /// Resting y against the wall gravity points at.
  static double restY(Chunk c, double x, int g) => g > 0 ? c.bot(x) - Tune.orbRadius : c.top(x) + Tune.orbRadius;

  /// Advances [o] by one fixed step; [s] is the orb's x after the step.
  /// Returns false when the orb is crushed or hits a slab side-on.
  static bool step(OrbState o, Chunk c, double s) {
    const r = Tune.orbRadius;
    var vy = (o.vy + o.g * Tune.gravity * Tune.dt).clamp(-Tune.maxFall, Tune.maxFall).toDouble();

    // Walls under the whole orb (ramps are gentle, so the two edges suffice).
    var top = math.max(c.top(s - r * 0.6), c.top(s + r * 0.6));
    var bot = math.min(c.bot(s - r * 0.6), c.bot(s + r * 0.6));

    for (final p in c.platforms) {
      if (s + r <= p.x0 || s - r >= p.x1) continue;
      if (o.y + r <= p.y0 + 1e-6) {
        bot = math.min(bot, p.y0);
      } else if (o.y - r >= p.y1 - 1e-6) {
        top = math.max(top, p.y1);
      } else {
        return false; // flew into the slab's front edge
      }
    }
    if (bot - top < 2 * r - 1e-6) return false;

    var y = o.y + vy * Tune.dt;
    if (y + r >= bot) {
      y = bot - r;
      if (vy > 0) vy = 0;
    }
    if (y - r <= top) {
      y = top + r;
      if (vy < 0) vy = 0;
    }
    o
      ..y = y
      ..vy = vy;
    return true;
  }

  /// First live hazard within [radius] of the orb at (s, y), or null.
  static Hazard? hit(Chunk c, double s, double y, double radius) {
    for (final h in c.hazards) {
      if (h.left > s + radius) break; // hazards are sorted by left edge
      if (h.right < s - radius || h.pierced) continue;
      if (h.distance(s, y, s) < radius) return h;
    }
    return null;
  }

  /// Is the orb touching the wall gravity points at?
  static bool grounded(OrbState o, Chunk c, double s) {
    const r = Tune.orbRadius;
    if (o.g > 0) {
      var bot = c.bot(s);
      for (final p in c.platforms) {
        if (s + r > p.x0 && s - r < p.x1 && o.y + r <= p.y0 + 1e-6) bot = math.min(bot, p.y0);
      }
      return o.y + r >= bot - 1e-4;
    }
    var top = c.top(s);
    for (final p in c.platforms) {
      if (s + r > p.x0 && s - r < p.x1 && o.y - r >= p.y1 - 1e-6) top = math.max(top, p.y1);
    }
    return o.y - r <= top + 1e-4;
  }
}
