import 'package:perf_engine/perf_engine.dart';

/// Not running in a browser: nothing to probe.
bool get canProbeBrowser => false;

HardwareReport? probeBrowser() => null;

double? browserDeviceMemoryGb() => null;

/// Phone model code from the browser (Android Chrome UA-CH). Null off-web.
Future<String?> browserPhoneModel() async => null;
