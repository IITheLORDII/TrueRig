import 'package:flutter/material.dart';

import 'package:darbogaz/core/theme/tokens.dart';

/// Technical words used in the app, each with a short everyday explanation.
enum Term {
  bottleneck,
  fps,
  onePercentLow,
  resolution,
  preset,
  vram,
  llm,
  tokensPerSec,
  quant,
  sustained,
  score,
  mpn,
}

extension TermText on Term {
  String get title => switch (this) {
    Term.bottleneck => 'Darboğaz nedir?',
    Term.fps => 'FPS nedir?',
    Term.onePercentLow => 'En düşük anlar (1% low)',
    Term.resolution => 'Çözünürlük (1080p, 1440p, 4K)',
    Term.preset => 'Grafik ayarı',
    Term.vram => 'Ekran kartı belleği (VRAM)',
    Term.llm => 'Yerel yapay zekâ (LLM)',
    Term.tokensPerSec => 'Kelime hızı (token/sn)',
    Term.quant => 'Sıkıştırma (Q4, Q8, FP16)',
    Term.sustained => 'Isınınca korunan performans',
    Term.score => 'Genel puan',
    Term.mpn => 'Parça numarası (MPN)',
  };

  String get body => switch (this) {
    Term.bottleneck =>
      'Bir parçanın diğerini yavaşlatmasıdır. Örneğin güçlü bir ekran kartı, '
          'zayıf bir işlemciyle tam gücünü kullanamaz. %10 altı sorun değil; '
          '%20 üstü belirgin kayıp demektir.',
    Term.fps =>
      'Oyunun saniyede çizdiği görüntü sayısı. 60 ve üstü akıcı, 30–60 '
          'oynanır, 30 altı takılır hissi verir.',
    Term.onePercentLow =>
      'Oyundaki en yavaş anların FPS değeri. Ortalama yüksek ama bu değer '
          'düşükse ara ara takılma hissedersin.',
    Term.resolution =>
      'Ekrandaki nokta sayısı. 1080p en yaygını; 1440p ve 4K daha keskin '
          'ama ekran kartını çok daha fazla yorar.',
    Term.preset =>
      'Oyun içindeki görüntü kalitesi (Düşük–Ultra). Yükseldikçe oyun güzel '
          'görünür ama FPS düşer.',
    Term.vram =>
      'Ekran kartının kendi belleği. Yeni oyunlar yüksek ayarda 8 GB ve '
          'üstü ister; yetmezse takılma olur.',
    Term.llm =>
      'Bilgisayarında internetsiz çalışan yapay zekâ sohbet modelleri '
          '(Qwen, Llama, Gemma). Ekran kartı belleği ne kadar fazlaysa o kadar '
          'büyük model çalışır.',
    Term.tokensPerSec =>
      'Yapay zekânın saniyede ürettiği kelime parçası sayısı. 10 ve üstü '
          'rahat okunur, 30 üstü çok hızlı hissettirir.',
    Term.quant =>
      'Modelin sıkıştırılma düzeyi. Q4 daha az bellek ister ve hızlıdır; '
          'FP16 en doğru ama en ağır olanıdır.',
    Term.sustained =>
      'Telefon uzun oyunda ısınınca yavaşlar. Bu değer, 20 dakika sonra '
          'performansın ne kadarının kaldığını gösterir.',
    Term.score =>
      'Telefonun işlemci, grafik ve belleğinin tek bir puanda özeti. '
          '75 üstü güçlü, 50–75 orta, 50 altı zayıf.',
    Term.mpn =>
      'Üreticinin parçaya verdiği kod. Mağazada aynı ürünü bulmanın en '
          'kesin yolu budur; kutunun üzerinde yazar.',
  };
}

Future<void> showTermSheet(BuildContext context, Term term) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.title,
              style: Theme.of(ctx).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.s),
            Text(term.body, style: Theme.of(ctx).textTheme.bodyLarge),
          ],
        ),
      ),
    );

/// Small ⓘ next to a technical word.
class TermInfoButton extends StatelessWidget {
  const TermInfoButton(this.term, {super.key});

  final Term term;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: term.title,
    visualDensity: VisualDensity.compact,
    icon: Icon(
      Icons.info_outline_rounded,
      size: 18,
      color: Theme.of(context).colorScheme.primary,
    ),
    onPressed: () => showTermSheet(context, term),
  );
}
