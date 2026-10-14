import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Loads the real Roboto + Material Icons fonts that ship with the Flutter
/// SDK, so screenshots and overflow checks use real glyph widths instead of
/// the test font's wide boxes. Silently does nothing if they aren't found.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    print('STAT fonts: FLUTTER_ROOT not set');
    return;
  }
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    print('STAT fonts: no ${dir.path}');
    return;
  }
  ByteData bytes(File f) => ByteData.view(Uint8List.fromList(f.readAsBytesSync()).buffer);
  final files = dir.listSync().whereType<File>().toList();
  final roboto = FontLoader('Roboto');
  var n = 0;
  for (final f in files) {
    final name = f.uri.pathSegments.last.toLowerCase();
    if (name.startsWith('roboto-') && name.endsWith('.ttf') && !name.contains('condensed')) {
      roboto.addFont(Future.value(bytes(f)));
      n++;
    }
  }
  if (n > 0) await roboto.load();
  for (final f in files) {
    final name = f.uri.pathSegments.last.toLowerCase();
    if (name.startsWith('materialicons-regular')) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(bytes(f)))).load();
    }
  }
  print('STAT fonts: roboto=$n files=${files.length}');
}
