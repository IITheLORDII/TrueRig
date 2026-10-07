import 'package:perf_engine/perf_engine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('LlmEstimator', () {
    const llmEst = LlmEstimator();
    final ram64 = part<Ram>('gskill-ddr5-6000-64');

    test('Qwen3 8B Q4 fully on RTX 4090 runs ~100-160 tok/s', () {
      final e = llmEst.estimate(
          model: llm('qwen3-8b'),
          quant: Quantization.q4km,
          gpu: part<Gpu>('rtx-4090'),
          ram: ram64);
      expect(e.placement, LlmPlacement.fullGpu);
      expect(e.tokensPerSecond, inInclusiveRange(100, 160));
      expect(e.verdict, 'Akıcı');
    });

    test('Llama 70B Q4 on 24GB GPU + 64GB RAM offloads and is slow', () {
      final e = llmEst.estimate(
          model: llm('llama3.3-70b'),
          quant: Quantization.q4km,
          gpu: part<Gpu>('rtx-4090'),
          ram: ram64);
      expect(e.placement, LlmPlacement.partialOffload);
      expect(e.tokensPerSecond, inInclusiveRange(1, 5));
      expect(e.verdict, 'Yavaş');
    });

    test('MoE model is much faster than dense model of similar size', () {
      final gpu = part<Gpu>('rtx-4090');
      final moe = llmEst.estimate(
          model: llm('qwen3-30b-a3b'),
          quant: Quantization.q4km,
          gpu: gpu,
          ram: ram64);
      final dense = llmEst.estimate(
          model: llm('qwen3-32b'),
          quant: Quantization.q4km,
          gpu: gpu,
          ram: ram64);
      expect(moe.tokensPerSecond, greaterThan(dense.tokensPerSecond * 4));
    });

    test('fast partial offload is still rated smooth', () {
      final e = llmEst.estimate(
          model: llm('qwen3-30b-a3b'),
          quant: Quantization.q4km,
          gpu: part<Gpu>('rtx-5080'),
          ram: part<Ram>('corsair-ddr5-6000-32'));
      expect(e.placement, LlmPlacement.partialOffload);
      expect(e.tokensPerSecond, greaterThan(20));
      expect(e.verdict, 'Akıcı');
    });

    test('DeepSeek 671B does not fit on a desktop', () {
      final e = llmEst.estimate(
          model: llm('deepseek-r1-671b'),
          quant: Quantization.q4km,
          gpu: part<Gpu>('rtx-5090'),
          ram: ram64);
      expect(e.placement, LlmPlacement.doesNotFit);
      expect(e.verdict, 'Sığmaz');
    });

    test('no GPU runs on CPU only using RAM bandwidth', () {
      final e = llmEst.estimate(
          model: llm('qwen3-8b'),
          quant: Quantization.q4km,
          cpu: part<Cpu>('r7-7800x3d'),
          ram: ram64);
      expect(e.placement, LlmPlacement.cpuOnly);
      expect(e.tokensPerSecond, inInclusiveRange(5, 15));
    });

    test('system RAM bandwidth for dual DDR5-6000 is 96 GB/s', () {
      expect(LlmEstimator.systemRamBandwidthGbs(null, ram64), 96);
      expect(LlmEstimator.systemRamBandwidthGbs(null, null), 50);
    });

    test('best full-GPU quant picks highest quality that fits', () {
      final q =
          llmEst.bestFullGpuQuant(llm('qwen3-14b'), part<Gpu>('rtx-4090'));
      expect(q, Quantization.q8);
      expect(
          llmEst.bestFullGpuQuant(llm('llama3.3-70b'), part<Gpu>('rtx-4060')),
          isNull);
    });
  });

  group('AppEstimator', () {
    const appEst = AppEstimator();
    final workstation = PcBuild(
      cpu: part<Cpu>('cu9-285k'),
      gpu: part<Gpu>('rtx-4080s'),
      ram: part<Ram>('gskill-ddr5-6000-64'),
    );
    final budget = PcBuild(
      cpu: part<Cpu>('i5-12400f'),
      gpu: part<Gpu>('rx-6600'),
      ram: part<Ram>('corsair-ddr4-3200-16'),
    );

    test('high-end workstation is smooth in SolidWorks', () {
      final e = appEst.estimate(app('solidworks'), workstation);
      expect(e.rating, AppRating.smooth);
      expect(e.score, greaterThan(90));
    });

    test('budget build scores lower everywhere', () {
      for (final a in kApps) {
        final hi = appEst.estimate(a, workstation).score;
        final lo = appEst.estimate(a, budget).score;
        expect(lo, lessThan(hi), reason: a.name);
      }
    });

    test('budget build struggles in Unreal Engine 5 and names a weak part', () {
      final e = appEst.estimate(app('unreal5'), budget);
      expect(e.rating, isNot(AppRating.smooth));
      expect(e.componentScores[e.weakestComponent],
          equals(e.componentScores.values.reduce((a, b) => a < b ? a : b)));
    });

    test('rating labels', () {
      expect(AppRating.struggles.label, 'Zorlanır');
    });
  });
}
