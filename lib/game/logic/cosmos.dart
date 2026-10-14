import 'dart:math' as math;

/// How a body is drawn. Real landmarks and filler bodies share these styles.
enum BodyStyle {
  sun,
  rocky,
  cratered,
  venus,
  earth,
  mars,
  banded,
  ringed,
  icy,
  probe,
  cloud,
  star,
  nebula,
  blackHole,
  galaxy,
  cmb,
}

class BodyLook {
  const BodyLook(this.style, this.primary, this.secondary, {this.tilt = 0, this.spot = false});

  final BodyStyle style;

  /// Main and secondary colours as 0xAARRGGBB.
  final int primary;
  final int secondary;

  /// Ring tilt for ringed bodies (radians, 0 = flat).
  final double tilt;

  /// Draw a storm spot (Jupiter, Neptune).
  final bool spot;
}

/// Decorations painted behind everything in a region.
enum Backdrop { none, sunGlow, milkyBand, galaxies }

/// Which music plays in a region.
enum Mood { solar, outer, deep, cosmic }

class Region {
  const Region({
    required this.name,
    required this.topArgb,
    required this.bottomArgb,
    required this.fillers,
    required this.mood,
    this.backdrop = Backdrop.none,
  });

  final String name;
  final int topArgb;
  final int bottomArgb;

  /// Looks used for ordinary (non-landmark) bodies in this region.
  final List<BodyLook> fillers;
  final Backdrop backdrop;
  final Mood mood;
}

class Landmark {
  const Landmark({
    required this.id,
    required this.name,
    required this.distanceAu,
    required this.distanceLabel,
    required this.look,
    required this.radius,
    required this.facts,
    required this.teaser,
    this.region,
  });

  final String id;
  final String name;

  /// Real distance from the Sun in astronomical units (1 AU = Earth–Sun).
  final double distanceAu;
  final String distanceLabel;
  final BodyLook look;
  final double radius;
  final List<String> facts;

  /// Cryptic hint shown before the place is discovered. Never names it.
  final String teaser;

  /// A new region begins at this landmark (null = keep the previous one).
  final Region? region;
}

// ------------------------------------------------------------------ regions

const _rockGrey = BodyLook(BodyStyle.cratered, 0xFF9A9A9E, 0xFF5E5E66);
const _rockBrown = BodyLook(BodyStyle.rocky, 0xFF9C7A5B, 0xFF5A4232);
const _rockDark = BodyLook(BodyStyle.cratered, 0xFF6F6A66, 0xFF3A3634);
const _icePale = BodyLook(BodyStyle.icy, 0xFFD6ECF5, 0xFF8FB8CC);
const _iceBlue = BodyLook(BodyStyle.icy, 0xFFA8D8EA, 0xFF5E8FA8);
const _miniGas = BodyLook(BodyStyle.banded, 0xFFE0C9A6, 0xFFB08F6A);
const _cometIce = BodyLook(BodyStyle.cloud, 0xFFCFE9FF, 0xFF7FA7C9);
const _starRed = BodyLook(BodyStyle.star, 0xFFFF7A5C, 0xFFFFC2A8);
const _starWhite = BodyLook(BodyStyle.star, 0xFFEAF2FF, 0xFFFFFFFF);
const _starBlue = BodyLook(BodyStyle.star, 0xFF8FB8FF, 0xFFE0ECFF);
const _starYellow = BodyLook(BodyStyle.star, 0xFFFFD27A, 0xFFFFF1C9);
const _starOrange = BodyLook(BodyStyle.star, 0xFFFFA24C, 0xFFFFDDB0);
const _nebulaPink = BodyLook(BodyStyle.nebula, 0xFFFF6FB5, 0xFF7A5CFF);
const _nebulaTeal = BodyLook(BodyStyle.nebula, 0xFF4FE3C1, 0xFF3A7BFF);
const _galaxyBlue = BodyLook(BodyStyle.galaxy, 0xFFB5C8FF, 0xFFFFE7B0);
const _galaxyGold = BodyLook(BodyStyle.galaxy, 0xFFFFD9A0, 0xFFFFF4DD);
const _cmbBlob = BodyLook(BodyStyle.cmb, 0xFFFF9966, 0xFF4D7CFF);

