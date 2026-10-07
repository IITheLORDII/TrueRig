import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perf_engine/perf_engine.dart';

import 'package:darbogaz/core/widgets/app_controls.dart';
import 'package:darbogaz/core/providers.dart';
import 'package:darbogaz/core/theme/app_theme.dart';
import 'package:darbogaz/core/widgets/common.dart';

const _contextOptions = [4096, 8192, 32768];

/// Local LLM (Ollama / LM Studio / llama.cpp) generation speed estimates.
class AiTab extends ConsumerStatefulWidget {
  const AiTab({super.key});

  @override
  ConsumerState<AiTab> createState() => _AiTabState();
}

class _AiTabState extends ConsumerState<AiTab> {
  Quantization _quant = Quantization.q4km;
  int _ctx = 8192;

  @override
  Widget build(BuildContext context) {
    final build = ref.watch(buildProvider);
    const est = LlmEstimator();
    final results = [
      for (final m in kLlmModels)
        est.estimate(
          model: m,
          quant: _quant,
          cpu: build.cpu,
          gpu: build.gpu,
          ram: build.ram,
          contextTokens: _ctx,
        ),
    ];
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AppSegmented<Quantization>(
          values: Quantization.values,
          selected: _quant,
          labelOf: (q) => q.label,
          onChanged: (v) => setState(() => _quant = v),
        ),
        const SizedBox(height: 8),
        AppSegmented<int>(
          values: _contextOptions,
          selected: _ctx,
          labelOf: (c) => '${c ~/ 1024}K bağlam',
          onChanged: (v) => setState(() => _ctx = v),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Üretim hızı (token/sn)',
          icon: Icons.psychology_rounded,
          child: Column(
            children: [
              for (final r in results) LlmRow(result: r),
              const SizedBox(height: 8),
              Text(
                'Hız, belleğin bant genişliğinden hesaplanır (Ollama / LM '
                'Studio / llama.cpp). Okuma hızı ~5 token/sn, akıcı sohbet '
                '20+ token/sn ister.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LlmRow extends StatelessWidget {
  const LlmRow({super.key, required this.result});

  final LlmEstimate result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final r = result;
    final color = switch (r.verdict) {
      'Akıcı' => palette.good,
      'Kullanılabilir' => palette.warn,
      _ => palette.bad,
    };
    final where = switch (r.placement) {
      LlmPlacement.fullGpu => 'Tamamen GPU',
      LlmPlacement.partialOffload =>
        '%${(r.gpuFraction * 100).round()} GPU + RAM',
      LlmPlacement.cpuOnly => 'Sadece CPU/RAM',
      LlmPlacement.doesNotFit => 'Belleğe sığmıyor',
    };
    final needs = '${r.requiredGb.toStringAsFixed(1)} GB';
    return MetricBar(
      label: r.model.name,
      value: r.tokensPerSecond,
      max: 100,
      valueText: r.placement == LlmPlacement.doesNotFit
          ? 'Sığmaz'
          : '${r.tokensPerSecond.toStringAsFixed(r.tokensPerSecond < 10 ? 1 : 0)} t/s',
      color: color,
      subtitle: '$where · $needs gerekli · ${r.verdict}',
    );
  }
}
