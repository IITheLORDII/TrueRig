import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/features/detect/browser_probe.dart';

/// Raw identifier of the phone this app runs on:
/// iOS machine id ("iPhone16,1"), Android model ("SM-S921B" / "Pixel 8"),
/// or the Android Chrome UA-CH model on the website. No permission needed.
final selfDeviceIdProvider = FutureProvider<String?>((ref) async {
  if (kIsWeb) return browserPhoneModel();
  try {
    final info = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return (await info.androidInfo).model;
      case TargetPlatform.iOS:
        return (await info.iosInfo).utsname.machine;
      default:
        return null;
    }
  } on PlatformException catch (e) {
    debugPrint('device info unavailable: ${e.message}');
    return null;
  } on MissingPluginException catch (e) {
    debugPrint('device info plugin missing: ${e.message}');
    return null;
  }
});

/// The current phone matched against the catalog, if it is a known phone.
final selfPhoneProvider = FutureProvider<PhoneMatch?>((ref) async {
  final raw = await ref.watch(selfDeviceIdProvider.future);
  if (raw == null || raw.trim().isEmpty) return null;
  return ref.watch(mobileCatalogProvider).matchPhone(raw);
});
