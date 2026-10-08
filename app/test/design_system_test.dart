import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/verdicts.dart';
import 'package:darbogaz/core/widgets/buttons.dart';
import 'package:darbogaz/core/widgets/cards.dart';
import 'package:darbogaz/core/widgets/common.dart';
import 'package:darbogaz/core/widgets/flow.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

void main() {
  group('buttons', () {
    testWidgets('primary fires, is 52 tall and full width', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PrimaryButton(label: 'Devam', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Devam'));
      expect(taps, 1);
      final size = tester.getSize(find.byType(PrimaryButton));
      expect(size.height, 52);
      expect(size.width, greaterThan(700));
    });

    testWidgets('disabled primary does not fire', (tester) async {
      await tester.pumpWidget(
        _host(const PrimaryButton(label: 'Devam', onPressed: null)),
      );
      await tester.tap(find.text('Devam'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('all buttons meet tap target guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              PrimaryButton(label: 'A', onPressed: () {}),
              SecondaryButton(label: 'B', onPressed: () {}),
              TertiaryButton(label: 'C', onPressed: () {}),
              DangerButton(label: 'D', onPressed: () {}),
            ],
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('cards', () {
    testWidgets('NavCard reads as one button and taps', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          NavCard(
            icon: Icons.search,
            title: 'Parça ara',
            subtitle: 'Fiyatları gör',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Parça ara. Fiyatları gör'), findsOneWidget);
      await tester.tap(find.byType(NavCard));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('SelectCard exposes selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(SelectCard(title: 'Oyun', selected: true, onTap: () {})),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Oyun')),
        matchesSemantics(
          label: 'Oyun',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Notice shows title, message and action', (tester) async {
      await tester.pumpWidget(
        _host(
          Notice(
            title: 'Uyumsuz',
            message: 'RAM bu anakarta takılmaz.',
            tone: Tone.bad,
            action: TertiaryButton(label: 'Değiştir', onPressed: () {}),
          ),
        ),
      );
      expect(find.text('Uyumsuz'), findsOneWidget);
      expect(find.text('RAM bu anakarta takılmaz.'), findsOneWidget);
      expect(find.text('Değiştir'), findsOneWidget);
    });

    testWidgets('light theme text has enough contrast', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              NavCard(
                icon: Icons.search,
                title: 'Parça ara',
                subtitle: 'Fiyatları gör',
                onTap: () {},
              ),
              const Notice(
                title: 'Uyarı',
                message: 'Kısa not',
                tone: Tone.warn,
              ),
              const BulletRow('Bir madde'),
              const Footnote('Tahmini değerler'),
            ],
          ),
          brightness: Brightness.light,
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  group('flow', () {
    testWidgets('StatView error offers retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_host(StatView.error(onAction: () => retries++)));
      await tester.tap(find.text('Tekrar dene'));
      expect(retries, 1);
    });

    testWidgets('StepProgress announces the step', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const StepProgress(step: 2, total: 4)));
      expect(find.bySemanticsLabel('Adım 2 / 4'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('confirmAction returns true only on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmAction(
                context,
                title: 'Silinsin mi?',
                message: 'Geri alınamaz.',
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('verdicts', () {
    test('fps, ai speed and score share one scale', () {
      expect(fpsTone(75), Tone.good);
      expect(fpsTone(45), Tone.warn);
      expect(fpsTone(20), Tone.bad);
      expect(tpsTone(40), Tone.good);
      expect(tpsTone(12), Tone.warn);
      expect(tpsTone(5), Tone.bad);
      expect(bottleneckTone(5), Tone.good);
      expect(bottleneckTone(25), Tone.bad);
      expect(scoreWord(70), 'Güçlü');
      expect(scoreWord(50), 'Orta');
      expect(scoreWord(10), 'Zayıf');
    });
  });
}
