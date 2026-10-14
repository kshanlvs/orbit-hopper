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
    this.asteroids = false,
  });

  final String name;
  final int topArgb;
  final int bottomArgb;

  /// Looks used for ordinary (non-landmark) bodies in this region.
  final List<BodyLook> fillers;
  final Backdrop backdrop;
  final Mood mood;

  /// Rocks drift across the gaps between planets in this region.
  final bool asteroids;
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
    this.real = true,
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

  /// False for generated uncharted worlds beyond the edge (their text is
  /// story, not science).
  final bool real;
}

// ------------------------------------------------------------------ regions

/// Look of the drifting asteroids.
const asteroidLook = BodyLook(BodyStyle.cratered, 0xFF8A8580, 0xFF4A4642);

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
  asteroids: true,
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
  asteroids: true,
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
const _virgo = Region(
  name: 'The Virgo Cluster',
  mood: Mood.cosmic,
  topArgb: 0xFF03020C,
  bottomArgb: 0xFF120C2A,
  fillers: [_galaxyGold, _galaxyBlue, _starWhite],
  backdrop: Backdrop.galaxies,
);
const _cosmicWeb = Region(
  name: 'The Cosmic Web',
  mood: Mood.cosmic,
  topArgb: 0xFF05020E,
  bottomArgb: 0xFF1A0830,
  fillers: [_nebulaPink, _galaxyBlue, _nebulaTeal],
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
/// The real journey, in true order of distance from the Sun.
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
    id: 'moon',
    teaser: 'A grey companion, close enough to touch… with footprints still on it.',
    name: 'The Moon',
    distanceAu: 1.0026,
    distanceLabel: '1 AU',
    look: BodyLook(BodyStyle.cratered, 0xFFC9C6C0, 0xFF7A7670),
    radius: 24,
    facts: [
      'The Moon is about 384,400 km from Earth.',
      'Only 12 people have ever walked on it, all on NASA\'s Apollo missions (1969–1972).',
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
    id: 'vesta',
    teaser: 'A bright rock among the dark ones, scarred by a giant crater.',
    name: 'Vesta',
    distanceAu: 2.36,
    distanceLabel: '2.4 AU',
    look: BodyLook(BodyStyle.rocky, 0xFFB8A48C, 0xFF6B5A48),
    radius: 22,
    region: _asteroidBelt,
    facts: [
      'Vesta is the brightest asteroid; on a dark night it can be seen without a telescope.',
      'NASA\'s Dawn spacecraft orbited it in 2011–2012 before moving on to Ceres.',
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
    id: 'europa',
    teaser: 'Ice above, something hidden below. An ocean?',
    name: 'Europa',
    distanceAu: 5.203,
    distanceLabel: '5.2 AU',
    look: BodyLook(BodyStyle.icy, 0xFFF0E2C8, 0xFFB07A55),
    radius: 26,
    facts: [
      'Under Europa\'s icy shell lies a salty ocean, maybe with twice the water of all Earth\'s oceans.',
      'NASA\'s Europa Clipper launched in 2024 to find out whether it could support life.',
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
    id: 'titan',
    teaser: 'An orange fog hides lakes that are not made of water.',
    name: 'Titan',
    distanceAu: 9.55,
    distanceLabel: '9.5 AU',
    look: BodyLook(BodyStyle.venus, 0xFFE6A84A, 0xFF9A6020),
    radius: 30,
    facts: [
      'Titan is the only moon with a thick atmosphere.',
      'It has rain, rivers and seas, but made of liquid methane, not water.',
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
    id: 'arrokoth',
    teaser: 'Something tiny and ancient, shaped like a snowman.',
    name: 'Arrokoth',
    distanceAu: 44.6,
    distanceLabel: '≈44 AU',
    look: BodyLook(BodyStyle.rocky, 0xFFC2705A, 0xFF6A3426),
    radius: 22,
    facts: [
      'Arrokoth is the most distant object a spacecraft has ever flown past (New Horizons, 2019).',
      'This snowman-shaped world has barely changed since the solar system formed.',
    ],
  ),
  Landmark(
    id: 'sedna',
    teaser: 'A red loner on a journey that takes over 10,000 years.',
    name: 'Sedna',
    distanceAu: 84.0,
    distanceLabel: '≈84 AU (now)',
    look: BodyLook(BodyStyle.rocky, 0xFFD05A40, 0xFF6E2418),
    radius: 24,
    facts: [
      'One orbit of the Sun takes Sedna more than 10,000 years.',
      'It is one of the reddest objects in the solar system.',
    ],
  ),
  Landmark(
    id: 'eris',
    teaser: 'A twin of a famous dwarf… the one that changed the rules.',
    name: 'Eris',
    distanceAu: 96.0,
    distanceLabel: '≈96 AU (now)',
    look: BodyLook(BodyStyle.icy, 0xFFF2F2F2, 0xFFA0A8B8),
    radius: 26,
    facts: [
      'Eris is almost exactly the size of Pluto; its discovery in 2005 led to Pluto being called a dwarf planet.',
      'Eris has a small moon named Dysnomia.',
    ],
  ),
  Landmark(
    id: 'voyager2',
    teaser: 'Another human whisper in the dark. It saw the ice giants.',
    name: 'Voyager 2',
    distanceAu: 140.0,
    distanceLabel: '≈140 AU',
    look: BodyLook(BodyStyle.probe, 0xFFD8D8D8, 0xFFFFC94D),
    radius: 24,
    region: _heliopause,
    facts: [
      'Voyager 2 is the only spacecraft ever to visit Uranus and Neptune.',
      'It crossed into interstellar space in 2018, six years after its twin.',
    ],
  ),
  Landmark(
    id: 'voyager1',
    teaser: 'A faint human signal… still transmitting since 1977.',
    name: 'Voyager 1',
    distanceAu: 170,
    distanceLabel: '≈170 AU',
    look: BodyLook(BodyStyle.probe, 0xFFD8D8D8, 0xFFFFC94D),
    radius: 24,
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
    id: 'barnard',
    teaser: 'A dim red star racing across the sky.',
    name: 'Barnard's Star',
    distanceAu: 5.96 * auPerLightYear,
    distanceLabel: '6 light-years',
    look: BodyLook(BodyStyle.star, 0xFFFF6A4D, 0xFFFFB199),
    radius: 28,
    facts: [
      'Barnard\'s Star moves across our sky faster than any other star.',
      'It is a small, old red dwarf, one of the Sun\'s closest neighbours.',
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
    id: 'eps_eri',
    teaser: 'A young orange sun, still wrapped in dust.',
    name: 'Epsilon Eridani',
    distanceAu: 10.5 * auPerLightYear,
    distanceLabel: '10.5 light-years',
    look: BodyLook(BodyStyle.star, 0xFFFFB86B, 0xFFFFE2B8),
    radius: 30,
    facts: [
      'Epsilon Eridani is younger than the Sun and still surrounded by rings of dust.',
      'A giant planet circles it, one of the closest known exoplanets.',
    ],
  ),
  Landmark(
    id: 'vega',
    teaser: 'A brilliant blue-white star that once guided travellers north.',
    name: 'Vega',
    distanceAu: 25.0 * auPerLightYear,
    distanceLabel: '25 light-years',
    look: BodyLook(BodyStyle.star, 0xFFBFD6FF, 0xFFFFFFFF),
    radius: 38,
    facts: [
      'Around 14,000 years ago Vega was the North Star, and it will be again in about 12,000 years.',
      'It spins so fast that it bulges at its equator.',
    ],
  ),
  Landmark(
    id: 'trappist1',
    teaser: 'Seven worlds circling one small red sun.',
    name: 'TRAPPIST-1',
    distanceAu: 40.7 * auPerLightYear,
    distanceLabel: '40 light-years',
    look: BodyLook(BodyStyle.star, 0xFFFF5A3A, 0xFFFFA080),
    radius: 34,
    facts: [
      'TRAPPIST-1 has seven rocky, Earth-sized planets.',
      'Three of them orbit where liquid water could exist.',
    ],
  ),
  Landmark(
    id: 'pleiades',
    teaser: 'Seven sisters, glowing blue in the dark.',
    name: 'The Pleiades',
    distanceAu: 444.0 * auPerLightYear,
    distanceLabel: '≈440 light-years',
    look: BodyLook(BodyStyle.nebula, 0xFF8FB8FF, 0xFF5C7CFF),
    radius: 44,
    region: _orionArm,
    facts: [
      'The Pleiades are a cluster of young, hot blue stars about 100 million years old.',
      'Japan calls this cluster Subaru, and the car company\'s logo shows its stars.',
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
    id: 'crab',
    teaser: 'The ghost of an explosion so bright it was seen in daylight.',
    name: 'Crab Nebula',
    distanceAu: 6500.0 * auPerLightYear,
    distanceLabel: '≈6,500 light-years',
    look: BodyLook(BodyStyle.nebula, 0xFFFF8A5C, 0xFF5CE1FF),
    radius: 44,
    facts: [
      'The Crab Nebula is what remains of a star that exploded; astronomers in China recorded it in 1054.',
      'At its heart a pulsar spins about 30 times every second.',
    ],
  ),
  Landmark(
    id: 'omega_cen',
    teaser: 'Ten million stars packed into one glowing ball.',
    name: 'Omega Centauri',
    distanceAu: 17000.0 * auPerLightYear,
    distanceLabel: '≈17,000 light-years',
    look: BodyLook(BodyStyle.cloud, 0xFFFFE2A0, 0xFFFFC870),
    radius: 44,
    facts: [
      'Omega Centauri is the largest star cluster in the Milky Way, with about 10 million stars.',
      'It may be the core of a small galaxy that ours swallowed long ago.',
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
    id: 'smc',
    teaser: 'A smaller cloud of stars, sibling of a larger one.',
    name: 'Small Magellanic Cloud',
    distanceAu: 200000.0 * auPerLightYear,
    distanceLabel: '≈200,000 light-years',
    look: BodyLook(BodyStyle.galaxy, 0xFFC9D6FF, 0xFFFFE9C2, tilt: 0.3),
    radius: 38,
    facts: [
      'The Small Magellanic Cloud is a dwarf galaxy you can see with bare eyes from the Southern Hemisphere.',
      'It and its larger sibling are named after Ferdinand Magellan, whose crew described them in the 1500s.',
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
    id: 'triangulum',
    teaser: 'A faint spiral, third in our neighbourhood.',
    name: 'Triangulum Galaxy',
    distanceAu: 2.73e6 * auPerLightYear,
    distanceLabel: '≈2.7 million light-years',
    look: BodyLook(BodyStyle.galaxy, 0xFFA8C8FF, 0xFFFFD6A8, tilt: 0.2),
    radius: 44,
    facts: [
      'Triangulum is the third-largest galaxy in our Local Group, after Andromeda and the Milky Way.',
      'Under very dark skies it is one of the most distant things the human eye can see.',
    ],
  ),
  Landmark(
    id: 'm87',
    teaser: 'A giant galaxy with a monster at its heart — the first ever seen.',
    name: 'M87',
    distanceAu: 5.35e7 * auPerLightYear,
    distanceLabel: '≈54 million light-years',
    look: BodyLook(BodyStyle.blackHole, 0xFFFF9A3A, 0xFFFFE0A0, tilt: 0.5),
    radius: 44,
    region: _virgo,
    facts: [
      'The black hole at the heart of M87 was the first ever photographed, in 2019.',
      'It weighs about 6.5 billion times as much as the Sun.',
    ],
  ),
  Landmark(
    id: 'great_attractor',
    teaser: 'Something unseen is pulling whole galaxies toward it.',
    name: 'The Great Attractor',
    distanceAu: 2.0e8 * auPerLightYear,
    distanceLabel: '≈200 million light-years',
    look: BodyLook(BodyStyle.nebula, 0xFFC77DFF, 0xFF5CE1FF),
    radius: 46,
    region: _cosmicWeb,
    facts: [
      'The Great Attractor is a huge concentration of mass pulling our galaxy and thousands of others toward it.',
      'It hides behind the dust of the Milky Way, so it is very hard to see directly.',
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

/// Hops (planets) between two real places.
const int hopsPerLandmark = 4;

// ------------------------------------------------------------------ beyond

const _beyondRegions = [
  Region(
    name: 'The Lumen Expanse',
    mood: Mood.cosmic,
    topArgb: 0xFF020A12,
    bottomArgb: 0xFF06303A,
    fillers: [_nebulaTeal, _starWhite, _galaxyBlue],
    backdrop: Backdrop.galaxies,
  ),
  Region(
    name: 'The Glass Reaches',
    mood: Mood.deep,
    topArgb: 0xFF0A0418,
    bottomArgb: 0xFF2A0E44,
    fillers: [_nebulaPink, _starBlue, _icePale],
    backdrop: Backdrop.galaxies,
  ),
  Region(
    name: 'The Dreaming Void',
    mood: Mood.deep,
    topArgb: 0xFF010103,
    bottomArgb: 0xFF0C0A1E,
    fillers: [_starRed, _galaxyGold, _cometIce],
    backdrop: Backdrop.galaxies,
  ),
];

class _WorldType {
  const _WorldType(this.kind, this.style, this.colors, this.teaser, this.lore);

  final String kind;
  final BodyStyle style;
  final List<(int, int)> colors;
  final String teaser;
  final List<String> lore;
}

const _worldTypes = <_WorldType>[
  _WorldType('Ocean World', BodyStyle.earth, [(0xFF1FB5C9, 0xFF2EE6A6), (0xFF3D5BFF, 0xFF7CF5FF)],
      'A world of endless water, glowing from below.',
      ['Its whole surface is one ocean, lit by creatures of light.', 'The Lumen say storms here can last a thousand years.']),
  _WorldType('Crystal Planet', BodyStyle.icy, [(0xFFFF9BE0, 0xFF9A5CFF), (0xFF9BF0FF, 0xFF5C7CFF)],
      'Something ahead is sparkling like a gem.',
      ['Its mountains are giant crystals that ring when starlight hits them.', 'The Lumen come here to listen to the planet "sing".']),
  _WorldType('Ringed Giant', BodyStyle.ringed, [(0xFFFFC97A, 0xFFB86A3A), (0xFFB5FFDD, 0xFF4FA88A)],
      'Rings upon rings, wider than any you have seen.',
      ['Its rings are so wide that a comet could orbit inside them for a year.', 'Tiny moons herd the rings like shepherds.']),
  _WorldType('Twin Suns', BodyStyle.star, [(0xFFFFB86B, 0xFFFFF1C9), (0xFF8FB8FF, 0xFFFFFFFF)],
      'Two lights, dancing around each other.',
      ['Two stars locked in a dance, each circling the other.', 'Worlds near them have two sunrises every day.']),
  _WorldType('Living Nebula', BodyStyle.nebula, [(0xFF4FE3C1, 0xFFFF6FB5), (0xFFFFD166, 0xFF7A5CFF)],
      'A cloud that seems to breathe.',
      ['This cloud of gas glows and dims slowly, as if it were breathing.', 'The Lumen believe new kinds of stars are born here.']),
  _WorldType('Glass Galaxy', BodyStyle.galaxy, [(0xFFE0F7FF, 0xFFB5C8FF), (0xFFFFE0F0, 0xFFC77DFF)],
      'A galaxy you can almost see through.',
      ['Its stars are so spread out that the whole galaxy looks like glass.', 'Light passing through it bends into rainbows.']),
  _WorldType('Lumen Beacon', BodyStyle.cloud, [(0xFF7CF5FF, 0xFFFFFFFF), (0xFFFFE2A0, 0xFFFFFFFF)],
      'A steady light, too regular to be natural.',
      ['A signal tower of the Lumen, guiding travellers through the dark.', 'Every comet that passes is given a name and remembered here.']),
  _WorldType('Silent Black Hole', BodyStyle.blackHole, [(0xFF9A7CFF, 0xFFE0D0FF), (0xFFFF6FB5, 0xFFFFD0E8)],
      'A circle of nothing, ringed with fire.',
      ['A black hole with a glowing ring, eating nothing at all, just waiting.', 'The Lumen fly around it to slingshot between galaxies.']),
  _WorldType('Ember World', BodyStyle.mars, [(0xFFFF6A3D, 0xFF7A1E10), (0xFFFFA24C, 0xFF8C3A1E)],
      'A red glow, warm as a campfire in space.',
      ['Rivers of glowing rock cross this world.', 'Even here, far beyond the map, something is still warm.']),
];

const _syllables = ['Ka', 'Lu', 'Vor', 'Ae', 'Thi', 'Zen', 'Ora', 'Qui', 'Sel', 'Nyx', 'Iri', 'Mo', 'Ves', 'Ul', 'Ry', 'Xa'];
const _endings = ['ra', 'on', 'is', 'ae', 'ix', 'um', 'el', 'ar'];

/// Number of real places in the journey.
int get realPlaces => journey.length;

final Map<int, Landmark> _generated = {};

Landmark _uncharted(int k) => _generated.putIfAbsent(k, () {
      final n = k - realPlaces; // 0, 1, 2…
      final rng = math.Random(n * 7919 + 101);
      final type = _worldTypes[rng.nextInt(_worldTypes.length)];
      final (a, b) = type.colors[rng.nextInt(type.colors.length)];
      final name = '${_syllables[rng.nextInt(_syllables.length)]}'
          '${_syllables[rng.nextInt(_syllables.length)].toLowerCase()}'
          '${_endings[rng.nextInt(_endings.length)]}';
      return Landmark(
        id: 'beyond_$n',
        name: '$name ${type.kind}',
        distanceAu: journey.last.distanceAu,
        distanceLabel: 'Uncharted',
        look: BodyLook(type.style, a, b, tilt: rng.nextDouble() * 0.6, spot: rng.nextBool()),
        radius: 30 + rng.nextDouble() * 16,
        facts: type.lore,
        teaser: type.teaser,
        real: false,
        region: n % 5 == 1 ? _beyondRegions[(n ~/ 5) % _beyondRegions.length] : null,
      );
    });

// ------------------------------------------------------------------ chapters

/// A milestone: finishing a chapter of the journey pays a big reward.
class Chapter {
  const Chapter(this.title, this.endId, this.reward);

  final String title;

  /// Reaching this place completes the chapter.
  final String endId;
  final int reward;
}

const chapters = <Chapter>[
  Chapter('The Inner Planets', 'mars', 100),
  Chapter('The Giants', 'neptune', 200),
  Chapter('Edge of the Solar System', 'oort', 300),
  Chapter('Neighbour Stars', 'trappist1', 400),
  Chapter('The Milky Way', 'sgr_a', 600),
  Chapter('Other Galaxies', 'great_attractor', 800),
  Chapter('The Edge of Everything', 'edge', 1000),
];

/// After the edge: an endless chain of expeditions, one per 8 uncharted worlds.
const int unchartedPerExpedition = 8;

// ------------------------------------------------------------------ story

/// "The Signal": the story told through transmissions. Fiction, kept
/// separate from the true facts on each place.
class Transmission {
  const Transmission(this.from, this.text, {this.fragment});

  final String from;
  final String text;

  /// Which part of the signal this decodes (null = no new fragment).
  final int? fragment;
}

const int signalFragments = 8;

const transmissions = <String, Transmission>{
  'sun': Transmission('MISSION CONTROL',
      'Little comet, our telescopes caught a faint signal repeating from far beyond the stars. Nobody knows who sent it. Follow it.'),
  'earth': Transmission('MISSION CONTROL',
      'The signal is not from Earth. It comes from deep space, and it grows stronger the further out you go.'),
  'jupiter': Transmission('SIGNAL · FRAGMENT 1',
      'Decoded: 2, 3, 5, 7, 11, 13… prime numbers. Nature does not count in primes. Someone made this.', fragment: 1),
  'voyager1': Transmission('SIGNAL · FRAGMENT 2',
      'The rhythm matches the golden record Voyager carries. They heard our message… and they are answering.',
      fragment: 2),
  'proxima': Transmission('SIGNAL · FRAGMENT 3',
      'A picture forms: a spiral of stars, with one tiny point marked. Not our Sun. Somewhere much further.',
      fragment: 3),
  'trappist1': Transmission('SIGNAL · FRAGMENT 4',
      'The signal pulses seven times, then stops. Then one word: "MANY". Are there many of them?', fragment: 4),
  'orion_nebula': Transmission('SIGNAL · FRAGMENT 5',
      '"WE WERE BORN IN CLOUDS LIKE THIS." They are old. Older than our Sun.', fragment: 5),
  'sgr_a': Transmission('SIGNAL · FRAGMENT 6',
      'The signal curves around the black hole; it was aimed to bend. "FOLLOW THE LIGHT THAT BENDS."', fragment: 6),
  'andromeda': Transmission('SIGNAL · FRAGMENT 7',
      '"YOU ARE CLOSE. LOOK BEYOND THE OLDEST LIGHT." Beyond the edge of the universe?', fragment: 7),
  'edge': Transmission('SIGNAL · FINAL FRAGMENT',
      '"WELCOME, TRAVELLER." The source lies past the edge of everything we know. Keep going.', fragment: 8),
  'beyond_0': Transmission('FIRST CONTACT',
      'Beings of pure light surround you. "We are the Lumen. Every comet that reaches us is given a name. '
          'The universe never ends, little one. Neither should you."'),
};

abstract final class Cosmos {
  /// Any place on the endless journey: real for the first [realPlaces],
  /// then generated uncharted worlds forever.
  static Landmark place(int k) => k < realPlaces ? journey[k] : _uncharted(k);

  /// Landmark index if planet [index] is a landmark (every [hopsPerLandmark]).
  static int? landmarkAt(int index) => index % hopsPerLandmark == 0 ? index ~/ hopsPerLandmark : null;

  /// Index of the last landmark at or before planet [index].
  static int lastLandmarkBefore(int index) => index ~/ hopsPerLandmark;

  static Region regionAt(int index) {
    for (var k = lastLandmarkBefore(index); k >= 0; k--) {
      final r = place(k).region;
      if (r != null) return r;
    }
    return journey.first.region!;
  }

  static int get edgeIndex => (realPlaces - 1) * hopsPerLandmark;

  static bool isBeyondMap(int index) => index > edgeIndex;

  /// Next landmark ahead of planet [index] (there is always one).
  static Landmark nextLandmark(int index) => place(index ~/ hopsPerLandmark + 1);

  /// 0..1 progress from the previous landmark to the next.
  static double progressToNext(int index) => (index % hopsPerLandmark) / hopsPerLandmark;

  /// Real distance from the Sun at planet [index], interpolated between landmarks
  /// on a log scale (space gets emptier the further you go).
  static double distanceAuAt(num index) {
    final k = math.min(lastLandmarkBefore(index.floor()), realPlaces - 1);
    final a = journey[k].distanceAu;
    if (k == realPlaces - 1) return a;
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

  static String distanceLabelAt(num index) {
    final i = index.floor();
    if (!isBeyondMap(i)) return formatDistance(distanceAuAt(index));
    final hops = i - edgeIndex;
    return 'Uncharted · $hops hop${hops == 1 ? '' : 's'} past the edge';
  }

  // ------------------------------------------------------------- ranks

  static const _rankSteps = <(String, String)>[
    ('earth', 'Planet Hopper'),
    ('vesta', 'Belt Runner'),
    ('jupiter', 'Giant Rider'),
    ('neptune', 'Edge Walker'),
    ('voyager2', 'Interstellar Voyager'),
    ('proxima', 'Star Sailor'),
    ('orion_nebula', 'Galaxy Wanderer'),
    ('lmc', 'Cosmic Navigator'),
    ('edge', 'Master of the Universe'),
  ];

  /// Explorer rank earned by reaching landmark [k].
  static String rankFor(int k) {
    if (k >= realPlaces) {
      final n = k - realPlaces;
      if (n >= 40) return 'Legend of the Void';
      if (n >= 16) return 'Multiverse Pioneer';
      return 'Friend of the Lumen';
    }
    var rank = 'Solar Cadet';
    for (final (id, title) in _rankSteps) {
      if (k >= indexOfId(id)) rank = title;
    }
    return rank;
  }

  /// True when reaching landmark [k] earns a new rank.
  static bool isRankUp(int k) => k > 0 && rankFor(k) != rankFor(k - 1);

  // ------------------------------------------------------------- milestones

  /// The milestone completed by reaching landmark [k], if any.
  static Chapter? chapterEndingAt(int k) {
    if (k < realPlaces) {
      final id = journey[k].id;
      for (final c in chapters) {
        if (c.endId == id) return c;
      }
      return null;
    }
    final n = k - realPlaces + 1; // uncharted worlds found
    if (n % unchartedPerExpedition != 0) return null;
    final e = n ~/ unchartedPerExpedition;
    return Chapter('Uncharted Expedition $e', 'beyond_${n - 1}', 500 + 100 * e);
  }

  /// The next milestone ahead of [furthest] (index of the furthest place
  /// discovered), with how many places are still left to reach it.
  static (Chapter, int) nextChapter(int furthest) {
    for (final c in chapters) {
      final end = indexOfId(c.endId);
      if (end > furthest) return (c, end - furthest);
    }
    var k = math.max(furthest + 1, realPlaces);
    while (chapterEndingAt(k) == null) {
      k++;
    }
    return (chapterEndingAt(k)!, k - furthest);
  }

  // ------------------------------------------------------------- story

  static Transmission? transmissionAt(int k) => transmissions[place(k).id];

  /// Signal fragments decoded so far, given the furthest place discovered.
  static int fragmentsDecoded(bool Function(int k) discovered) {
    var n = 0;
    for (final entry in transmissions.entries) {
      final f = entry.value.fragment;
      if (f != null && discovered(indexOfId(entry.key))) n++;
    }
    return n;
  }

  // ------------------------------------------------------------- ids

  static final Map<String, int> _realIndex = {for (var k = 0; k < journey.length; k++) journey[k].id: k};

  /// Journey index for a place id (real or 'beyond_n'); unknown ids map to 0.
  static int indexOfId(String id) {
    final real = _realIndex[id];
    if (real != null) return real;
    if (id.startsWith('beyond_')) {
      final n = int.tryParse(id.substring(7));
      if (n != null && n >= 0) return realPlaces + n;
    }
    return 0;
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
