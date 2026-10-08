import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const advisor = PurchaseAdvisor();
  const usdTry = 41.0;

  PurchaseAdvice advise(UsageProfile p) =>
      advisor.advise(p, catalog, usdTry: usdTry);

  test('office use: no gaming hardware, a saving is pointed out', () {
    final a = advise(const UsageProfile(uses: {Usage.office}));
    expect(a.options, isNotEmpty);
    final cheapest = a.options.first;
    expect(cheapest.label, 'En uygun');
    // Integrated graphics or an entry card is enough.
    expect(cheapest.build.gpu!.rasterScore, lessThan(15));
    expect(a.cautions.join(' '), contains('Oyuncu bilgisayarına gerek yok'));
  });

  test('heavy gaming never suggests integrated or 4 GB graphics', () {
    final a = advise(
      const UsageProfile(uses: {Usage.gaming}, gameLevel: GameLevel.heavy),
    );
    expect(a.options, isNotEmpty);
    for (final o in a.options) {
      expect(isIntegratedGpu(o.build.gpu!), isFalse, reason: o.name);
      expect(o.build.gpu!.vramGb, greaterThan(4), reason: o.name);
      expect(
          advisor.gameFps(
              o.build,
              const UsageProfile(
                  uses: {Usage.gaming}, gameLevel: GameLevel.heavy)),
          greaterThanOrEqualTo(60),
          reason: o.name);
    }
    expect(a.cautions.first, contains('Ekran kartı olmayan'));
  });

  test('options get stronger and pricier in order', () {
    final a = advise(
      const UsageProfile(uses: {Usage.gaming}, gameLevel: GameLevel.medium),
    );
    expect(a.options.length, greaterThanOrEqualTo(2));
    for (var i = 1; i < a.options.length; i++) {
      expect(a.options[i].priceTry, greaterThan(a.options[i - 1].priceTry));
      expect(a.options[i].score, greaterThan(a.options[i - 1].score));
    }
  });

  test('local AI needs at least 8 GB of graphics memory', () {
    final a = advise(const UsageProfile(uses: {Usage.ai}));
    expect(a.options, isNotEmpty);
    for (final o in a.options) {
      expect(o.build.gpu!.vramGb, greaterThanOrEqualTo(8), reason: o.name);
    }
  });

  test('laptop only returns laptops with laptop memory', () {
    final a = advise(
      const UsageProfile(uses: {Usage.gaming}, form: FormChoice.laptop),
    );
    expect(a.options, isNotEmpty);
    for (final o in a.options) {
      expect(o.isLaptop, isTrue);
      expect(o.build.ram!.formFactor, RamFormFactor.sodimm);
    }
  });

  test('too small a budget is said out loud', () {
    final a = advise(
      const UsageProfile(
        uses: {Usage.gaming},
        gameLevel: GameLevel.heavy,
        budgetTry: 5000,
      ),
    );
    expect(a.overBudget, isTrue);
    expect(a.cautions.join(' '), contains('Bütçen bu kullanım için düşük'));
  });

  test('office and coding never get a gaming graphics card', () {
    for (final uses in [
      {Usage.office},
      {Usage.coding},
      {Usage.office, Usage.coding},
    ]) {
      final a = advise(UsageProfile(uses: uses));
      expect(a.options, isNotEmpty, reason: '$uses');
      for (final o in a.options) {
        expect(o.build.gpu!.rasterScore, lessThan(15), reason: o.name);
      }
    }
  });
}
