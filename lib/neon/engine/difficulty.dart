import 'dart:math' as math;

import 'tuning.dart';

/// The difficulty curve. Everything is a function of distance travelled
/// and has a hard upper limit, so late runs get dense, not impossible.
abstract final class Difficulty {
  /// 0 at the start, about 0.16 after a minute, 0.6 at ~650 units, -> 1.
  static double level(double s) => 1 - math.exp(-math.max(0, s) / 700);

  /// Base speed (before chase boosts), capped at [Tune.maxSpeed].
  static double speed(double s) {
    final k = (math.max(0, s) / Tune.speedRampDistance).clamp(0.0, 1.0);
    return Tune.baseSpeed + (Tune.maxSpeed - Tune.baseSpeed) * math.pow(k, 0.8);
  }

  /// Hardest pattern rating allowed. Wave peaks get one extra step.
  static int maxRating(double d, {bool peak = false}) => math.min(9, 2 + (d * 7).floor() + (peak ? 1 : 0));

  /// Patterns demanding faster taps than this are held back.
  static double reactionFloor(double d) => 0.32 - 0.13 * d.clamp(0.0, 1.0);
}
