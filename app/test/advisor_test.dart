import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('gamer on a laptop gets real gaming laptops and warnings', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Bilgisayarı ne için alıyorsun?'), findsOneWidget);
    await tapText(tester, 'Bilgisayarı ne için alıyorsun?');

    expect(find.text('Bilgisayarda ne yapacaksın?'), findsOneWidget);
    await tapText(tester, 'Oyun');
    await tapText(tester, 'Devam');
    await tapText(tester, 'Yeni ve ağır oyunlar (Cyberpunk, RDR2)');
    await tapText(tester, 'Devam');
    await tapText(tester, 'Laptop');
    await tapText(tester, 'Devam');
    await tapText(tester, 'Bilmiyorum / fark etmez');
    await tapText(tester, 'Önerileri göster');

    expect(find.text('En uygun'), findsOneWidget);
    // Reasons and cautions open from question buttons.
    expect(find.textContaining('Ekran kartı olmayan'), findsNothing);
    await tapText(tester, 'Dikkat et: satın alırken nelere bakmalı?');
    expect(find.textContaining('Ekran kartı olmayan'), findsOneWidget);
    await tapText(tester, 'Neden bu önerildi?');
    expect(find.textContaining('FPS'), findsWidgets);
  });

  testWidgets('office user is told a gaming PC is not needed', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Bilgisayarı ne için alıyorsun?');
    await tapText(tester, 'İnternet, ofis ve ders');
    await tapText(tester, 'Devam'); // no games step
    expect(find.text('Laptop mu, masaüstü mü?'), findsOneWidget);
    await tapText(tester, 'Devam');
    await tapText(tester, 'Önerileri göster');
    await tapText(tester, 'Dikkat et: satın alırken nelere bakmalı?');
    expect(
      find.textContaining('Oyuncu bilgisayarına gerek yok'),
      findsOneWidget,
    );
  });

  testWidgets('Android back steps back through the questions', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Bilgisayarı ne için alıyorsun?');
    await tapText(tester, 'Oyun');
    await tapText(tester, 'Devam');
    expect(find.text('Hangi oyunları oynayacaksın?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bilgisayarda ne yapacaksın?'), findsOneWidget);
  });
}
