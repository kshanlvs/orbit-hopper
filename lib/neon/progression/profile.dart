import 'dart:convert';

class NeonSettings {
  const NeonSettings({
    this.music = true,
    this.sfx = true,
    this.haptics = true,
    this.reducedEffects = false,
    this.pauseOnFocusLoss = true,
    this.highContrast = false,
  });

  final bool music;
  final bool sfx;
  final bool haptics;

  /// Fewer particles, no screen shake, no camera twist, no flashing.
  final bool reducedEffects;
  final bool pauseOnFocusLoss;

  /// Brighter, thicker hazard outlines and a plain background.
  final bool highContrast;

  NeonSettings copyWith({
    bool? music,
    bool? sfx,
    bool? haptics,
    bool? reducedEffects,
    bool? pauseOnFocusLoss,
    bool? highContrast,
  }) =>
      NeonSettings(
        music: music ?? this.music,
        sfx: sfx ?? this.sfx,
        haptics: haptics ?? this.haptics,
        reducedEffects: reducedEffects ?? this.reducedEffects,
        pauseOnFocusLoss: pauseOnFocusLoss ?? this.pauseOnFocusLoss,
        highContrast: highContrast ?? this.highContrast,
      );

  Map<String, Object?> toJson() => {
        'music': music,
        'sfx': sfx,
        'haptics': haptics,
        'reducedEffects': reducedEffects,
        'pauseOnFocusLoss': pauseOnFocusLoss,
        'highContrast': highContrast,
      };

  factory NeonSettings.fromJson(Map<String, Object?> j) => NeonSettings(
        music: j['music'] as bool? ?? true,
        sfx: j['sfx'] as bool? ?? true,
        haptics: j['haptics'] as bool? ?? true,
        reducedEffects: j['reducedEffects'] as bool? ?? false,
        pauseOnFocusLoss: j['pauseOnFocusLoss'] as bool? ?? true,
        highContrast: j['highContrast'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is NeonSettings &&
      other.music == music &&
      other.sfx == sfx &&
      other.haptics == haptics &&
      other.reducedEffects == reducedEffects &&
      other.pauseOnFocusLoss == pauseOnFocusLoss &&
      other.highContrast == highContrast;

  @override
  int get hashCode => Object.hash(music, sfx, haptics, reducedEffects, pauseOnFocusLoss, highContrast);
}

/// Everything Neon Shift remembers between launches.
class NeonProfile {
  const NeonProfile({
    this.best = 0,
    this.runs = 0,
    this.lifetimeDistance = 0,
    this.energy = 0,
    this.ownedSkins = const {'pulse'},
    this.ownedTrails = const {'streak'},
    this.skin = 'pulse',
    this.trail = 'streak',
    this.dimension = 'core',
    this.achievements = const {},
    this.tiersClaimed = 0,
    this.dailyDate,
    this.dailyBest = 0,
    this.dailyDone = false,
    this.settings = const NeonSettings(),
  });

  final int best;
  final int runs;
  final int lifetimeDistance;
  final int energy;
  final Set<String> ownedSkins;
  final Set<String> ownedTrails;
  final String skin;
  final String trail;
  final String dimension;
  final Set<String> achievements;

  /// How many of the personal-best tiers have paid out.
  final int tiersClaimed;

  /// The daily challenge this progress belongs to (yyyy-mm-dd).
  final String? dailyDate;
  final int dailyBest;
  final bool dailyDone;

  final NeonSettings settings;

  NeonProfile copyWith({
    int? best,
    int? runs,
    int? lifetimeDistance,
    int? energy,
    Set<String>? ownedSkins,
    Set<String>? ownedTrails,
    String? skin,
    String? trail,
    String? dimension,
    Set<String>? achievements,
    int? tiersClaimed,
    String? dailyDate,
    int? dailyBest,
    bool? dailyDone,
    NeonSettings? settings,
  }) =>
      NeonProfile(
        best: best ?? this.best,
        runs: runs ?? this.runs,
        lifetimeDistance: lifetimeDistance ?? this.lifetimeDistance,
        energy: energy ?? this.energy,
        ownedSkins: ownedSkins ?? this.ownedSkins,
        ownedTrails: ownedTrails ?? this.ownedTrails,
        skin: skin ?? this.skin,
        trail: trail ?? this.trail,
        dimension: dimension ?? this.dimension,
        achievements: achievements ?? this.achievements,
        tiersClaimed: tiersClaimed ?? this.tiersClaimed,
        dailyDate: dailyDate ?? this.dailyDate,
        dailyBest: dailyBest ?? this.dailyBest,
        dailyDone: dailyDone ?? this.dailyDone,
        settings: settings ?? this.settings,
      );

  Map<String, Object?> toJson() => {
        'v': 1,
        'best': best,
        'runs': runs,
        'lifetimeDistance': lifetimeDistance,
        'energy': energy,
        'ownedSkins': ownedSkins.toList()..sort(),
        'ownedTrails': ownedTrails.toList()..sort(),
        'skin': skin,
        'trail': trail,
        'dimension': dimension,
        'achievements': achievements.toList()..sort(),
        'tiersClaimed': tiersClaimed,
        'dailyDate': dailyDate,
        'dailyBest': dailyBest,
        'dailyDone': dailyDone,
        'settings': settings.toJson(),
      };

  String encode() => jsonEncode(toJson());

  factory NeonProfile.fromJson(Map<String, Object?> j) {
    Set<String> strings(Object? v, Set<String> fallback) =>
        v is List ? {...fallback, ...v.whereType<String>()} : fallback;
    int integer(Object? v) => v is num ? v.toInt() : 0;
    final settings = j['settings'];
    return NeonProfile(
      best: integer(j['best']),
      runs: integer(j['runs']),
      lifetimeDistance: integer(j['lifetimeDistance']),
      energy: integer(j['energy']),
      ownedSkins: strings(j['ownedSkins'], const {'pulse'}),
      ownedTrails: strings(j['ownedTrails'], const {'streak'}),
      skin: j['skin'] as String? ?? 'pulse',
      trail: j['trail'] as String? ?? 'streak',
      dimension: j['dimension'] as String? ?? 'core',
      achievements: strings(j['achievements'], const {}),
      tiersClaimed: integer(j['tiersClaimed']),
      dailyDate: j['dailyDate'] as String?,
      dailyBest: integer(j['dailyBest']),
      dailyDone: j['dailyDone'] as bool? ?? false,
      settings: settings is Map<String, Object?> ? NeonSettings.fromJson(settings) : const NeonSettings(),
    );
  }

  /// Never throws: a corrupt save gives a fresh profile.
  static NeonProfile decode(String? raw) {
    if (raw == null || raw.isEmpty) return const NeonProfile();
    try {
      final j = jsonDecode(raw);
      return j is Map<String, Object?> ? NeonProfile.fromJson(j) : const NeonProfile();
    } catch (_) {
      return const NeonProfile();
    }
  }
}
