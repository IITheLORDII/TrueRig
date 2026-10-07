/// Reads what the browser exposes about this machine. On mobile/desktop
/// builds there is no browser, so the stub returns null.
library;

export 'package:darbogaz/features/detect/browser_probe_stub.dart'
    if (dart.library.js_interop) 'package:darbogaz/features/detect/browser_probe_web.dart';
