import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_hopper/neon/audio/neon_audio.dart';
import 'package:orbit_hopper/neon/engine/hazards.dart';
import 'package:orbit_hopper/neon/engine/neon_world.dart';
import 'package:orbit_hopper/neon/render/fx.dart';
import 'package:orbit_hopper/neon/render/palette.dart';
import 'package:orbit_hopper/neon/render/scene.dart';
import 'package:orbit_hopper/neon/ui/neon_routes.dart';
import 'package:orbit_hopper/neon/ui/neon_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bot.dart';
import 'fonts.dart';

/// Screenshots go to build/shots/ (CI publishes them for review).
Future<void> _save(ui.Image image, String name) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/shots/$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await _save(await boundary.toImage(pixelRatio: 1), name);
  });
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUpAll(loadRealFonts);

  setUp(() {
    NeonAudio.silent = true;
    SharedPreferences.setMockInitialValues({});
  });

  for (final size in const [Size(800, 360), Size(640, 320), Size(1024, 600)]) {
    testWidgets('every Neon Shift screen lays out at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: NeonRoutes.menu, routes: [neonShellRoute()]);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: MaterialApp.router(routerConfig: router, theme: neonTheme())),
      );
      await _frames(tester, 10);
      expect(find.text('PLAY'), findsOneWidget);
      final tag = '${size.width.toInt()}';
      await _shot(tester, key, 'menu_$tag');

      router.push(NeonRoutes.lab);
      await _frames(tester, 20);
      await _shot(tester, key, 'lab_$tag');
      await tester.tap(find.text('ORBS'));
      await _frames(tester, 10);
      await tester.tap(find.text('Nova'));
      await _frames(tester, 10);
      await _shot(tester, key, 'lab_orbs_$tag');
      router.pop();
      await _frames(tester, 20);

      router.push(NeonRoutes.challenges);
      await _frames(tester, 20);
      await _shot(tester, key, 'goals_$tag');
      router.pop();
      await _frames(tester, 20);

      router.push(NeonRoutes.settings);
      await _frames(tester, 20);
      await tester.tap(find.byType(Switch).first);
      await _frames(tester, 5);
      await _shot(tester, key, 'settings_$tag');
      router.pop();
      await _frames(tester, 20);

      // A run: flip a few times, then stop and let the corridor win.
      router.push(NeonRoutes.play);
      await _frames(tester, 30);
      await _shot(tester, key, 'play_start_$tag');
      for (var i = 0; i < 6; i++) {
        await tester.tapAt(Offset(size.width * 0.6, size.height * 0.5));
        await _frames(tester, 25);
      }
      await _shot(tester, key, 'play_mid_$tag');
      for (var i = 0; i < 900 && find.text('RETRY').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('RETRY'), findsOneWidget, reason: 'the run never ended');
      await _frames(tester, 70);
      await _shot(tester, key, 'game_over_$tag');

      await tester.tap(find.text('RETRY'));
      await _frames(tester, 10);
      expect(find.text('RETRY'), findsNothing);

      // Pause menu.
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await _frames(tester, 10);
      expect(find.text('PAUSED'), findsOneWidget);
      await _shot(tester, key, 'pause_$tag');
      await tester.tap(find.text('RESUME'));
      await _frames(tester, 60);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('scene snapshots across dimensions and events', (tester) async {
    final shots = <(String, double, String)>[
      ('core_start', 6, 'core'),
      ('core_patterns', 60, 'core'),
      ('sunset_break', 100, 'sunset'),
      ('toxic_risk', 200, 'toxic'),
      ('ice_chase', 335, 'ice'),
      ('inferno_late', 640, 'inferno'),
      ('void_late', 900, 'void'),
    ];
    final world = NeonWorld(seed: 2026);
    final bot = NeonBot(world);
    final scene = NeonScene();
    final particles = Particles(220), rings = Rings(), floaters = Floaters();
    final tx = <double>[], ty = <double>[];
    var t = 0.0;
    for (final (name, at, dim) in shots) {
      while (world.alive && world.s < at) {
        bot.tick();
        if (world.dashReady && world.s > 600) world.dash();
        for (final e in world.events) {
          if (e.type == NeonEventType.shard) particles.burst(e.x, e.y, const Color(0xFF8CFBFF), 7, speed: 0.8, size: 0.009);
          if (e.type == NeonEventType.nearMiss) floaters.add(e.x, e.y - 0.12, 'NEAR MISS +${e.value}', const Color(0xFF8A5CFF));
        }
        world.events.clear();
        tx.add(world.s);
        ty.add(world.orb.y);
        if (tx.length > 26) {
          tx.removeAt(0);
          ty.removeAt(0);
        }
        particles.update(1 / 120);
        floaters.update(1 / 120);
        t += 1 / 120;
      }
      expect(world.alive, isTrue, reason: 'bot died before $name');
      const size = Size(800, 360);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      scene.layout(size);
      final base = NeonPalette.of(dim);
      final pal = world.activeBreak == null ? base : base.shifted(world.activeBreak!, t);
      scene.render(
        canvas,
        SceneFrame(
          world: world,
          palette: pal,
          skin: SkinLook.of(dim == 'void' ? 'ghost' : 'pulse'),
          trail: dim == 'ice' ? 'ribbon' : 'streak',
          trailX: tx,
          trailY: ty,
          time: t,
          renderS: world.s,
          orbY: world.orb.y,
          particles: particles,
          rings: rings,
          floaters: floaters,
          reduced: false,
          highContrast: false,
          chaseFront: world.chaseActive ? 0.6 : 0,
          dashGlow: world.dashing ? 1 : 0,
        ),
      );
      final pic = rec.endRecording();
      await tester.runAsync(() async {
        await _save(await pic.toImage(800, 360), 'scene_$name');
      });
      final c = world.current;
      print('STAT shot $name s=${world.s.round()} chunk=${c.patternId} role=${c.role.name} '
          'break=${world.activeBreak?.name} chase=${world.chaseActive} hazards=${c.hazards.length} '
          'risk=${c.riskTop != null}');
    }
    expect(BreakVariant.values, isNotEmpty);
  });
}
