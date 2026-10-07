import 'package:perf_engine/src/models/prebuilt.dart';

// Popular ready-made gaming laptops in Turkey with their common factory
// configurations. RAM ids point to generic kits in platform_generic.dart.

const _d4x16 = 'ram-ddr4-3200-2x8';
const _d4x32 = 'ram-ddr4-3200-2x16';
const _d5x16 = 'ram-ddr5-4800-2x8';
const _d5x32 = 'ram-ddr5-4800-2x16';
const _d5x16f = 'ram-ddr5-5600-2x8';
const _d5x32f = 'ram-ddr5-5600-2x16';

PrebuiltVariant _v(String cpu, String gpu, String ram, [String? code]) =>
    PrebuiltVariant(cpuId: cpu, gpuId: gpu, ramId: ram, code: code);

PrebuiltSystem _laptop(
        String id, String brand, String model, List<PrebuiltVariant> variants,
        {List<String> aliases = const []}) =>
    PrebuiltSystem(
      id: id,
      brand: brand,
      model: model,
      isLaptop: true,
      variants: variants,
      aliases: aliases,
    );

final List<PrebuiltSystem> kPrebuilts = List.unmodifiable([
  // ---- Casper ----
  _laptop('casper-g770', 'Casper', 'Excalibur G770', [
    _v('i5-12450h', 'rtx-3050-laptop', _d4x16, 'G770.1245'),
    _v('i5-12450h', 'rtx-4050-laptop', _d4x16),
    _v('i7-12700h', 'rtx-3060-laptop', _d4x16, 'G770.1270'),
    _v('i7-12700h', 'rtx-4060-laptop', _d4x16),
    _v('i7-13700h', 'rtx-4060-laptop', _d4x32, 'G770.1370'),
  ]),
  _laptop('casper-g870', 'Casper', 'Excalibur G870', [
    _v('i7-12700h', 'rtx-4060-laptop', _d4x16, 'G870.1270'),
    _v('i7-13700h', 'rtx-4060-laptop', _d5x16, 'G870.1370'),
    _v('i7-13700h', 'rtx-4070-laptop', _d5x32),
  ]),
  _laptop('casper-g911', 'Casper', 'Excalibur G911', [
    _v('i7-13700h', 'rtx-4070-laptop', _d5x32, 'G911.1370'),
    _v('i9-13900hx', 'rtx-4080-laptop', _d5x32),
  ]),
  // ---- Monster ----
  _laptop('monster-abra-a5', 'Monster', 'Abra A5', [
    _v('i5-12500h', 'rtx-3050-laptop', _d4x16),
    _v('i5-13420h', 'rtx-4050-laptop', _d4x16),
    _v('i7-13700h', 'rtx-4060-laptop', _d5x16),
  ]),
  _laptop('monster-abra-a7', 'Monster', 'Abra A7', [
    _v('i7-12650h', 'rtx-4060-laptop', _d4x16),
    _v('i7-13700h', 'rtx-4060-laptop', _d5x16),
  ]),
  _laptop('monster-tulpar-t5', 'Monster', 'Tulpar T5', [
    _v('i7-13700h', 'rtx-4060-laptop', _d5x16),
    _v('i7-13700h', 'rtx-4070-laptop', _d5x32),
  ]),
  _laptop('monster-tulpar-t7', 'Monster', 'Tulpar T7', [
    _v('i9-13900hx', 'rtx-4070-laptop', _d5x32),
    _v('i9-13900hx', 'rtx-4080-laptop', _d5x32),
  ]),
  _laptop('monster-semruk-s7', 'Monster', 'Semruk S7', [
    _v('i9-13900hx', 'rtx-4080-laptop', _d5x32),
    _v('i9-14900hx', 'rtx-4090-laptop', _d5x32f),
  ]),
  // ---- ASUS ----
  _laptop('asus-tuf-f15', 'ASUS', 'TUF Gaming F15', [
    _v('i5-12500h', 'rtx-3050-laptop', _d4x16),
    _v('i5-12500h', 'rtx-4050-laptop', _d4x16),
    _v('i7-12700h', 'rtx-4060-laptop', _d4x16),
  ], aliases: [
    'FX507'
  ]),
  _laptop('asus-tuf-a15', 'ASUS', 'TUF Gaming A15', [
    _v('r7-7735hs', 'rtx-4050-laptop', _d5x16),
    _v('r7-7735hs', 'rtx-4060-laptop', _d5x16),
  ], aliases: [
    'FA507'
  ]),
  _laptop('asus-rog-strix-g16', 'ASUS', 'ROG Strix G16', [
    _v('i7-13650hx', 'rtx-4060-laptop', _d5x16),
    _v('i7-14650hx', 'rtx-4070-laptop', _d5x16f),
    _v('i9-14900hx', 'rtx-4080-laptop', _d5x32f),
  ], aliases: [
    'G614'
  ]),
  _laptop('asus-rog-zephyrus-g14', 'ASUS', 'ROG Zephyrus G14', [
    _v('r9-8945hs', 'rtx-4060-laptop', _d5x16f),
    _v('r9-8945hs', 'rtx-4070-laptop', _d5x32f),
  ], aliases: [
    'GA403'
  ]),
  // ---- Lenovo ----
  _laptop('lenovo-loq-15', 'Lenovo', 'LOQ 15', [
    _v('i5-12450h', 'rtx-3050-laptop', _d5x16),
    _v('i5-12450h', 'rtx-4050-laptop', _d5x16),
    _v('i7-13620h', 'rtx-4060-laptop', _d5x16),
  ], aliases: [
    '15IRH8',
    '15IAX9'
  ]),
  _laptop('lenovo-legion-5', 'Lenovo', 'Legion 5', [
    _v('r7-7735hs', 'rtx-4060-laptop', _d5x16),
    _v('r7-6800h', 'rtx-3060-laptop', _d5x16),
  ]),
  _laptop('lenovo-legion-pro-5', 'Lenovo', 'Legion Pro 5', [
    _v('i7-13650hx', 'rtx-4060-laptop', _d5x16f),
    _v('i7-14650hx', 'rtx-4070-laptop', _d5x32f),
  ]),
  _laptop('lenovo-legion-pro-7', 'Lenovo', 'Legion Pro 7', [
    _v('i9-14900hx', 'rtx-4080-laptop', _d5x32f),
    _v('i9-14900hx', 'rtx-4090-laptop', _d5x32f),
  ]),
  // ---- MSI ----
  _laptop('msi-thin-gf63', 'MSI', 'Thin GF63', [
    _v('i5-12450h', 'rtx-3050-laptop', _d4x16),
    _v('i5-12450h', 'rtx-4050-laptop', _d4x16),
  ]),
  _laptop('msi-cyborg-15', 'MSI', 'Cyborg 15', [
    _v('i5-12450h', 'rtx-4050-laptop', _d5x16),
    _v('i7-12650h', 'rtx-4060-laptop', _d5x16),
  ]),
  _laptop('msi-katana-15', 'MSI', 'Katana 15', [
    _v('i7-12650h', 'rtx-4050-laptop', _d5x16),
    _v('i7-13620h', 'rtx-4060-laptop', _d5x16),
    _v('i7-13620h', 'rtx-4070-laptop', _d5x16),
  ]),
  // ---- HP ----
  _laptop('hp-victus-15', 'HP', 'Victus 15', [
    _v('i5-12500h', 'rtx-3050-laptop', _d4x16),
    _v('r5-7535hs', 'rtx-4050-laptop', _d5x16),
  ]),
  _laptop('hp-victus-16', 'HP', 'Victus 16', [
    _v('i7-13700h', 'rtx-4060-laptop', _d5x16),
    _v('r7-7840hs', 'rtx-4060-laptop', _d5x16),
  ]),
  _laptop('hp-omen-16', 'HP', 'Omen 16', [
    _v('i7-13700h', 'rtx-4060-laptop', _d5x16),
    _v('i7-14650hx', 'rtx-4070-laptop', _d5x32f),
  ]),
  // ---- Acer ----
  _laptop('acer-nitro-5', 'Acer', 'Nitro 5', [
    _v('i5-12500h', 'rtx-3050-laptop', _d4x16),
    _v('i5-12500h', 'rtx-4050-laptop', _d4x16),
    _v('i7-12650h', 'rtx-4060-laptop', _d4x16),
  ], aliases: [
    'AN515'
  ]),
  _laptop('acer-nitro-v15', 'Acer', 'Nitro V 15', [
    _v('i5-13420h', 'rtx-3050-laptop', _d5x16),
    _v('i5-13420h', 'rtx-4050-laptop', _d5x16),
    _v('i7-13620h', 'rtx-4060-laptop', _d5x16),
  ], aliases: [
    'ANV15'
  ]),
  _laptop('acer-predator-helios-neo-16', 'Acer', 'Predator Helios Neo 16', [
    _v('i7-13700hx', 'rtx-4060-laptop', _d5x16),
    _v('i7-14650hx', 'rtx-4070-laptop', _d5x32f),
  ], aliases: [
    'PHN16'
  ]),
  // ---- Dell ----
  _laptop('dell-g15', 'Dell', 'G15', [
    _v('i5-13450hx', 'rtx-3050-laptop', _d5x16),
    _v('i7-13650hx', 'rtx-4060-laptop', _d5x16),
  ], aliases: [
    '5530',
    '5535'
  ]),
  _laptop('dell-alienware-m16', 'Dell', 'Alienware m16', [
    _v('cu7-155h', 'rtx-4060-laptop', _d5x16f),
    _v('cu7-155h', 'rtx-4070-laptop', _d5x32f),
  ]),
]);
