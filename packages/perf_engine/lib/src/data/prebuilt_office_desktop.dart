part of 'prebuilt_catalog.dart';

// Everyday laptops (integrated or entry graphics).
final List<PrebuiltSystem> _officeLaptops = [
  _laptop('casper-nirvana', 'Casper', 'Nirvana X / C serisi', [
    _v(2019, 'i5-8250u', 'uhd-620-igpu', _d4s8, 'X500'),
    _v(2020, 'i5-10210u', 'uhd-620-igpu', _d4s8, 'C600'),
    _v(2021, 'i5-1135g7', 'iris-xe-igpu', _d4x8, 'X600'),
    _v(2022, 'i5-1235u', 'iris-xe-igpu', _d4x16, 'X600'),
    _v(2022, 'i7-1255u', 'iris-xe-igpu', _d4x16, 'X700'),
  ]),
  _laptop('lenovo-ideapad', 'Lenovo', 'IdeaPad 3 / 5 / Slim', [
    _v(2019, 'i5-8250u', 'uhd-620-igpu', _d4s8, '330'),
    _v(2020, 'i5-10210u', 'uhd-620-igpu', _d4s8, '3 15IIL05'),
    _v(2021, 'r5-5500u', 'vega8-igpu', _d4x8, '3 15ALC6'),
    _v(2021, 'i5-1135g7', 'iris-xe-igpu', _d4x8, '5 15ITL05'),
    _v(2022, 'i5-1235u', 'iris-xe-igpu', _d4x16, '3 15IAU7'),
    _v(2023, 'r7-7730u', 'vega8-igpu', _d4x16, 'Slim 3 15ABR8'),
    _v(2024, 'r7-8845hs', 'radeon-780m-igpu', _d5x16f, 'Slim 5 14AHP9'),
  ]),
  _laptop('lenovo-thinkpad-e', 'Lenovo', 'ThinkPad E14 / E15', [
    _v(2020, 'i5-10210u', 'uhd-620-igpu', _d4s8, 'Gen 1'),
    _v(2021, 'i5-1135g7', 'iris-xe-igpu', _d4x8, 'Gen 2'),
    _v(2022, 'i5-1235u', 'iris-xe-igpu', _d4x16, 'Gen 4'),
    _v(2023, 'r7-7730u', 'vega8-igpu', _d4x16, 'Gen 5 AMD'),
  ]),
  _laptop('hp-15s-250', 'HP', '15s / 250 / Pavilion 15', [
    _v(2020, 'i5-10210u', 'uhd-620-igpu', _d4s8, '250 G7'),
    _v(2021, 'i5-1135g7', 'iris-xe-igpu', _d4x8, '15s-fq2'),
    _v(2021, 'r5-5500u', 'vega8-igpu', _d4x8, '15s-eq2'),
    _v(2022, 'i5-1235u', 'iris-xe-igpu', _d4x16, '250 G9'),
    _v(2022, 'i5-1235u', 'mx550-laptop', _d4x16, 'Pavilion 15-eg2'),
  ]),
  _laptop('dell-inspiron-vostro', 'Dell', 'Inspiron / Vostro 15', [
    _v(2020, 'i5-10210u', 'uhd-620-igpu', _d4s8, 'Inspiron 3501'),
    _v(2021, 'i5-1135g7', 'iris-xe-igpu', _d4x8, 'Inspiron 3511'),
    _v(2021, 'i5-1135g7', 'mx450-laptop', _d4x8, 'Vostro 5510'),
    _v(2022, 'i5-1235u', 'iris-xe-igpu', _d4x16, 'Inspiron 3520'),
    _v(2023, 'r5-7530u', 'vega8-igpu', _d4x16, 'Inspiron 3535'),
  ]),
  _laptop('asus-vivobook', 'ASUS', 'Vivobook 15 / 16', [
    _v(2020, 'i5-10210u', 'uhd-620-igpu', _d4s8, 'X512'),
    _v(2021, 'i5-1135g7', 'iris-xe-igpu', _d4x8, 'X515EA'),
    _v(2021, 'i5-1135g7', 'mx450-laptop', _d4x8, 'K513EQ'),
    _v(2022, 'i5-1235u', 'iris-xe-igpu', _d4x16, 'X1502ZA'),
    _v(2023, 'r5-7530u', 'vega8-igpu', _d4x16, 'M1502YA'),
    _v(2024, 'cu5-125h', 'arc-igpu', _d5x16f, 'S5406MA'),
  ]),
  _laptop('acer-aspire', 'Acer', 'Aspire 3 / 5 / 7', [
    _v(2019, 'i5-8250u', 'uhd-620-igpu', _d4s8, 'A315-53'),
    _v(2021, 'i5-1135g7', 'mx450-laptop', _d4x8, 'A515-56G'),
    _v(2021, 'r5-5500u', 'vega8-igpu', _d4x8, 'A315-43'),
    _v(2022, 'i5-1235u', 'mx550-laptop', _d4x16, 'A515-57G'),
    _v(2022, 'i5-12450h', 'rtx-3050-laptop', _d4x16, 'A715-51G'),
    _v(2023, 'r7-7730u', 'vega8-igpu', _d4x16, 'A315-44P'),
  ]),
  _laptop(
      'thin-light-ai',
      'Çeşitli',
      'Yeni nesil ince laptop (Core Ultra / '
          'Ryzen AI)',
      [
        _v(2024, 'cu7-155h', 'arc-igpu', _d5x16f),
        _v(2024, 'r9-8945hs', 'radeon-780m-igpu', _d5x32f),
        _v(2024, 'cu7-258v', 'arc-140v-igpu', _d5x32f),
        _v(2024, 'ryzen-ai-9-hx-370', 'radeon-890m-igpu', _d5x32f),
      ],
      aliases: [
        'Zenbook',
        'Yoga',
        'Swift',
        'XPS',
      ]),
];

