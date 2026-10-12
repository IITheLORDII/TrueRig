/// Store domains the app may open. Price data comes from outside (the daily
/// index and the price service), so a tampered offer could point anywhere;
/// only pages on these stores' own domains are ever opened.
const Set<String> kTrustedStoreDomains = {
  // Turkey
  'akakce.com',
  'cimri.com',
  'epey.com',
  'hepsiburada.com',
  'trendyol.com',
  'n11.com',
  'amazon.com.tr',
  'vatanbilgisayar.com',
  'itopya.com',
  'incehesap.com',
  'teknosa.com',
  'mediamarkt.com.tr',
  'gaming.gen.tr',
  'monsternotebook.com.tr',
  'troyestore.com',
  'pazarama.com',
  'sinerji.gen.tr',
  // Global
  'amazon.com',
  'newegg.com',
  'pcpartpicker.com',
};

/// True for plain https pages (default port, no credentials) on one of the
/// [kTrustedStoreDomains] or their subdomains.
bool isTrustedStoreUrl(Uri url) {
  if (url.scheme != 'https' || url.userInfo.isNotEmpty) return false;
  if (url.hasPort && url.port != 443) return false;
  final host = url.host.toLowerCase();
  if (host.isEmpty) return false;
  return kTrustedStoreDomains.any((d) => host == d || host.endsWith('.$d'));
}
