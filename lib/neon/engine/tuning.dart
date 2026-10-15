/// Every gameplay number in one place.
///
/// World units: the corridor is 1 unit tall. x grows forward (the orb's x
/// equals the distance travelled), y goes from 0 (ceiling) to 1 (floor).
abstract final class Tune {
  /// Fixed simulation step. The game and the route validator use the same
  /// step, so "the validator found a route" means the game allows it.
  static const double dt = 1 / 120;

  /// Steps between possible flip decisions in the validator (60 Hz input).
  static const int decisionEvery = 2;

  static const double orbRadius = 0.062;

  /// Hazards use a slightly smaller hitbox than the orb looks: grazing a
  /// spike's glow should be a near miss, not a death.
  static const double hitRadius = 0.052;

  /// Extra clearance the validator demands, so routes it accepts are not
  /// pixel-perfect.
  static const double validatorMargin = 0.012;

  static const double gravity = 48;
  static const double maxFall = 7.5;

  /// Clearance (beyond the hitbox) that still counts as a near miss.
  static const double nearMiss = 0.07;

  static const double shardPickup = 0.075;

  // Speed (units per second).
  static const double baseSpeed = 1.7;
  static const double maxSpeed = 3.0;
  static const double speedRampDistance = 1600;
  static const double chaseBoost = 1.12;

  // Pulse Dash.
  static const int dashCharge = 12;
  static const double dashDuration = 1.0;
  static const int dashMaxPierce = 3;

  // Perfect Chain.
  static const double chainWindow = 4.0;
  static const int maxChain = 20;
  static const double perChain = 0.2;

  // Score.
  static const double scorePerUnit = 10;
  static const double nearMissScore = 25;
  static const double shardScore = 5;
  static const double perfectPatternScore = 40;
  static const double escapeScore = 300;

  // Events (distances in units).
  static const double firstBreakAt = 90;
  static const double breakEvery = 120;
  static const double breakLength = 26;
  static const List<double> chaseAt = [320, 760, 1300];
  static const double chaseEveryAfter = 600;
  static const double chaseLength = 22;

  static const double milestoneEvery = 250;
}
