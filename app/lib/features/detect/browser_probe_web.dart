import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:perf_engine/perf_engine.dart';
import 'package:web/web.dart' as web;

/// `WEBGL_debug_renderer_info.UNMASKED_RENDERER_WEBGL`.
const int _unmaskedRenderer = 0x9246;

bool get canProbeBrowser => true;

/// Browsers expose no CPU model, motherboard or exact RAM; only the GPU
/// renderer string (WebGL), logical thread count and screen size.
HardwareReport? probeBrowser() {
  final nav = web.window.navigator;
  final screen = web.window.screen;
  final dpr = web.window.devicePixelRatio;
  final gpu = _webglRenderer();
  return HardwareReport(
    threads: nav.hardwareConcurrency,
    gpuNames: [?gpu],
    screenWidth: (screen.width * dpr).round(),
    screenHeight: (screen.height * dpr).round(),
    source: 'browser',
  );
}

String? _webglRenderer() {
  final canvas = web.HTMLCanvasElement();
  final ctx =
      canvas.getContext('webgl') ?? canvas.getContext('experimental-webgl');
  if (ctx == null) return null;
  final gl = ctx as web.WebGLRenderingContext;
  final ext = gl.getExtension('WEBGL_debug_renderer_info');
  final value = gl.getParameter(
    ext == null ? web.WebGLRenderingContext.RENDERER : _unmaskedRenderer,
  );
  if (!value.isA<JSString>()) return null;
  final name = (value as JSString).toDart.trim();
  return name.isEmpty ? null : name;
}

/// Approximate RAM; browsers cap this at 8 GB, so it is only a lower bound.
double? browserDeviceMemoryGb() {
  final v = (web.window.navigator as JSObject).getProperty<JSAny?>(
    'deviceMemory'.toJS,
  );
  return v.isA<JSNumber>() ? (v as JSNumber).toDartDouble : null;
}

/// Android Chrome exposes the phone model code (e.g. "SM-S921B") through
/// User-Agent Client Hints. Safari/Firefox and desktops return null.
Future<String?> browserPhoneModel() async {
  final uaData = (web.window.navigator as JSObject).getProperty<JSObject?>(
    'userAgentData'.toJS,
  );
  if (uaData == null) return null;
  final mobile = uaData.getProperty<JSBoolean?>('mobile'.toJS)?.toDart;
  if (mobile != true) return null;
  try {
    final values = await uaData
        .callMethod<JSPromise<JSObject>>(
          'getHighEntropyValues'.toJS,
          ['model'.toJS].toJS,
        )
        .toDart;
    final model = values.getProperty<JSString?>('model'.toJS)?.toDart.trim();
    return model == null || model.isEmpty ? null : model;
  } on Object catch (e) {
    // JS promise rejections surface as non-Exception objects in Dart.
    web.console.warn('UA-CH model unavailable: $e'.toJS);
    return null;
  }
}
