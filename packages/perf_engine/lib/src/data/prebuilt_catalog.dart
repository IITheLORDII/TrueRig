import 'package:perf_engine/src/models/prebuilt.dart';

part 'prebuilt_laptops_tr.dart';
part 'prebuilt_laptops_global.dart';
part 'prebuilt_office_desktop.dart';

// Ready-made laptops and desktops with their factory configurations from
// every generation we know of (2018 onwards). Years are the year a
// configuration came out. RAM ids point to generic kits in
// platform_generic.dart; configurations are the common retail ones, not
// every regional SKU.

const _d4s8 = 'ram-ddr4-2666-1x8';
const _d4o16 = 'ram-ddr4-2666-2x8';
const _d4x8 = 'ram-ddr4-3200-1x8';
const _d4x16 = 'ram-ddr4-3200-2x8';
const _d4x32 = 'ram-ddr4-3200-2x16';
const _d5x16 = 'ram-ddr5-4800-2x8';
const _d5x32 = 'ram-ddr5-4800-2x16';
const _d5x16f = 'ram-ddr5-5600-2x8';
const _d5x32f = 'ram-ddr5-5600-2x16';
const _d5x64f = 'ram-ddr5-5600-2x32';

PrebuiltVariant _v(int year, String cpu, String gpu, String ram,
        [String? code]) =>
    PrebuiltVariant(cpuId: cpu, gpuId: gpu, ramId: ram, year: year, code: code);

/// Laptops use SO-DIMM modules: 'ram-ddr4-…' becomes 'ram-so-ddr4-…'.
PrebuiltVariant _soDimm(PrebuiltVariant v) => PrebuiltVariant(
      cpuId: v.cpuId,
      gpuId: v.gpuId,
      ramId: v.ramId.replaceFirst('ram-', 'ram-so-'),
      year: v.year,
      code: v.code,
    );

PrebuiltSystem _laptop(
        String id, String brand, String model, List<PrebuiltVariant> variants,
        {List<String> aliases = const []}) =>
    PrebuiltSystem(
      id: id,
      brand: brand,
      model: model,
      isLaptop: true,
      variants: [for (final v in variants) _soDimm(v)],
      aliases: aliases,
    );

PrebuiltSystem _desktop(
        String id, String brand, String model, List<PrebuiltVariant> variants,
        {List<String> aliases = const []}) =>
    PrebuiltSystem(
      id: id,
      brand: brand,
      model: model,
      isLaptop: false,
      variants: variants,
      aliases: aliases,
    );

final List<PrebuiltSystem> kPrebuilts = List.unmodifiable([
  ..._turkishLaptops,
  ..._globalLaptops,
  ..._officeLaptops,
  ..._desktops,
]);