const _innerSystem = Region(
  mood: Mood.solar,
  name: 'Inner Solar System',
  topArgb: 0xFF0D0705,
  bottomArgb: 0xFF2A1308,
  fillers: [_rockGrey, _rockBrown],
  backdrop: Backdrop.sunGlow,
);
const _asteroidBelt = Region(
  mood: Mood.solar,
  name: 'Asteroid Belt',
  topArgb: 0xFF0B0907,
  bottomArgb: 0xFF22180F,
  fillers: [_rockGrey, _rockBrown, _rockDark],
);
const _outerSystem = Region(
  mood: Mood.outer,
  name: 'Outer Solar System',
  topArgb: 0xFF050812,
  bottomArgb: 0xFF0E1C33,
  fillers: [_icePale, _iceBlue, _miniGas, _rockGrey],
);
const _kuiperBelt = Region(
  mood: Mood.outer,
  name: 'Kuiper Belt',
  topArgb: 0xFF04060D,
  bottomArgb: 0xFF0B1424,
  fillers: [_icePale, _rockDark, _iceBlue],
);
const _heliopause = Region(
  mood: Mood.outer,
  name: 'Edge of the Heliosphere',
  topArgb: 0xFF03040A,
  bottomArgb: 0xFF0A0F22,
  fillers: [_iceBlue, _rockDark, _cometIce],
);
const _oortCloud = Region(
  mood: Mood.deep,
  name: 'Oort Cloud',
  topArgb: 0xFF020309,
  bottomArgb: 0xFF081026,
  fillers: [_cometIce, _icePale],
);
const _interstellar = Region(
  mood: Mood.deep,
  name: 'Interstellar Space',
  topArgb: 0xFF020208,
  bottomArgb: 0xFF0D0A24,
  fillers: [_starRed, _starWhite, _rockDark, _starRed],
);
const _orionArm = Region(
  mood: Mood.deep,
  name: 'Orion Arm of the Milky Way',
  topArgb: 0xFF06031A,
  bottomArgb: 0xFF1C0D3A,
  fillers: [_starBlue, _starWhite, _starYellow, _starRed],
  backdrop: Backdrop.milkyBand,
);
const _stellarNursery = Region(
  mood: Mood.deep,
  name: 'Stellar Nursery',
  topArgb: 0xFF120420,
  bottomArgb: 0xFF2E0B3A,
  fillers: [_nebulaPink, _starBlue, _nebulaTeal, _starWhite],
  backdrop: Backdrop.milkyBand,
);
const _galacticCore = Region(
  mood: Mood.cosmic,
  name: 'Galactic Core',
  topArgb: 0xFF140B04,
  bottomArgb: 0xFF3A2008,
  fillers: [_starYellow, _starOrange, _starRed, _starWhite],
  backdrop: Backdrop.milkyBand,
);
const _intergalactic = Region(
  mood: Mood.cosmic,
  name: 'Intergalactic Space',
  topArgb: 0xFF010104,
  bottomArgb: 0xFF070A1A,
  fillers: [_galaxyBlue, _starWhite, _galaxyGold],
  backdrop: Backdrop.galaxies,
);
const _localGroup = Region(
  mood: Mood.cosmic,
  name: 'The Local Group',
  topArgb: 0xFF02020A,
  bottomArgb: 0xFF0C0E26,
  fillers: [_galaxyBlue, _galaxyGold, _nebulaTeal],
  backdrop: Backdrop.galaxies,
);
const _beyond = Region(
  mood: Mood.cosmic,
  name: 'Beyond the Map',
  topArgb: 0xFF0A0410,
  bottomArgb: 0xFF1E0A24,
  fillers: [_cmbBlob, _galaxyBlue, _galaxyGold, _nebulaPink],
  backdrop: Backdrop.galaxies,
);

// ------------------------------------------------------------------ journey

const double auPerLightYear = 63241;

