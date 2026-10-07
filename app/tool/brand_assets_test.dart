// Renders the TrueRig mark to PNG files used by flutter_launcher_icons and
// flutter_native_splash. Run: flutter test tool/brand_assets_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darbogaz/core/brand/truerig_logo.dart';

Future<void> _render(
  WidgetTester tester,
  String path,
  CustomPainter painter,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox.square(
          dimension: 256,
          child: CustomPaint(painter: painter),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4); // 1024 px
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render brand assets', (tester) async {
    // iOS / legacy Android / web: opaque square tile.
    await _render(
      tester,
      'assets/brand/icon_1024.png',
      const TrueRigMarkPainter(true, tileRadius: 0),
    );
    // Android adaptive icon foreground: mark inside the 66% safe zone.
    await _render(
      tester,
      'assets/brand/icon_foreground.png',
      const TrueRigMarkPainter(false, markScale: 0.62),
    );
    // Native splash (Android 12 crops to a circle): smaller mark.
    await _render(
      tester,
      'assets/brand/splash_logo.png',
      const TrueRigMarkPainter(false, markScale: 0.6),
    );
    expect(File('assets/brand/icon_1024.png').existsSync(), isTrue);
  });
}
