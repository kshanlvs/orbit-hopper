/// All tuning knobs in one place. [level] is the planet index.
/// Difficulty ramps smoothly from level 0 to level 80, then stays at max.
class Difficulty {
  const Difficulty(this.level);

  final int level;

  double get t => (level / 80).clamp(0.0, 1.0).toDouble();

  double _lerp(double a, double b) => a + (b - a) * t;

  /// Vertical distance between consecutive planets.
  double get minGap => _lerp(165, 215);
  double get maxGap => _lerp(225, 290);

  /// Planet body size.
  double get minRadius => _lerp(28, 16);
  double get maxRadius => _lerp(40, 28);

  /// Linear speed (px/s) of the comet while orbiting.
  double get orbitSpeed => _lerp(200, 300);

  /// Linear speed (px/s) after launch.
  double get launchSpeed => _lerp(560, 760);

  /// Seconds before a planet collapses under you. First planets are safe.
  double get stability => level < 3 ? double.infinity : _lerp(7.5, 3.2);

  double get moonChance => level < 6 ? 0.0 : _lerp(0.3, 0.6);
  double get driftChance => level < 9 ? 0.0 : _lerp(0.25, 0.5);
  double get moonSpeedMin => _lerp(0.8, 1.3);
  double get moonSpeedMax => _lerp(1.4, 2.4);
}
