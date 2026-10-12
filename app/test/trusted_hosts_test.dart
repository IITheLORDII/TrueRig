import 'package:flutter_test/flutter_test.dart';

import 'package:darbogaz/core/net/trusted_hosts.dart';

void main() {
  test('store pages on known store domains are trusted', () {
    for (final url in [
      'https://www.itopya.com/urun/rtx-4060',
      'https://www.vatanbilgisayar.com/x.html',
      'https://itopya.com/a',
      'https://www.amazon.com.tr/dp/B0',
      'https://m.hepsiburada.com/p',
    ]) {
      expect(isTrustedStoreUrl(Uri.parse(url)), isTrue, reason: url);
    }
  });

  test('anything else is refused', () {
    for (final url in [
      'https://itopya.com.evil.example/urun', // look-alike suffix
      'https://evilitopya.com/urun', // look-alike prefix
      'https://www.itopya.co/urun',
      'http://www.itopya.com/urun', // not https
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///etc/passwd',
      'https://user:pass@www.itopya.com/', // credentials in URL
      'https://www.itopya.com:8443/', // unusual port
    ]) {
      expect(isTrustedStoreUrl(Uri.parse(url)), isFalse, reason: url);
    }
  });
}
