import 'package:perf_engine/src/models/parts.dart';

// Generic entries cover every common chipset / size so users can always pick
// a part equivalent to theirs even when the exact model is not listed.

const _zen3 = [
  'r5-5500',
  'r5-5600',
  'r5-5600x',
  'r5-5600g',
  'r7-5700x',
  'r7-5700g',
  'r7-5800x',
  'r9-5900x',
  'r9-5950x',
  'r7-5700x3d',
  'r7-5800x3d',
];
const _zen2 = ['r5-3600', 'r7-3700x', 'r9-3900x'];
const _zen3NewBios = ['r5-5500', 'r7-5700x3d', 'r7-5800x3d', 'r7-5700x'];
const _zen5 = [
  'r5-9600',
  'r5-9600x',
  'r7-9700x',
  'r7-9800x3d',
  'r9-9900x',
  'r9-9900x3d',
  'r9-9950x',
  'r9-9950x3d',
];
const _raptor = [
  'i5-13400f',
  'i5-13600k',
  'i7-13700k',
  'i9-13900k',
  'i5-14400f',
  'i5-14600k',
  'i7-14700k',
  'i9-14900k',
];

class _Chipset {
  const _Chipset(this.socket, this.name, this.mem, this.maxSpeed, this.m2,
      this.pcie, this.price,
      {this.bios = const [], this.eAtx = false, this.memLabel = false});

  final String socket;
  final String name;
  final MemoryType mem;
  final int maxSpeed;
  final int m2;
  final int pcie;
  final double price;
  final List<String> bios;
  final bool eAtx;

  /// Add " · DDR4/DDR5" to the name (chipsets sold with both).
  final bool memLabel;
}

const _chipsets = [
  _Chipset('LGA1155', 'B75', MemoryType.ddr3, 1600, 0, 3, 50),
  _Chipset('LGA1155', 'Z77', MemoryType.ddr3, 2400, 0, 3, 70),
  _Chipset('LGA1150', 'H81', MemoryType.ddr3, 1600, 0, 2, 45),
  _Chipset('LGA1150', 'B85', MemoryType.ddr3, 1600, 0, 3, 55),
  _Chipset('LGA1150', 'Z97', MemoryType.ddr3, 3200, 1, 3, 80),
  _Chipset('AM3+', '970', MemoryType.ddr3, 2133, 0, 2, 55),
  _Chipset('LGA1151', 'B360', MemoryType.ddr4, 2666, 1, 3, 80),
  _Chipset('LGA1151', 'Z390', MemoryType.ddr4, 4266, 2, 3, 150),
  _Chipset('LGA1200', 'B560', MemoryType.ddr4, 4400, 2, 4, 110),
  _Chipset('LGA1200', 'Z590', MemoryType.ddr4, 5000, 3, 4, 180),
  _Chipset('LGA1700', 'H610', MemoryType.ddr4, 3200, 1, 4, 80,
      bios: _raptor, memLabel: true),
  _Chipset('LGA1700', 'B660', MemoryType.ddr4, 4800, 2, 4, 120,
      bios: _raptor, memLabel: true),
  _Chipset('LGA1700', 'B660', MemoryType.ddr5, 6400, 2, 4, 140,
      bios: _raptor, memLabel: true),
  _Chipset('LGA1700', 'B760', MemoryType.ddr4, 4800, 2, 4, 120, memLabel: true),
  _Chipset('LGA1700', 'B760', MemoryType.ddr5, 7200, 2, 4, 150, memLabel: true),
  _Chipset('LGA1700', 'Z690', MemoryType.ddr5, 6400, 4, 5, 220,
      bios: _raptor, memLabel: true),
  _Chipset('LGA1700', 'Z790', MemoryType.ddr4, 5000, 4, 5, 200, memLabel: true),
  _Chipset('LGA1700', 'Z790', MemoryType.ddr5, 7600, 4, 5, 230,
      eAtx: true, memLabel: true),
  _Chipset('LGA1851', 'B860', MemoryType.ddr5, 7200, 3, 5, 150),
  _Chipset('LGA1851', 'Z890', MemoryType.ddr5, 8800, 4, 5, 260, eAtx: true),
  _Chipset('AM4', 'A320', MemoryType.ddr4, 3200, 1, 3, 60,
      bios: [..._zen2, ..._zen3]),
  _Chipset('AM4', 'B450', MemoryType.ddr4, 3600, 1, 3, 80,
      bios: [..._zen2, ..._zen3]),
  _Chipset('AM4', 'X470', MemoryType.ddr4, 3600, 2, 3, 130,
      bios: [..._zen2, ..._zen3]),
  _Chipset('AM4', 'B550', MemoryType.ddr4, 4400, 2, 4, 120, bios: _zen3NewBios),
  _Chipset('AM4', 'X570', MemoryType.ddr4, 4600, 2, 4, 180, bios: _zen3NewBios),
  _Chipset('AM5', 'A620', MemoryType.ddr5, 6000, 1, 4, 100, bios: _zen5),
  _Chipset('AM5', 'B650', MemoryType.ddr5, 7200, 2, 4, 160, bios: _zen5),
  _Chipset('AM5', 'B650E', MemoryType.ddr5, 7600, 3, 5, 220, bios: _zen5),
  _Chipset('AM5', 'X670E', MemoryType.ddr5, 8000, 4, 5, 320,
      bios: _zen5, eAtx: true),
  _Chipset('AM5', 'B850', MemoryType.ddr5, 8000, 3, 5, 200),
  _Chipset('AM5', 'X870', MemoryType.ddr5, 8000, 3, 5, 280),
  _Chipset('AM5', 'X870E', MemoryType.ddr5, 8000, 4, 5, 380, eAtx: true),
];

