import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/page_nav.dart';
import 'package:darbogaz/core/devices.dart';
import 'package:darbogaz/core/widgets/picker.dart';
import 'package:darbogaz/core/brand/truerig_logo.dart';

export 'package:darbogaz/core/widgets/picker.dart'
    show BrandChips, PickerSearchField;

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
      bottomNavigationBar: const InnerNavBar(),
      appBar: AppBar(
        leading: const PageBackButton(),
        title: BrandTitle(switch (widget.mode) {
          'pair' => 'Saatin telefonu',
          'compare' => 'Karşılaştırılacak telefon',
          _ => 'Telefon seç',
        }),
      ),
      body: Column(
        children: [
          PickerSearchField(
            hint: 'Model ara (ör. iPhone 15, S24, Redmi Note 13)',
            onChanged: (v) => setState(() => _query = v),
          ),
          BrandChips(
            brands: catalog.phoneBrands,
            selected: _brand,
            onSelected: (b) => setState(() => _brand = b),
          ),
          Expanded(
            child: PickerList(
              itemCount: phones.length,
              itemBuilder: (context, i) {
                final p = phones[i];
                final soc = catalog.soc(p.socId);
                return PickerTile(
                  icon: p.platform == MobilePlatform.ios
                      ? Icons.phone_iphone_rounded
                      : Icons.phone_android_rounded,
                  title: p.displayName,
                  subtitle:
                      '${soc?.name ?? p.socId} · '
                      '${p.ramOptionsGb.join('/')} GB · ${p.year}',
                  trailingText: p.refPriceUsd == null
                      ? null
                      : '~\$${p.refPriceUsd!.round()}',
                  selected:
                      !widget.returnsPhone &&
                      ref.watch(phoneSelectionProvider)?.phoneId == p.id,
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
