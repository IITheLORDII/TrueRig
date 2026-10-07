import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local key-value store. Null (tests, first frame) means "don't persist".
final prefsProvider = Provider<SharedPreferences?>((ref) => null);

final mobileCatalogProvider = Provider<MobileCatalog>(
  (ref) => MobileCatalog.seed(),
);

enum DeviceKind { pc, phone, watch }

extension DeviceKindLabel on DeviceKind {
  String get label => switch (this) {
    DeviceKind.pc => 'PC',
    DeviceKind.phone => 'Telefon',
    DeviceKind.watch => 'Saat',
  };
}

const _kindKey = 'device.kind';

final activeDeviceProvider = NotifierProvider<ActiveDevice, DeviceKind>(
  ActiveDevice.new,
);

class ActiveDevice extends Notifier<DeviceKind> {
  @override
  DeviceKind build() {
    final saved = ref.read(prefsProvider)?.getString(_kindKey);
    return DeviceKind.values.firstWhere(
      (k) => k.name == saved,
      orElse: () => DeviceKind.pc,
    );
  }

  void set(DeviceKind kind) {
    state = kind;
    ref.read(prefsProvider)?.setString(_kindKey, kind.name);
  }
}

/// The user's phone: model + chip variant + RAM option.
@immutable
class PhoneSelection {
  const PhoneSelection({
    required this.phoneId,
    required this.socId,
    required this.ramGb,
  });

  final String phoneId;
  final String socId;
  final int ramGb;
}

const _phoneKey = 'phone.selection';

final phoneSelectionProvider =
    NotifierProvider<PhoneSelectionController, PhoneSelection?>(
      PhoneSelectionController.new,
    );

class PhoneSelectionController extends Notifier<PhoneSelection?> {
  @override
  PhoneSelection? build() {
    final raw = ref.read(prefsProvider)?.getStringList(_phoneKey);
    if (raw == null || raw.length != 3) return null;
    final catalog = ref.read(mobileCatalogProvider);
    final phone = catalog.phone(raw[0]);
    final ram = int.tryParse(raw[2]);
    if (phone == null || catalog.soc(raw[1]) == null || ram == null) {
      return null;
    }
    return PhoneSelection(phoneId: phone.id, socId: raw[1], ramGb: ram);
  }

  /// Selects [phone]; [socId] defaults to its regional default chip.
  void select(Phone phone, {String? socId, int? ramGb}) => _save(
    PhoneSelection(
      phoneId: phone.id,
      socId: socId ?? phone.socId,
      ramGb: ramGb ?? phone.defaultRamGb,
    ),
  );

  void setRam(int ramGb) {
    final s = state;
    if (s == null) return;
    _save(PhoneSelection(phoneId: s.phoneId, socId: s.socId, ramGb: ramGb));
  }

  void clear() {
    state = null;
    ref.read(prefsProvider)?.remove(_phoneKey);
  }

  void _save(PhoneSelection s) {
    state = s;
    ref.read(prefsProvider)?.setStringList(_phoneKey, [
      s.phoneId,
      s.socId,
      '${s.ramGb}',
    ]);
  }
}

/// Resolved phone + chip + RAM for the estimators.
final phoneSpecProvider = Provider<PhoneSpec?>((ref) {
  final s = ref.watch(phoneSelectionProvider);
  if (s == null) return null;
  final catalog = ref.watch(mobileCatalogProvider);
  final phone = catalog.phone(s.phoneId);
  final soc = catalog.soc(s.socId);
  if (phone == null || soc == null) return null;
  return PhoneSpec(phone: phone, soc: soc, ramGb: s.ramGb);
});

/// The user's watch and the phone it pairs with (null = the selected phone).
@immutable
class WatchSelection {
  const WatchSelection({required this.watchId, this.pairedPhoneId});

  final String watchId;
  final String? pairedPhoneId;
}

const _watchKey = 'watch.selection';

final watchSelectionProvider =
    NotifierProvider<WatchSelectionController, WatchSelection?>(
      WatchSelectionController.new,
    );

class WatchSelectionController extends Notifier<WatchSelection?> {
  @override
  WatchSelection? build() {
    final raw = ref.read(prefsProvider)?.getStringList(_watchKey);
    if (raw == null || raw.isEmpty) return null;
    if (ref.read(mobileCatalogProvider).watch(raw[0]) == null) return null;
    return WatchSelection(
      watchId: raw[0],
      pairedPhoneId: raw.length > 1 && raw[1].isNotEmpty ? raw[1] : null,
    );
  }

  void select(Watch watch) => _save(
    WatchSelection(watchId: watch.id, pairedPhoneId: state?.pairedPhoneId),
  );

  void pairWith(Phone? phone) {
    final s = state;
    if (s == null) return;
    _save(WatchSelection(watchId: s.watchId, pairedPhoneId: phone?.id));
  }

  void clear() {
    state = null;
    ref.read(prefsProvider)?.remove(_watchKey);
  }

  void _save(WatchSelection s) {
    state = s;
    ref.read(prefsProvider)?.setStringList(_watchKey, [
      s.watchId,
      s.pairedPhoneId ?? '',
    ]);
  }
}

/// Watch report against the explicitly paired phone or the selected phone.
final watchReportProvider = Provider<WatchReport?>((ref) {
  final s = ref.watch(watchSelectionProvider);
  if (s == null) return null;
  final catalog = ref.watch(mobileCatalogProvider);
  final watch = catalog.watch(s.watchId);
  if (watch == null) return null;
  final pairedId = s.pairedPhoneId;
  final phone = pairedId != null
      ? catalog.phone(pairedId)
      : ref.watch(phoneSpecProvider)?.phone;
  return const WatchCompatibility().check(watch, phone);
});
