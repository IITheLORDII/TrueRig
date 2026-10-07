import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/images/part_images.dart';
import 'package:darbogaz/core/widgets/part_thumb.dart';

const _base = 'https://proj.supabase.co';

void main() {
  final catalog = PartCatalog.seed();
  final ram = catalog.byId('corsair-ddr5-6000-32')!;
  final gpu = catalog.byId('rtx-4090')!;

  test('imageKeyFor uses the lowercased MPN and skips parts without one', () {
    expect(imageKeyFor(ram), 'cmk32gx5m2b6000z30');
    expect(imageKeyFor(gpu), isNull);
  });

  group('PartImageRepository', () {
    test('is inert when not configured', () async {
      final repo = PartImageRepository(baseUrl: '', anonKey: '');
      expect(await repo.fetch(['cmk32gx5m2b6000z30']), isEmpty);
    });

    test('queries part_images once and keeps only https URLs', () async {
      late Uri requested;
      final client = MockClient((req) async {
        requested = req.url;
        expect(req.headers['apikey'], 'anon');
        return http.Response(
          jsonEncode([
            {
              'query': 'cmk32gx5m2b6000z30',
              'image_url': 'https://cdn.example/a.jpg',
            },
            {'query': 'bad', 'image_url': 'http://cdn.example/b.jpg'},
          ]),
          200,
        );
      });
      final repo = PartImageRepository(
        client: client,
        baseUrl: _base,
        anonKey: 'anon',
      );
      final map = await repo.fetch(['cmk32gx5m2b6000z30', 'bad', 'drop"me']);
      expect(map, {
        'cmk32gx5m2b6000z30': Uri.parse('https://cdn.example/a.jpg'),
      });
      expect(requested.path, '/rest/v1/part_images');
      expect(
        requested.queryParameters['query'],
        contains('cmk32gx5m2b6000z30'),
      );
      expect(requested.queryParameters['query'], isNot(contains('drop')));
    });

    test('non-200 throws so the provider can fall back', () async {
      final repo = PartImageRepository(
        client: MockClient((_) async => http.Response('x', 500)),
        baseUrl: _base,
        anonKey: 'anon',
      );
      expect(() => repo.fetch(['abc']), throwsA(isA<http.ClientException>()));
    });
  });

  test('session images win and are keyed by MPN', () async {
    final container = ProviderContainer(
      overrides: [
        partImageRepositoryProvider.overrideWithValue(
          PartImageRepository(baseUrl: '', anonKey: ''),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(cachedPartImagesProvider.future);
    expect(container.read(partImageProvider(ram)), isNull);

    container
        .read(sessionPartImagesProvider.notifier)
        .remember('CMK32GX5M2B6000Z30', Uri.parse('https://cdn.example/r.jpg'));
    expect(
      container.read(partImageProvider(ram)),
      Uri.parse('https://cdn.example/r.jpg'),
    );
  });

  testWidgets('PartThumb shows the category icon without an image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PartThumb(imageUrl: null, fallbackIcon: Icons.memory_rounded),
      ),
    );
    expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
  });
}
