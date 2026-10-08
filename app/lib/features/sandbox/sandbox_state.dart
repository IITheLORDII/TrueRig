import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/devices.dart';

/// A PC in the scratch area: the build and, if it came from a ready-made
/// system, its name.
@immutable
class SandboxPc {
  const SandboxPc({this.label, this.build = const PcBuild()});

  final String? label;
  final PcBuild build;

  bool get isReady => build.cpu != null && build.gpu != null;

  String? get name {
    if (label != null) return label;
    final cpu = build.cpu;
    final gpu = build.gpu;
    if (cpu == null && gpu == null) return null;
    return [cpu?.model, gpu?.model].whereType<String>().join(' + ');
  }
}

/// "Kaydetmeden dene": two slots (A = main, B = compared) per device kind.
/// Lives in memory only — nothing is written to preferences, so it is gone
/// when the app closes and never touches the user's own devices.
@immutable
class SandboxState {
  const SandboxState({
    this.kind = DeviceKind.pc,
    this.comparing = false,
    this.pcs = const [SandboxPc(), SandboxPc()],
    this.phones = const [null, null],
    this.watches = const [null, null],
  });

  final DeviceKind kind;
  final bool comparing;
  final List<SandboxPc> pcs;
  final List<Phone?> phones;
  final List<Watch?> watches;

  SandboxState copyWith({
    DeviceKind? kind,
    bool? comparing,
    List<SandboxPc>? pcs,
    List<Phone?>? phones,
    List<Watch?>? watches,
  }) => SandboxState(
    kind: kind ?? this.kind,
    comparing: comparing ?? this.comparing,
    pcs: pcs ?? this.pcs,
    phones: phones ?? this.phones,
    watches: watches ?? this.watches,
  );
}

final sandboxProvider = NotifierProvider<SandboxController, SandboxState>(
  SandboxController.new,
);

class SandboxController extends Notifier<SandboxState> {
  @override
  SandboxState build() => const SandboxState();

  void setKind(DeviceKind k) => state = state.copyWith(kind: k);

  void setComparing(bool on) => state = state.copyWith(comparing: on);

  void setPc(int slot, SandboxPc pc) =>
      state = state.copyWith(pcs: _replace(state.pcs, slot, pc));

  /// Hand-picked part: the build is no longer the ready-made system.
  void setPart(int slot, Part part) {
    final pc = state.pcs[slot];
    setPc(slot, SandboxPc(build: pc.build.withPart(part)));
  }

  void clearPart(int slot, PartCategory category) {
    final pc = state.pcs[slot];
    setPc(slot, SandboxPc(build: pc.build.without(category)));
  }

  void setPhone(int slot, Phone? phone) =>
      state = state.copyWith(phones: _replace(state.phones, slot, phone));

  void setWatch(int slot, Watch? watch) =>
      state = state.copyWith(watches: _replace(state.watches, slot, watch));

  void clear() => state = SandboxState(kind: state.kind);

  static List<T> _replace<T>(List<T> list, int i, T value) =>
      List.unmodifiable([...list]..[i] = value);
}