/// The real journey, in order of distance from the Sun.
const List<Landmark> journey = [
  Landmark(
    id: 'sun',
    teaser: 'Where every journey begins.',
    name: 'The Sun',
    distanceAu: 0,
    distanceLabel: 'Start',
    look: BodyLook(BodyStyle.sun, 0xFFFFC23D, 0xFFFF7A1A),
    radius: 46,
    region: _innerSystem,
    facts: [
      'The Sun holds about 99.8% of all the mass in the solar system.',
      'Sunlight takes about 8 minutes and 20 seconds to reach Earth.',
    ],
  ),
  Landmark(
    id: 'mercury',
    teaser: 'A small, scorched world racing close to the fire.',
    name: 'Mercury',
    distanceAu: 0.39,
    distanceLabel: '0.39 AU',
    look: BodyLook(BodyStyle.cratered, 0xFFA8A29C, 0xFF6B655F),
    radius: 26,
    facts: [
      'The smallest planet, and the closest to the Sun.',
      'A year on Mercury lasts just 88 Earth days.',
    ],
  ),
  Landmark(
    id: 'venus',
    teaser: 'Something bright ahead, wrapped in poisonous clouds.',
    name: 'Venus',
    distanceAu: 0.72,
    distanceLabel: '0.72 AU',
    look: BodyLook(BodyStyle.venus, 0xFFF1D79A, 0xFFC9A061),
    radius: 34,
    facts: [
      'The hottest planet, at about 465 °C, because its thick CO₂ air traps heat.',
      'Venus spins backwards, and one day there is longer than its year.',
    ],
  ),
  Landmark(
    id: 'earth',
    teaser: 'A pale blue dot… and faint signals of life.',
    name: 'Earth',
    distanceAu: 1,
    distanceLabel: '1 AU',
    look: BodyLook(BodyStyle.earth, 0xFF2E7BFF, 0xFF3FBF6A),
    radius: 35,
    facts: [
      'The only world known to host life. Home!',
      '1 AU, the Earth–Sun distance, is about 150 million km.',
    ],
  ),
  Landmark(
    id: 'mars',
    teaser: 'A rusty world hiding the tallest volcano you will ever see.',
    name: 'Mars',
    distanceAu: 1.52,
    distanceLabel: '1.52 AU',
    look: BodyLook(BodyStyle.mars, 0xFFD9653B, 0xFF8C3A1E),
    radius: 30,
    facts: [
      'Olympus Mons on Mars is the tallest volcano in the solar system, about 2.5× Everest.',
      'Mars has two small moons, Phobos and Deimos.',
    ],
  ),
  Landmark(
    id: 'ceres',
    teaser: 'A field of drifting rocks… and a giant among them.',
    name: 'Ceres',
    distanceAu: 2.77,
    distanceLabel: '2.8 AU',
    look: BodyLook(BodyStyle.cratered, 0xFF8E8A86, 0xFF55514D),
    radius: 26,
    region: _asteroidBelt,
    facts: [
      'Ceres is the largest object in the asteroid belt, and a dwarf planet.',
      'The belt holds millions of rocks, but they are so spread out that spacecraft cross it safely.',
    ],
  ),
  Landmark(
    id: 'jupiter',
    teaser: 'Something enormous. A storm on it has raged for centuries.',
    name: 'Jupiter',
    distanceAu: 5.2,
    distanceLabel: '5.2 AU',
    look: BodyLook(BodyStyle.banded, 0xFFE3B98A, 0xFFA8693F, spot: true),
    radius: 50,
    region: _outerSystem,
    facts: [
      'The largest planet: more than 1,300 Earths could fit inside.',
      'The Great Red Spot is a storm wider than the whole Earth.',
    ],
  ),
  Landmark(
    id: 'saturn',
    teaser: 'Something ahead is wearing a crown of ice.',
    name: 'Saturn',
    distanceAu: 9.5,
    distanceLabel: '9.5 AU',
    look: BodyLook(BodyStyle.ringed, 0xFFE9D3A0, 0xFFB89A62, tilt: 0.35),
    radius: 42,
    facts: [
      'Saturn is less dense than water. In a big enough bathtub it would float!',
      'Its rings are mostly ice: some bits as small as dust, some as big as houses.',
    ],
  ),
  Landmark(
    id: 'uranus',
    teaser: 'A pale world, knocked over onto its side.',
    name: 'Uranus',
    distanceAu: 19.2,
    distanceLabel: '19.2 AU',
    look: BodyLook(BodyStyle.ringed, 0xFF9FE3E8, 0xFF5FB3BD, tilt: 1.35),
    radius: 36,
    facts: [
      'Uranus is tipped over by about 98°, so it rolls around the Sun on its side.',
      'It was the first planet discovered with a telescope, in 1781.',
    ],
  ),
  Landmark(
    id: 'neptune',
    teaser: 'Out here, the winds scream faster than sound.',
    name: 'Neptune',
    distanceAu: 30.1,
    distanceLabel: '30 AU',
    look: BodyLook(BodyStyle.banded, 0xFF3D63E0, 0xFF223A99, spot: true),
    radius: 35,
    facts: [
      'Neptune has the fastest winds in the solar system: over 2,000 km/h.',
      'One Neptune year lasts about 165 Earth years.',
    ],
  ),
  Landmark(
    id: 'pluto',
    teaser: 'A small, frozen heart, beating in the dark.',
    name: 'Pluto',
    distanceAu: 39.5,
    distanceLabel: '39.5 AU',
    look: BodyLook(BodyStyle.icy, 0xFFE2CFB4, 0xFF9C7F66),
    radius: 24,
    region: _kuiperBelt,
    facts: [
      'Pluto was reclassified as a dwarf planet in 2006.',
      'In 2015 New Horizons photographed a giant heart-shaped glacier on Pluto.',
    ],
  ),
  Landmark(
    id: 'voyager1',
    teaser: 'A faint human signal… still transmitting since 1977.',
    name: 'Voyager 1',
    distanceAu: 165,
    distanceLabel: '160+ AU',
    look: BodyLook(BodyStyle.probe, 0xFFD8D8D8, 0xFFFFC94D),
    radius: 24,
    region: _heliopause,
    facts: [
      'Launched in 1977, Voyager 1 is the farthest human-made object.',
      'In 2012 it became the first spacecraft to reach interstellar space.',
    ],
  ),
  Landmark(
    id: 'oort',
    teaser: 'A ghostly shell of countless frozen comets. Your birthplace?',
    name: 'Oort Cloud',
    distanceAu: 2000,
    distanceLabel: '2,000+ AU',
    look: BodyLook(BodyStyle.cloud, 0xFFCFE9FF, 0xFF7FA7C9),
    radius: 32,
    region: _oortCloud,
    facts: [
      'A vast, distant shell of icy bodies surrounding the whole solar system.',
      'Long-period comets, like you, are thought to come from here.',
    ],
  ),
  Landmark(
    id: 'proxima',
    teaser: 'A dim red light. The closest stranger in the dark.',
    name: 'Proxima Centauri',
    distanceAu: 4.24 * auPerLightYear,
    distanceLabel: '4.24 light-years',
    look: BodyLook(BodyStyle.star, 0xFFFF6A4D, 0xFFFFB199),
    radius: 30,
    region: _interstellar,
    facts: [
      'The nearest star to the Sun.',
      'This small red dwarf has at least one Earth-sized planet: Proxima b.',
    ],
  ),
  Landmark(
    id: 'sirius',
    teaser: 'The brightest light in your night sky… and it is not alone.',
    name: 'Sirius',
    distanceAu: 8.6 * auPerLightYear,
    distanceLabel: '8.6 light-years',
    look: BodyLook(BodyStyle.star, 0xFFCFE2FF, 0xFFFFFFFF),
    radius: 34,
    facts: [
      'The brightest star in Earth\'s night sky.',
      'Sirius is really two stars: Sirius A and a tiny white dwarf, Sirius B.',
    ],
  ),
  Landmark(
    id: 'betelgeuse',
    teaser: 'A dying giant, swollen and red.',
    name: 'Betelgeuse',
    distanceAu: 550 * auPerLightYear,
    distanceLabel: '≈550 light-years',
    look: BodyLook(BodyStyle.star, 0xFFFF5A2E, 0xFFFFA070),
    radius: 50,
    region: _orionArm,
    facts: [
      'A red supergiant. Placed where the Sun is, it would reach past the orbit of Mars.',
      'Its distance is uncertain: estimates range from about 500 to 700 light-years.',
    ],
  ),
  Landmark(
    id: 'orion_nebula',
    teaser: 'A glowing cloud where new stars are being born.',
    name: 'Orion Nebula',
    distanceAu: 1344 * auPerLightYear,
    distanceLabel: '≈1,340 light-years',
    look: BodyLook(BodyStyle.nebula, 0xFFFF6FB5, 0xFF5C7CFF),
    radius: 44,
    region: _stellarNursery,
    facts: [
      'A stellar nursery where new stars are being born right now.',
      'You can see it with bare eyes as the fuzzy middle "star" of Orion\'s sword.',
    ],
  ),
  Landmark(
    id: 'sgr_a',
    teaser: 'Light ahead is bending. Something is swallowing it.',
    name: 'Sagittarius A*',
    distanceAu: 26000 * auPerLightYear,
    distanceLabel: '≈26,000 light-years',
    look: BodyLook(BodyStyle.blackHole, 0xFFFFA43A, 0xFFFFE2A8, tilt: 0.3),
    radius: 34,
    region: _galacticCore,
    facts: [
      'The supermassive black hole at the heart of the Milky Way: about 4 million Suns of mass.',
      'Its first image was revealed by the Event Horizon Telescope in 2022.',
    ],
  ),
  Landmark(
    id: 'lmc',
    teaser: 'A cloud of stars outside our galaxy.',
    name: 'Large Magellanic Cloud',
    distanceAu: 160000 * auPerLightYear,
    distanceLabel: '≈160,000 light-years',
    look: BodyLook(BodyStyle.galaxy, 0xFFC9D6FF, 0xFFFFE9C2),
    radius: 40,
    region: _intergalactic,
    facts: [
      'A small satellite galaxy of the Milky Way, visible from the Southern Hemisphere.',
      'In 1987 a star exploded there: the closest supernova seen since 1604.',
    ],
  ),
  Landmark(
    id: 'andromeda',
    teaser: 'Another galaxy. Hundreds of billions of suns, heading our way.',
    name: 'Andromeda Galaxy',
    distanceAu: 2.5e6 * auPerLightYear,
    distanceLabel: '≈2.5 million light-years',
    look: BodyLook(BodyStyle.galaxy, 0xFFB5C8FF, 0xFFFFDFA8, tilt: 0.5),
    radius: 50,
    region: _localGroup,
    facts: [
      'The farthest thing most people can see with the naked eye.',
      'Astronomers long expected it to hit the Milky Way; a 2025 study puts the odds near 50% within 10 billion years.',
    ],
  ),
  Landmark(
    id: 'edge',
    teaser: 'The oldest light there is.',
    name: 'Edge of the Observable Universe',
    distanceAu: 46e9 * auPerLightYear,
    distanceLabel: '≈46 billion light-years',
    look: BodyLook(BodyStyle.cmb, 0xFFFF9966, 0xFF4D7CFF),
    radius: 50,
    region: _beyond,
    facts: [
      'The light from here has been travelling for about 13.8 billion years.',
      'Space kept expanding meanwhile, so this edge is now about 46 billion light-years away.',
    ],
  ),
];

