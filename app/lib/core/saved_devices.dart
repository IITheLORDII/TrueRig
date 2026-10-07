import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/providers.dart';

/// One saved device. [data] is kind-specific:
/// - pc: [prebuiltLabel, isLaptop ('1'/'0'), ...partIds]
/// - phone: [phoneId, socId, ramGb]
/// - watch: [watchId, pairedPhoneId]
@immutable
class SavedDevice {
  const SavedDevice({this.name, this.data = const []});

  /// User-given name ("İş laptopu"); null = derived from the hardware.
  final String? name;
  final List<String> data;

  bool get isEmpty => data.isEmpty;

  SavedDevice copyWith({String? name, List<String>? data}) =>
      SavedDevice(name: name ?? this.name, data: data ?? this.data);

  Map<String, dynamic> toJson() => {'n': name, 'd': data};

  factory SavedDevice.fromJson(Map<String, dynamic> j) => SavedDevice(
    name: j['n'] as String?,
    data: [for (final e in (j['d'] as List? ?? const [])) e.toString()],
  );
}

/// All saved devices per kind and which one is active.
@immutable
class SavedDevices {
  const SavedDevices({this.lists = const {}, this.active = const {}});

  final Map<DeviceKind, List<SavedDevice>> lists;
  final Map<DeviceKind, int> active;

  List<SavedDevice> of(DeviceKind k) => lists[k] ?? const [];
  int activeIndex(DeviceKind k) => active[k] ?? 0;

  SavedDevices withList(DeviceKind k, List<SavedDevice> list, {int? index}) =>
      SavedDevices(
        lists: {...lists, k: List.unmodifiable(list)},
        active: {...active, k: index ?? activeIndex(k)},
      );

  String encode() => jsonEncode({
    for (final k in DeviceKind.values)
      k.name: {
        'a': activeIndex(k),
        'l': [for (final d in of(k)) d.toJson()],
      },
  });

  static SavedDevices decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final lists = <DeviceKind, List<SavedDevice>>{};
    final active = <DeviceKind, int>{};
    for (final k in DeviceKind.values) {
      final e = j[k.name];
      if (e is! Map<String, dynamic>) continue;
      lists[k] = List.unmodifiable([
        for (final d in (e['l'] as List? ?? const []))
          SavedDevice.fromJson(d as Map<String, dynamic>),
      ]);
      active[k] = (e['a'] as num?)?.toInt() ?? 0;
    }
    return SavedDevices(lists: lists, active: active);
  }
}

const _savedKey = 'devices.saved';

final savedDevicesProvider =
    NotifierProvider<SavedDevicesController, SavedDevices>(
      SavedDevicesController.new,
    );

/// Keeps a list of devices per kind. The active one lives in the existing
/// providers (buildProvider, phoneSelectionProvider, watchSelectionProvider);
/// every change there is mirrored into its slot here.
class SavedDevicesController extends Notifier<SavedDevices> {
  /// True while a slot is being loaded into the live providers.
  bool _loading = false;

  @override
  SavedDevices build() {
    ref.listen(buildProvider, (_, _) => _sync(DeviceKind.pc));
    ref.listen(prebuiltProvider, (_, _) => _sync(DeviceKind.pc));
    ref.listen(phoneSelectionProvider, (_, _) => _sync(DeviceKind.phone));
    ref.listen(watchSelectionProvider, (_, _) => _sync(DeviceKind.watch));

    final raw = ref.read(prefsProvider)?.getString(_savedKey);
    var s = const SavedDevices();
    if (raw != null) {
      try {
        s = SavedDevices.decode(raw);
      } on FormatException catch (e) {
        debugPrint('Kayıtlı cihazlar okunamadı: $e');
      }
    }
    // First run / older install: adopt whatever is configured now.
    for (final k in DeviceKind.values) {
      final live = _snapshot(k);
      if (s.of(k).isEmpty && live.isNotEmpty) {
        s = s.withList(k, [SavedDevice(data: live)], index: 0);
      }
    }
    return s;
  }

  /// Display name of a saved device.
  String labelOf(DeviceKind k, int index) {
    final list = state.of(k);
    if (index >= list.length) return k.label;
    final d = list[index];
    return d.name ?? _derivedName(k, d) ?? '${k.label} ${index + 1}';
  }

  /// Saves the current one and starts an empty device of [k].
  void addNew(DeviceKind k) {
    _sync(k);
    final list = [...state.of(k), const SavedDevice()];
    _commit(state.withList(k, list, index: list.length - 1));
    _load(k, const SavedDevice());
  }

  /// Makes [index] the active device of [k].
  void switchTo(DeviceKind k, int index) {
    final list = state.of(k);
    if (index < 0 || index >= list.length) return;
    _sync(k);
    _commit(state.withList(k, state.of(k), index: index));
    _load(k, state.of(k)[index]);
  }

  void rename(DeviceKind k, int index, String name) {
    final list = [...state.of(k)];
    if (index >= list.length) return;
    final trimmed = name.trim();
    list[index] = SavedDevice(
      name: trimmed.isEmpty ? null : trimmed,
      data: list[index].data,
    );
    _commit(state.withList(k, list));
  }