String _ffLabel(FormFactor f) => switch (f) {
      FormFactor.miniItx => 'Mini-ITX',
      FormFactor.microAtx => 'mATX',
      FormFactor.atx => 'ATX',
      FormFactor.eAtx => 'E-ATX',
    };

final List<Motherboard> kGenericBoards = List.unmodifiable([
  for (final c in _chipsets)
    for (final ff in [
      FormFactor.atx,
      FormFactor.microAtx,
      FormFactor.miniItx,
      if (c.eAtx) FormFactor.eAtx,
    ])
      Motherboard(
        id: 'mb-${c.name.toLowerCase()}-${ff.name.toLowerCase()}'
            '${c.memLabel ? '-${c.mem.name}' : ''}',
        brand: 'Genel',
        model: '${c.name} · ${_ffLabel(ff)}'
            '${c.memLabel ? ' · ${c.mem.name.toUpperCase()}' : ''}',
        refPriceUsd: c.price + (ff == FormFactor.miniItx ? 40 : 0),
        socket: c.socket,
        chipset: c.name,
        formFactor: ff,
        memoryType: c.mem,
        memSlots: ff == FormFactor.miniItx ? 2 : 4,
        maxMemSpeed: c.maxSpeed,
        m2Slots: ff == FormFactor.miniItx ? 2 : c.m2,
        pcieGen: c.pcie,
        biosUpdateRequiredFor: c.bios,
      ),
]);

Ram _kit(MemoryType type, int speed, int count, int size, RamFormFactor ff) {
  final so = ff == RamFormFactor.sodimm;
  final perGb = switch (type) {
    MemoryType.ddr5 => 3.2,
    MemoryType.ddr4 => 2.2,
    MemoryType.ddr3 => 1.6,
  };
  return Ram(
    id: 'ram-${so ? 'so-' : ''}${type.name}-$speed-${count}x$size',
    brand: 'Genel',
    model: '${count * size}GB (${count}x$size) '
        '${type.name.toUpperCase()}-$speed${so ? ' SO-DIMM' : ''}',
    refPriceUsd: perGb * count * size,
    type: type,
    speedMts: speed,
    moduleCount: count,
    moduleSizeGb: size,
    casLatency: switch (type) {
      MemoryType.ddr5 => speed >= 6000 ? 30 : 40,
      MemoryType.ddr4 => so ? 22 : 16,
      MemoryType.ddr3 => 11,
    },
    formFactor: ff,
  );
}

/// Desktop (DIMM) and laptop (SO-DIMM) kits for every common size / speed.
final List<Ram> kGenericRams = List.unmodifiable([
  for (final (type, speeds, kits, ff) in [
    (
      MemoryType.ddr3,
      [1600],
      [(1, 4), (2, 4), (1, 8), (2, 8)],
      RamFormFactor.dimm,
    ),
    (
      MemoryType.ddr4,
      [2666, 3200, 3600],
      [(1, 8), (2, 8), (1, 16), (2, 16), (2, 32)],
      RamFormFactor.dimm,
    ),
    (
      MemoryType.ddr5,
      [4800, 5600, 6000, 6400, 7200],
      [(2, 8), (1, 16), (2, 16), (2, 24), (2, 32), (2, 48)],
      RamFormFactor.dimm,
    ),
    (
      MemoryType.ddr3,
      [1600],
      [(1, 4), (2, 4), (1, 8), (2, 8)],
      RamFormFactor.sodimm,
    ),
    (
      MemoryType.ddr4,
      [2666, 3200],
      [(1, 8), (2, 8), (1, 16), (2, 16), (2, 32)],
      RamFormFactor.sodimm,
    ),
    (
      MemoryType.ddr5,
      [4800, 5600, 6400],
      [(1, 8), (2, 8), (1, 16), (2, 16), (2, 32)],
      RamFormFactor.sodimm,
    ),
  ])
    for (final speed in speeds)
      for (final (count, size) in kits) _kit(type, speed, count, size, ff),
]);

