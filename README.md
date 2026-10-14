# Orbit Hopper

An endless one-tap space game built with Flutter + Flame.

You are a comet starting at the Sun. **Tap** to fly off on a tangent and get caught by the next body's gravity. You travel outward through the real universe: past the planets in their true order, through the asteroid and Kuiper belts, past Voyager 1, on to nearby stars, the Milky Way's core, Andromeda and the edge of the observable universe.

## Features

- **Perfect skims:** enter an orbit sideways, not head-on, for a PERFECT. Chained perfects build a combo worth up to +5 per landing.
- **Skip bonus:** jump past a planet straight to the next one for extra points.
- **Unstable planets:** from planet 3 on, a ring timer shows how long the planet holds. It wobbles and the screen pulses red before it collapses.
- **Moons:** killer moons circle some planets, so you have to time your exit and entry around them.
- **Drifting planets:** in later sectors, planets slide side to side.
- **Stardust:** pick up sparkles between planets and spend them on 7 comet skins (the Prism skin cycles through rainbow colours).
- **The real journey:** 40 real places in true order from the Sun, one every 4 hops: the planets and their famous moons (the Moon, Europa, Titan), Vesta and Ceres, Arrokoth, Sedna and Eris, both Voyagers, the Oort Cloud, nearby stars (Proxima Centauri, Barnard's Star, Sirius, Epsilon Eridani, Vega, TRAPPIST-1), the Pleiades, Betelgeuse, the Orion and Crab nebulae, Omega Centauri, Sagittarius A*, the Magellanic Clouds, Andromeda, Triangulum, M87, the Great Attractor and the edge of the observable universe. Each one is drawn in its own style.
- **Endless uncharted worlds:** past the edge, generated worlds keep coming forever (ocean worlds, crystal planets, ringed giants, twin suns, living nebulae, glass galaxies, Lumen beacons), each with its own name and story text, clearly marked as uncharted.
- **Milestones:** seven chapters (The Inner Planets, The Giants, Edge of the Solar System, Neighbour Stars, The Milky Way, Other Galaxies, The Edge of Everything) with big stardust rewards, then an endless chain of Uncharted Expeditions. The next milestone shows on the home screen and in the Star Map.
- **The Signal (story):** a mysterious alien transmission is decoded fragment by fragment at key places (Jupiter, Voyager 1, Proxima, TRAPPIST-1, the Orion Nebula, Sagittarius A*, Andromeda, the edge), leading to first contact with the Lumen beyond the edge of the universe. Story text is shown separately from the true facts, and every transmission can be re-read in the Star Map.
- **Real distances:** the HUD shows how far you are from the Sun (AU, then light-years) and a progress bar to the next real place.
- **Fact cards:** landing on a real place shows a short, true fact. The first landing on each one earns +10 stardust.
- **Star Map:** a collection screen listing all 21 places in true order, grouped by region. Places you've reached reveal their facts; the rest stay locked.
- **Regions:** 13 regions with their own sky and their own kind of filler bodies: rocks in the inner system, ice in the Kuiper Belt, stars in interstellar space, nebulae in the stellar nursery, galaxies in intergalactic space. The background fades between them, with the Sun's glow, the Milky Way band, and distant galaxies.
- **Unknown objects:** real places you haven't found yet appear as dark silhouettes marked "UNKNOWN OBJECT". A signal arrow at the top of the screen counts the hops to the next one, it sends sonar pings as you get close, and landing on it triggers a slow-motion reveal.
- **Incoming signals:** every undiscovered place has a cryptic teaser that never names it ("Something ahead is wearing a crown of ice"). Teasers appear on the home screen, on fact cards, in the Star Map and on game over ("Only 2 hops from an unknown object…").
- **Wormholes:** rare swirling portals beside the path. Fly through one to warp 2–3 hops ahead with a hyperspace flash. They never skip past the next real place; you land right on it instead.
- **Asteroid fields:** in the Asteroid Belt and the Kuiper Belt, single rocks drift across about half of the gaps, so you have to time some jumps around them.
- **Shields:** a rare green bubble that absorbs one moon or asteroid hit, then leaves you briefly invulnerable.
- **Missions:** three active goals (perfects, combos, stardust, hops, wormholes, shield saves, discoveries) with stardust rewards. Completing one pops a toast mid-run and replaces it with a harder one.
- **Explorer ranks:** from Solar Cadet to Master of the Universe, based on the furthest place you've discovered, with a rank-up moment on the fact card.
- **Save Earth mode:** a 2-km asteroid is on a collision course with Earth. Launch from Earth, hop through debris to build charge (PERFECT = double), then ram the killer asteroid before the countdown hits zero. Alarms sound in the last 10 seconds. A win gives a huge slow-motion deflection, a stardust reward, the real story of NASA's DART mission, and a harder threat level next time.
- **Checkpoints:** every place you discover becomes a launch point, so the journey always moves forward. Pick any discovered place in the Star Map to launch from it.
- **Travel feel:** stars stretch into warp streaks when you move fast (faster the deeper you go), the camera pulls back in flight, the distance from the Sun ticks up live while you fly, and there's slow motion for discoveries and crashes.
- **Sound:** original synthesized effects (launch, landing, a rising chime per combo step, stardust, collapse warning, explosion, discovery reveal, sonar ping, warp whoosh) and four music moods: warm near the Sun, cold among the outer planets, tense in interstellar space, and vast among the galaxies. The music crossfades as you cross regions and ducks while paused. Sound effects play from preloaded low-latency pools, so they land exactly on the action. There's a mute toggle on the home screen.
- **Performance:** every planet, glow and label is drawn once into a cached image and then just blitted, with no blurs per frame, stars batched into a few draw calls, and region skies pre-rendered.
- **Effects:** particles, shockwaves, screen shake, gold flashes, haptics, a parallax starfield and an aim guide for the first jumps.

## Run it

```bash
cd orbit_hopper
flutter create . --platforms=android,ios   # generates the native folders; keeps lib/ as is
flutter pub get
flutter run
```

If `pub get` reports a version conflict, run `flutter pub upgrade --major-versions`.

All sounds were synthesized by `tool/make_sounds.py`, so they have no licensing issues. To tweak them, edit the script and run `python3 tool/make_sounds.py` (needs numpy, scipy and ffmpeg).

Run the logic tests with:

```bash
flutter test
```

## Structure

```
lib/
  core/          theme, colours, go_router config
  domain/        entities (PlayerProgress, CometSkin) + repository interface
  data/          SharedPreferences repository
  game/
    logic/       pure-Dart simulation: world, generator, difficulty, cosmos (the real journey data) — unit-tested
    render/      body renderer (all planets/stars/galaxies), region backdrops, particles, starfield
    render/sprites.dart      cached body/glow/text images (the main performance win)
    audio/       pooled sound effects, mood music with crossfades
    orbit_hopper_game.dart   Flame game: loop, drawing, effects, slow-mo, warp, signals
  presentation/
    progress/    ProgressCubit (best score, stardust, skins)
    run/         RunCubit (score, combo, pause, game over)
    pages/       Home, Play, Star Map, Comets (skins)
    widgets/     HUD, pause/game-over panels, buttons
```

The simulation in `game/logic` doesn't depend on Flame or widgets. The Flame layer reads its events and draws them, and the Bloc layer only receives callbacks.

## Tuning

All difficulty settings live in `lib/game/logic/difficulty.dart`: gaps, planet sizes, orbit and launch speed, collapse time, and how often moons and drifting planets appear. Difficulty ramps from planet 0 to planet 80 and then stays at its maximum.

To add or edit real places, change the `journey` list in `lib/game/logic/cosmos.dart`. Each entry has a name, its real distance, a look, facts, and optionally the region that starts there.