// Brand desktops (store-built PCs are filled from the listing title).
final List<PrebuiltSystem> _desktops = [
  _desktop('hp-omen-desktop', 'HP', 'Omen 25L / 30L / 40L / 45L', [
    _v(2020, 'i5-10400', 'gtx-1660s', _d4x16, '25L'),
    _v(2020, 'i7-10700k', 'rtx-3080', _d4x32, '30L'),
    _v(2021, 'r7-5800x', 'rtx-3070', _d4x16, '25L'),
    _v(2022, 'i7-12700k', 'rtx-3070ti', _d5x16, '40L'),
    _v(2023, 'i7-13700k', 'rtx-4070', _d5x32, '40L'),
    _v(2023, 'i9-13900k', 'rtx-4090', _d5x32f, '45L'),
    _v(2024, 'r7-7800x3d', 'rtx-4070s', _d5x32f, '35L'),
  ]),
  _desktop('lenovo-legion-tower', 'Lenovo', 'Legion Tower 5 / 7', [
    _v(2021, 'r5-5600g', 'rtx-3060-12', _d4x16, 'T5 26ACH6'),
    _v(2021, 'r7-5800x', 'rtx-3070', _d4x16, 'T5 26AMR5'),
    _v(2023, 'i7-13700k', 'rtx-4060ti', _d5x16f, 'Tower 5i Gen 8'),
    _v(2023, 'i9-13900k', 'rtx-4080', _d5x32f, 'Tower 7i Gen 8'),
    _v(2024, 'i9-14900k', 'rtx-4080s', _d5x32f, 'Tower 7i Gen 9'),
  ]),
  _desktop('dell-alienware-aurora', 'Dell', 'Alienware Aurora', [
    _v(2019, 'i7-9700k', 'rtx-2070s', _d4x16, 'R9'),
    _v(2020, 'r7-3700x', 'rtx-2060s', _d4x16, 'R10'),
    _v(2020, 'i7-10700k', 'rtx-3070', _d4x16, 'R11'),
    _v(2021, 'i7-11700k', 'rtx-3080', _d4x32, 'R12'),
    _v(2022, 'i7-12700k', 'rtx-3080', _d5x32, 'R13'),
    _v(2023, 'i7-13700k', 'rtx-4070ti', _d5x32f, 'R15'),
    _v(2023, 'i9-13900k', 'rtx-4090', _d5x32f, 'R15'),
    _v(2024, 'i7-14700k', 'rtx-4070s', _d5x32f, 'R16'),
    _v(2024, 'i9-14900k', 'rtx-4090', _d5x64f, 'R16'),
  ]),
  _desktop('msi-desktop', 'MSI', 'Codex / Aegis / Infinite', [
    _v(2021, 'i5-11400f', 'rtx-3060-12', _d4x16, 'Codex R'),
    _v(2022, 'i7-12700k', 'rtx-3070ti', _d4x32, 'Aegis RS'),
    _v(2023, 'i5-13400f', 'rtx-4060', _d4x16, 'Codex R2'),
    _v(2024, 'i5-14400f', 'rtx-4060ti', _d5x16f, 'Infinite S3'),
    _v(2024, 'i7-14700k', 'rtx-4070s', _d5x32f, 'Aegis R2'),
  ]),
  _desktop('asus-rog-desktop', 'ASUS', 'ROG Strix G10 / G13 / G16CH', [
    _v(2020, 'i5-10400', 'gtx-1660s', _d4x16, 'G10DK'),
    _v(2021, 'r7-5800x', 'rtx-3060ti', _d4x16, 'G10DK'),
    _v(2023, 'i7-13700k', 'rtx-4070', _d5x32f, 'G16CH'),
    _v(2024, 'i7-14700k', 'rtx-4070s', _d5x32f, 'G16CHR'),
  ]),
];
