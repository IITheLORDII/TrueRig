import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/features/detect/detect_page.dart';
import 'package:darbogaz/features/detect/detection_controller.dart';
import 'package:perf_engine/perf_engine.dart';

String _code(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

final _laptop = _code({
  'v': 1,
  'cpu': '12th Gen Intel(R) Core(TM) i5-12450H',
  'cores': 8,
  'threads': 12,
  'gpus': ['NVIDIA GeForce GTX 1650', 'Intel(R) UHD Graphics'],
  'ram': [
    {'gb': 16, 'mts': 3200, 'type': 26},
    {'gb': 16, 'mts': 3200, 'type': 26},
  ],
  'board': 'CASPER BILGISAYAR SISTEMLERI NLAK 001',
});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> pump(WidgetTester tester, {String? code}) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: DetectPage(initialCode: code),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('helper code from the URL is applied and resolved', (
    tester,
  ) async {
    final c = await pump(tester, code: _laptop);
    expect(find.text('Tam algılama'), findsOneWidget);
    expect(find.text('Intel Core i5-12450H'), findsOneWidget);
    expect(find.text('NVIDIA GeForce GTX 1650'), findsOneWidget);
    expect(c.read(detectionProvider)?.build.ram?.totalGb, 32);
  });

  testWidgets('store apps hide the Windows helper (web-only feature)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Tam algılama (Windows)'), findsNothing);
    expect(find.textContaining('web sürümünü'), findsOneWidget);
  });

  test('malformed helper codes are rejected without throwing', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ctrl = c.read(detectionProvider.notifier);
    expect(ctrl.detectFromCode('bozuk-kod'), isFalse);
    expect(c.read(detectionProvider), isNull);
  });

  test('applyToBuild replaces the build and sets the screen resolution', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ctrl = c.read(detectionProvider.notifier);
    expect(ctrl.detectFromCode(_laptop), isTrue);
    c
        .read(buildProvider.notifier)
        .setPart(c.read(catalogProvider).byId('rtx-4090')!);
    ctrl.applyToBuild();
    final build = c.read(buildProvider);
    expect(build.gpu?.id, 'gtx-1650');
    expect(build.cpu?.id, 'i5-12450h');
  });

  test('suggested resolution follows physical screen width', () {
    DetectionState s(int w) => DetectionState(
      result: DetectionResult(
        report: HardwareReport(screenWidth: w, screenHeight: 1),
        build: const PcBuild(),
        cpuCandidates: const [],
        unmatched: const [],
      ),
    );
    expect(s(1920).suggestedResolution, Resolution.p1080);
    expect(s(2560).suggestedResolution, Resolution.p1440);
    expect(s(3840).suggestedResolution, Resolution.p2160);
  });
}
