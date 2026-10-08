import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

/// Phone list with search and brand filter.
/// [mode]: 'pair' (watch's phone) or 'compare' pops with the chosen phone
/// instead of changing the user's own phone.
class PhonePickerPage extends ConsumerStatefulWidget {
  const PhonePickerPage({super.key, this.mode});

  final String? mode;

  bool get returnsPhone => mode == 'pair' || mode == 'compare';

  @override
  ConsumerState<PhonePickerPage> createState() => _PhonePickerPageState();
}

class _PhonePickerPageState extends ConsumerState<PhonePickerPage> {
  String _query = '';
  String? _brand;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(mobileCatalogProvider);
    final phones = catalog.searchPhones(_query, brand: _brand);
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        actions: const [HomeButton()],
        title: BrandTitle(switch (widget.mode) {
          'pair' => 'Saatin telefonu',
          'compare' => 'Karşılaştırılacak telefon',
          _ => 'Telefon seç',
        }),
      ),
      body: Column(
        children: [
          _SearchField(
            hint: 'Model ara (ör. iPhone 15, S24, Redmi Note 13)',
            onChanged: (v) => setState(() => _query = v),
          ),
          BrandChips(
            brands: catalog.phoneBrands,
            selected: _brand,
            onSelected: (b) => setState(() => _brand = b),
          ),
          Expanded(
            child: phones.isEmpty
                ? const Center(child: Text('Sonuç bulunamadı'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: phones.length,
                    itemBuilder: (context, i) {
                      final p = phones[i];
                      final soc = catalog.soc(p.socId);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          p.platform == MobilePlatform.ios
                              ? Icons.phone_iphone_rounded
                              : Icons.phone_android_rounded,
                        ),
                        title: Text(p.displayName),
                        subtitle: Text(
                          '${soc?.name ?? p.socId} · '
                          '${p.ramOptionsGb.join('/')} GB · ${p.year}',
                        ),
                        trailing: p.refPriceUsd == null
                            ? null
                            : Text(
                                '~\$${p.refPriceUsd!.round()}',
                                style: numberStyle(
                                  context,
                                  size: 12,
                                  color: context.palette.muted,
                                ),
                              ),
                        onTap: () {
                          if (widget.returnsPhone) {
                            context.pop(p);
                            return;
                          }
                          ref.read(phoneSelectionProvider.notifier).select(p);
                          ref
                              .read(activeDeviceProvider.notifier)
                              .set(DeviceKind.phone);
                          context.pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: hint,
        isDense: true,
      ),
    ),
  );
}

/// Horizontal brand filter ("Tümü" + brands).
class BrandChips extends StatelessWidget {
  const BrandChips({
    super.key,
    required this.brands,
    required this.selected,
    required this.onSelected,
  });

  final List<String> brands;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final b in [null, ...brands])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              label: Text(b ?? 'Tümü'),
              selected: selected == b,
              onSelected: (_) => onSelected(b),
            ),
          ),
      ],
    ),
  );
}

/// Search field reused by the watch picker.
class PickerSearchField extends StatelessWidget {
  const PickerSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) =>
      _SearchField(hint: hint, onChanged: onChanged);
}
