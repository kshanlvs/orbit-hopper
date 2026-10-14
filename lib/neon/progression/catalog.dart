/// Everything you can unlock. Cosmetics only — nothing here changes the
/// orb's hitbox, speed or any rule of the game.
library;

class Dimension {
  const Dimension(this.id, this.name, this.unlockScore, this.tagline);

  final String id;
  final String name;

  /// Best score needed to enter this dimension.
  final int unlockScore;
  final String tagline;
}

class OrbSkin {
  const OrbSkin(this.id, this.name, this.price);

  final String id;
  final String name;
  final int price;
}

class TrailStyle {
  const TrailStyle(this.id, this.name, this.price);

  final String id;
  final String name;
  final int price;
}

class Achievement {
  const Achievement(this.id, this.title, this.description, this.reward);

  final String id;
  final String title;
  final String description;

  /// Energy awarded once, when first earned.
  final int reward;
}

abstract final class NeonCatalog {
  static const dimensions = [
    Dimension('core', 'Neon Core', 0, 'Where every shift begins.'),
    Dimension('sunset', 'Synth Sunset', 1500, 'A sun that never sets.'),
    Dimension('toxic', 'Toxic Grid', 3500, 'Do not touch the walls.'),
    Dimension('ice', 'Cryo Field', 6000, 'Frozen light, sharp edges.'),
    Dimension('inferno', 'Inferno', 10000, 'The corridor is burning.'),
    Dimension('void', 'The Void', 15000, 'Nothing but you and the line.'),
  ];

  static const skins = [
    OrbSkin('pulse', 'Pulse', 0),
    OrbSkin('nova', 'Nova', 150),
    OrbSkin('plasma', 'Plasma', 250),
    OrbSkin('venom', 'Venom', 400),
    OrbSkin('ghost', 'Ghost', 600),
    OrbSkin('prism', 'Prism', 1200),
  ];

  static const trails = [
    TrailStyle('streak', 'Streak', 0),
    TrailStyle('dots', 'Dots', 100),
    TrailStyle('ribbon', 'Ribbon', 300),
    TrailStyle('sparks', 'Sparks', 500),
    TrailStyle('echo', 'Echo', 800),
  ];

  static const achievements = [
    Achievement('first_run', 'First Shift', 'Finish your first run.', 10),
    Achievement('score_1000', 'Warming Up', 'Score 1,000 in one run.', 20),
    Achievement('score_5000', 'Neon Veteran', 'Score 5,000 in one run.', 50),
    Achievement('score_10000', 'Shift Master', 'Score 10,000 in one run.', 100),
    Achievement('near_miss_10', 'Close Call', '10 near misses in one run.', 30),
    Achievement('chain_x10', 'Perfect Chain', 'Build a chain of 10 (x3.0).', 40),
    Achievement('dash_3', 'Phase Runner', 'Pulse Dash 3 times in one run.', 30),
    Achievement('escape_chase', 'Escape Artist', 'Outrun the energy wave.', 40),
    Achievement('risk_taker', 'Risk Taker', 'Take every shard in a Risk Gate\'s danger lane.', 40),
    Achievement('no_dash_3000', 'Pure Skill', 'Score 3,000 without Pulse Dash.', 60),
    Achievement('break_3', 'Reality Bender', 'Survive 3 Reality Breaks in one run.', 60),
    Achievement('daily_done', 'Daily Shifter', 'Beat a daily challenge target.', 30),
    Achievement('lifetime_10k', 'Long Haul', 'Travel 10,000 m in total.', 80),
  ];

  /// Personal-best milestones and their one-time energy rewards.
  static const bestTiers = [500, 1000, 2500, 5000, 10000, 20000];
  static const bestTierRewards = [15, 25, 50, 80, 150, 300];

  static const dailyReward = 60;

  static Dimension dimension(String id) => dimensions.firstWhere((d) => d.id == id, orElse: () => dimensions.first);
  static OrbSkin skin(String id) => skins.firstWhere((s) => s.id == id, orElse: () => skins.first);
  static TrailStyle trail(String id) => trails.firstWhere((t) => t.id == id, orElse: () => trails.first);
  static Achievement achievement(String id) => achievements.firstWhere((a) => a.id == id);
}
