import 'package:flutter/material.dart';
import 'package:perf_engine/perf_engine.dart';

extension PartCategoryUi on PartCategory {
  String get label => switch (this) {
    PartCategory.cpu => 'İşlemci',
    PartCategory.gpu => 'Ekran Kartı',
    PartCategory.motherboard => 'Anakart',
    PartCategory.ram => 'RAM',
    PartCategory.psu => 'Güç Kaynağı',
    PartCategory.pcCase => 'Kasa',
    PartCategory.cooler => 'Soğutucu',
  };

  IconData get icon => switch (this) {
    PartCategory.cpu => Icons.memory_rounded,
    PartCategory.gpu => Icons.videogame_asset_rounded,
    PartCategory.motherboard => Icons.developer_board_rounded,
    PartCategory.ram => Icons.view_week_rounded,
    PartCategory.psu => Icons.bolt_rounded,
    PartCategory.pcCase => Icons.dns_rounded,
    PartCategory.cooler => Icons.ac_unit_rounded,
  };
}

/// One-line spec summary shown under a part name.
String partSubtitle(Part p) => switch (p) {
  Cpu c =>
    '${c.socket} · ${c.cores}C/${c.threads}T · '
        '${c.boostGhz.toStringAsFixed(1)} GHz · ${c.tdpW} W',
  Gpu g =>
    '${g.vramGb} GB · ${g.tdpW} W'
        '${g.lengthMm > 0 ? ' · ${g.lengthMm} mm' : ' · dizüstü'}',
  Motherboard m =>
    '${m.socket} · ${m.chipset} · '
        '${m.memoryType.name.toUpperCase()} · ${_ff(m.formFactor)}',
  Ram r =>
    '${r.totalGb} GB · ${r.type.name.toUpperCase()}-${r.speedMts} · '
        '${switch (r.formFactor) {
          RamFormFactor.dimm => 'Masaüstü (DIMM)',
          RamFormFactor.sodimm => 'Dizüstü (SO-DIMM)',
          RamFormFactor.soldered => 'Lehimli',
        }}${r.casLatency > 0 ? ' · CL${r.casLatency}' : ''}',
  Psu s => '${s.watts} W · ${s.rating}${s.has12vhpwr ? ' · 12V-2x6' : ''}',
  PcCase c =>
    'GPU ≤ ${c.maxGpuLengthMm} mm · '
        'Soğutucu ≤ ${c.maxCoolerHeightMm} mm',
  Cooler c =>
    c.isLiquid
        ? 'Sıvı · ${c.tdpRatingW} W'
        : 'Hava · ${c.heightMm} mm · ${c.tdpRatingW} W',
  _ => '',
};

String _ff(FormFactor f) => switch (f) {
  FormFactor.miniItx => 'Mini-ITX',
  FormFactor.microAtx => 'mATX',
  FormFactor.atx => 'ATX',
  FormFactor.eAtx => 'E-ATX',
};