/// Hops (planets) between two landmarks.
const int hopsPerLandmark = 6;

abstract final class Cosmos {
  /// Landmark index if planet [index] is a real landmark, otherwise null.
  static int? landmarkAt(int index) {
    if (index % hopsPerLandmark != 0) return null;
    final k = index ~/ hopsPerLandmark;
    return k < journey.length ? k : null;
  }

  /// Index of the last landmark at or before planet [index].
  static int lastLandmarkBefore(int index) =>
      math.min(index ~/ hopsPerLandmark, journey.length - 1);

  static Region regionAt(int index) {
    for (var k = lastLandmarkBefore(index); k >= 0; k--) {
      final r = journey[k].region;
      if (r != null) return r;
    }
    return journey.first.region!;
  }

  static bool isBeyondMap(int index) => index > (journey.length - 1) * hopsPerLandmark;

  /// Next landmark still ahead of planet [index], or null past the map.
  static Landmark? nextLandmark(int index) {
    final k = index ~/ hopsPerLandmark + 1;
    return k < journey.length ? journey[k] : null;
  }

  /// 0..1 progress from the previous landmark to the next.
  static double progressToNext(int index) =>
      (index % hopsPerLandmark) / hopsPerLandmark;

  /// Real distance from the Sun at planet [index], interpolated between landmarks
  /// on a log scale (space gets emptier the further you go).
  static double distanceAuAt(num index) {
    final k = lastLandmarkBefore(index.floor());
    final a = journey[k].distanceAu;
    if (k == journey.length - 1) return a;
    final b = journey[k + 1].distanceAu;
    final f = ((index - k * hopsPerLandmark) / hopsPerLandmark).clamp(0.0, 1.0);
    if (a <= 0) return b * f;
    return math.exp(math.log(a) + (math.log(b) - math.log(a)) * f);
  }

  static String formatDistance(double au) {
    if (au <= 0) return 'At the Sun';
    if (au < 100) return '${au.toStringAsFixed(au < 10 ? 2 : 1)} AU';
    if (au < 0.5 * auPerLightYear) return '${_group(au.round())} AU';
    final ly = au / auPerLightYear;
    if (ly < 100) return '${ly.toStringAsFixed(1)} light-years';
    if (ly < 1e6) return '${_group(ly.round())} light-years';
    if (ly < 1e9) return '${(ly / 1e6).toStringAsFixed(1)} million light-years';
    return '${(ly / 1e9).toStringAsFixed(1)} billion light-years';
  }

  static String distanceLabelAt(num index) =>
      isBeyondMap(index.floor()) ? 'Beyond the observable universe' : formatDistance(distanceAuAt(index));

  static int indexOfId(String id) {
    final k = journey.indexWhere((l) => l.id == id);
    return k < 0 ? 0 : k;
  }

  static String _group(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
