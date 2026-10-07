import 'package:flutter/foundation.dart';

/// True for the Google Play / App Store builds (not the website). Only used
/// for features that cannot work on a phone, like reading PC hardware.
bool get isStoreApp =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