final List<Psu> kGenericPsus = List.unmodifiable([
  for (final watts in [450, 550, 650, 750, 850, 1000, 1200, 1600])
    for (final gold in [false, true])
      if (!(watts >= 1200 && !gold))
        Psu(
          id: 'psu-$watts-${gold ? 'gold' : 'bronze'}',
          brand: 'Genel',
          model: '$watts W 80+ ${gold ? 'Gold' : 'Bronze'}'
              '${gold && watts >= 750 ? ' (ATX 3.1)' : ''}',
          refPriceUsd: watts * (gold ? 0.13 : 0.1),
          watts: watts,
          rating: '80+ ${gold ? 'Gold' : 'Bronze'}',
          has12vhpwr: gold && watts >= 750,
        ),
]);

const List<PcCase> kGenericCases = [
  PcCase(
      id: 'case-itx-sff',
      brand: 'Genel',
      model: 'Mini-ITX küçük kasa (SFF)',
      refPriceUsd: 90,
      supportedFormFactors: [FormFactor.miniItx],
      maxGpuLengthMm: 300,
      maxCoolerHeightMm: 70),
  PcCase(
      id: 'case-itx',
      brand: 'Genel',
      model: 'Mini-ITX kasa',
      refPriceUsd: 80,
      supportedFormFactors: [FormFactor.miniItx],
      maxGpuLengthMm: 330,
      maxCoolerHeightMm: 150),
  PcCase(
      id: 'case-matx',
      brand: 'Genel',
      model: 'Micro-ATX kasa',
      refPriceUsd: 60,
      supportedFormFactors: [FormFactor.miniItx, FormFactor.microAtx],
      maxGpuLengthMm: 320,
      maxCoolerHeightMm: 160),
  PcCase(
      id: 'case-atx-mid',
      brand: 'Genel',
      model: 'ATX orta kule',
      refPriceUsd: 80,
      supportedFormFactors: [
        FormFactor.miniItx,
        FormFactor.microAtx,
        FormFactor.atx
      ],
      maxGpuLengthMm: 360,
      maxCoolerHeightMm: 165),
  PcCase(
      id: 'case-atx-full',
      brand: 'Genel',
      model: 'ATX büyük kule',
      refPriceUsd: 140,
      supportedFormFactors: [
        FormFactor.miniItx,
        FormFactor.microAtx,
        FormFactor.atx,
        FormFactor.eAtx
      ],
      maxGpuLengthMm: 420,
      maxCoolerHeightMm: 185),
];

const _allSockets = ['AM4', 'AM5', 'LGA1151', 'LGA1200', 'LGA1700', 'LGA1851'];

const List<Cooler> kGenericCoolers = [
  Cooler(
      id: 'cooler-stock-amd',
      brand: 'Genel',
      model: 'Kutudan çıkan (AMD Wraith Prism)',
      refPriceUsd: 0,
      sockets: ['AM4', 'AM5'],
      heightMm: 93,
      tdpRatingW: 105),
  Cooler(
      id: 'cooler-stock-intel',
      brand: 'Genel',
      model: 'Kutudan çıkan (Intel)',
      refPriceUsd: 0,
      sockets: ['LGA1151', 'LGA1200', 'LGA1700', 'LGA1851'],
      heightMm: 47,
      tdpRatingW: 65),
  Cooler(
      id: 'cooler-lowprofile',
      brand: 'Genel',
      model: 'Low-profile hava soğutucu',
      refPriceUsd: 45,
      sockets: _allSockets,
      heightMm: 70,
      tdpRatingW: 120),
  Cooler(
      id: 'cooler-tower-120',
      brand: 'Genel',
      model: 'Tek kule hava 120 mm',
      refPriceUsd: 30,
      sockets: _allSockets,
      heightMm: 155,
      tdpRatingW: 180),
  Cooler(
      id: 'cooler-dual-tower',
      brand: 'Genel',
      model: 'Çift kule hava soğutucu',
      refPriceUsd: 60,
      sockets: _allSockets,
      heightMm: 160,
      tdpRatingW: 250),
  Cooler(
      id: 'cooler-aio-240',
      brand: 'Genel',
      model: '240 mm sıvı soğutma (AIO)',
      refPriceUsd: 80,
      sockets: _allSockets,
      heightMm: 0,
      tdpRatingW: 250,
      isLiquid: true),
  Cooler(
      id: 'cooler-aio-360',
      brand: 'Genel',
      model: '360 mm sıvı soğutma (AIO)',
      refPriceUsd: 110,
      sockets: _allSockets,
      heightMm: 0,
      tdpRatingW: 320,
      isLiquid: true),
];