  void remove(DeviceKind k, int index) {
    final list = [...state.of(k)];
    if (index >= list.length) return;
    list.removeAt(index);
    final active = state.activeIndex(k);
    final next = list.isEmpty
        ? 0
        : (active > index ? active - 1 : active.clamp(0, list.length - 1));
    _commit(state.withList(k, list, index: next));
    if (active == index || list.isEmpty) {
      _load(k, list.isEmpty ? const SavedDevice() : list[next]);
    }
  }

  void _sync(DeviceKind k) {
    if (_loading) return;
    final live = _snapshot(k);
    final list = [...state.of(k)];
    final i = state.activeIndex(k);
    if (list.isEmpty) {
      if (live.isEmpty) return;
      list.add(SavedDevice(data: live));
    } else if (i < list.length) {
      if (listEquals(list[i].data, live)) return;
      list[i] = list[i].copyWith(data: live);
    }
    _commit(state.withList(k, list, index: i.clamp(0, list.length - 1)));
  }

  List<String> _snapshot(DeviceKind k) {
    switch (k) {
      case DeviceKind.pc:
        final b = ref.read(buildProvider);
        if (b.parts.isEmpty) return const [];
        final pre = ref.read(prebuiltProvider);
        return [
          pre?.label ?? '',
          pre?.isLaptop ?? false ? '1' : '0',
          for (final p in b.parts) p.id,
        ];
      case DeviceKind.phone:
        final s = ref.read(phoneSelectionProvider);
        return s == null ? const [] : [s.phoneId, s.socId, '${s.ramGb}'];
      case DeviceKind.watch:
        final s = ref.read(watchSelectionProvider);
        return s == null ? const [] : [s.watchId, s.pairedPhoneId ?? ''];
    }
  }

  void _load(DeviceKind k, SavedDevice d) {
    _loading = true;
    try {
      switch (k) {
        case DeviceKind.pc:
          final build = pcBuildOf(d, ref.read(catalogProvider));
          final label = d.data.isEmpty ? '' : d.data[0];
          if (label.isEmpty) {
            ref.read(prebuiltProvider.notifier).clear();
            ref.read(buildProvider.notifier).replace(build);
          } else {
            ref
                .read(prebuiltProvider.notifier)
                .apply(
                  PrebuiltSelection(label: label, isLaptop: d.data[1] == '1'),
                  build,
                );
          }
        case DeviceKind.phone:
          final catalog = ref.read(mobileCatalogProvider);
          final phone = d.data.isEmpty ? null : catalog.phone(d.data[0]);
          final ctl = ref.read(phoneSelectionProvider.notifier);
          if (phone == null) {
            ctl.clear();
          } else {
            ctl.select(phone, socId: d.data[1], ramGb: int.tryParse(d.data[2]));
          }
        case DeviceKind.watch:
          final catalog = ref.read(mobileCatalogProvider);
          final watch = d.data.isEmpty ? null : catalog.watch(d.data[0]);
          final ctl = ref.read(watchSelectionProvider.notifier);
          if (watch == null) {
            ctl.clear();
          } else {
            ctl.select(watch);
            final paired = d.data.length > 1 && d.data[1].isNotEmpty
                ? catalog.phone(d.data[1])
                : null;
            ctl.pairWith(paired);
          }
      }
    } finally {
      _loading = false;
    }
  }

  void _commit(SavedDevices s) {
    state = s;
    ref.read(prefsProvider)?.setString(_savedKey, s.encode());
  }

  String? _derivedName(DeviceKind k, SavedDevice d) {
    if (d.isEmpty) return null;
    switch (k) {
      case DeviceKind.pc:
        if (d.data[0].isNotEmpty) return d.data[0].split(' · ').first;
        final b = pcBuildOf(d, ref.read(catalogProvider));
        final cpu = b.cpu;
        final gpu = b.gpu;
        if (cpu == null && gpu == null) return null;
        return [cpu?.model, gpu?.model].whereType<String>().join(' + ');
      case DeviceKind.phone:
        return ref.read(mobileCatalogProvider).phone(d.data[0])?.displayName;
      case DeviceKind.watch:
        return ref.read(mobileCatalogProvider).watch(d.data[0])?.displayName;
    }
  }
}

/// PC build stored in a saved device.
PcBuild pcBuildOf(SavedDevice d, PartCatalog catalog) {
  var b = const PcBuild();
  for (final id in d.data.skip(2)) {
    final p = catalog.byId(id);
    if (p != null) b = b.withPart(p);
  }
  return b;
}

/// Phone spec stored in a saved device.
PhoneSpec? phoneSpecOf(SavedDevice d, MobileCatalog catalog) {
  if (d.data.length < 3) return null;
  final phone = catalog.phone(d.data[0]);
  final soc = catalog.soc(d.data[1]);
  final ram = int.tryParse(d.data[2]);
  if (phone == null || soc == null || ram == null) return null;
  return PhoneSpec(phone: phone, soc: soc, ramGb: ram);
}

/// Watch stored in a saved device.
Watch? watchOf(SavedDevice d, MobileCatalog catalog) =>
    d.data.isEmpty ? null : catalog.watch(d.data[0]);
