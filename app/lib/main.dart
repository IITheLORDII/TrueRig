import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:darbogaz/app.dart';
import 'package:darbogaz/core/devices.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Saved PC build / phone / watch are restored before the first frame.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const DarbogazApp(),
    ),
  );
}
