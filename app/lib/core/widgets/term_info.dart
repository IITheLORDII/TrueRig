/// Technical words used in the app, each with a short everyday explanation
/// for people who do not know computers. Shown with `Explain.term`.
library;

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
  /// Asked as a question, the way a newcomer would ask it.
  String get title => switch (this) {
    Term.bottleneck => 'Darboğaz nedir?',
    Term.fps => 'FPS nedir?',
    Term.onePercentLow => 'En düşük anlar ne demek?',
    Term.resolution => 'Çözünürlük nedir?',
    Term.preset => 'Grafik ayarı nedir?',
    Term.vram => 'Ekran kartı belleği nedir?',
    Term.llm => 'Bilgisayarda çalışan yapay zekâ nedir?',
    Term.tokensPerSec => 'Yapay zekâ hızı ne demek?',
    Term.quant => 'Q4, Q8 ne demek?',
    Term.sustained => 'Telefon ısınınca ne olur?',
    Term.score => 'Bu puan ne demek?',
    Term.mpn => 'Parça kodu nedir?',
  };

  /// One or two short sentences, no jargon.
  String get body => switch (this) {
    Term.bottleneck =>
      'Bir parçanın diğerini yavaşlatmasıdır. Geniş bir yol dar bir '
          'köprüye bağlanırsa trafik köprüde tıkanır; bilgisayarda da en '
          'yavaş parça hızı belirler. Yeşil sorun yok, sarı biraz kayıp, '
          'kırmızı ise paranın bir kısmı boşa gidiyor demek.',
    Term.fps =>
      'Oyunun bir saniyede gösterdiği resim sayısı. Ne kadar yüksekse oyun '
          'o kadar akıcı görünür: 60 ve üstü akıcı, 30 altı takılır.',
    Term.onePercentLow =>
      'Oyunun en yavaşladığı anlardaki hız. Bu sayı düşükse oyun ara ara '
          'takılır, ortalama yüksek olsa bile.',
    Term.resolution =>
      'Görüntünün netliği. 1080p çoğu ekranda standarttır. 1440p ve 4K daha '
          'net ama ekran kartını çok daha fazla yorar.',
    Term.preset =>
      'Oyunun ne kadar güzel göründüğü (Düşük, Orta, Yüksek, Ultra). '
          'Yükseldikçe görüntü güzelleşir ama oyun yavaşlar.',
    Term.vram =>
      'Ekran kartının kendi hafızası. Yeni oyunlar 8 GB ve üstü ister; '
          'yetmezse oyun takılır.',
    Term.llm =>
      'İnternete bağlanmadan bilgisayarında çalışan sohbet yapay zekâsı. '
          'Ekran kartının hafızası ne kadar büyükse o kadar akıllı model '
          'çalışır.',
    Term.tokensPerSec =>
      'Yapay zekânın cevabı ne kadar hızlı yazdığı. 10 ve üstü rahat okunur, '
          '30 ve üstü çok hızlıdır.',
    Term.quant =>
      'Modelin ne kadar sıkıştırıldığı. Q4 küçük ve hızlıdır, çoğu kişi için '
          'yeterlidir; büyük sayılar daha doğru ama daha ağırdır.',
    Term.sustained =>
      'Uzun oyunda telefon ısınır ve kendini yavaşlatır. Bu değer, 20 dakika '
          'sonra hızın ne kadarının kaldığını gösterir.',
    Term.score =>
      'Telefonun ne kadar güçlü olduğunu tek sayıda özetler. 75 üstü güçlü, '
          '50–75 orta, 50 altı zayıf.',
    Term.mpn =>
      'Üreticinin ürüne verdiği kod. Kutunun üzerinde yazar; mağazada aynı '
          'ürünü bulmanın en kesin yoludur.',
  };
}
