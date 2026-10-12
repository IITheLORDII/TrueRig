import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The web page's Content Security Policy must allow exactly the inline
/// scripts it contains (by hash) and nothing loose like 'unsafe-inline'
/// for scripts or wildcard connections.
void main() {
  final html = File('web/index.html').readAsStringSync();
  final csp = RegExp(r'http-equiv="Content-Security-Policy" content="([^"]+)"')
      .firstMatch(html)!
      .group(1)!;
  final scriptSrc = csp
      .split(';')
      .map((d) => d.trim())
      .firstWhere((d) => d.startsWith('script-src'));

  test('every inline script is allowed by its hash', () {
    final inline = RegExp(
      r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>',
      dotAll: true,
    ).allMatches(html);
    expect(inline, isNotEmpty);
    for (final m in inline) {
      final hash = base64.encode(
        sha256.convert(utf8.encode(m.group(1)!)).bytes,
      );
      expect(scriptSrc, contains("'sha256-$hash'"));
    }
  });

  test('no loose script or connection rules', () {
    expect(scriptSrc, isNot(contains("'unsafe-inline'")));
    expect(scriptSrc, isNot(contains("'unsafe-eval'")));
    final connect = csp
        .split(';')
        .map((d) => d.trim())
        .firstWhere((d) => d.startsWith('connect-src'));
    expect(connect, isNot(contains(' * ')));
    expect(connect, isNot(endsWith('*')));
    expect(csp, contains("object-src 'none'"));
  });

  test('the hosting headers forbid framing', () {
    final headers = File('web/_headers').readAsStringSync();
    expect(headers, contains("frame-ancestors 'none'"));
    expect(headers, contains('X-Frame-Options: DENY'));
  });
}
