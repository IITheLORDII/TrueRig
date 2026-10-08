/// One place for every "is this good?" threshold so every screen uses the
/// same words and colours.
library;

import 'package:darbogaz/core/widgets/common.dart';

/// 60+ smooth, 30–60 playable, below 30 stutters.
const double kFpsSmooth = 60;
const double kFpsPlayable = 30;

/// Local AI: 30+ words/s feels instant, 10–30 is fine, below 10 is slow.
const double kTpsFast = 30;
const double kTpsUsable = 10;

Tone fpsTone(double fps) => fps >= kFpsSmooth
    ? Tone.good
    : fps >= kFpsPlayable
    ? Tone.warn
    : Tone.bad;

String fpsWord(double fps) => fps >= kFpsSmooth
    ? 'akıcı'
    : fps >= kFpsPlayable
    ? 'oynanır'
    : 'takılır';

Tone tpsTone(double tps) => tps >= kTpsFast
    ? Tone.good
    : tps >= kTpsUsable
    ? Tone.warn
    : Tone.bad;

String tpsWord(double tps) => tps >= kTpsFast
    ? 'hızlı'
    : tps >= kTpsUsable
    ? 'kullanılır'
    : 'yavaş';

/// Bottleneck percent: under 10 fine, 10–20 noticeable, 20+ strong.
Tone bottleneckTone(double percent) => percent < 10
    ? Tone.good
    : percent < 20
    ? Tone.warn
    : Tone.bad;

/// 0–100 device score (phones / watches): 60+ strong, 40–60 mid, else weak.
Tone scoreTone(double score) => score >= 60
    ? Tone.good
    : score >= 40
    ? Tone.warn
    : Tone.bad;

String scoreWord(double score) => score >= 60
    ? 'Güçlü'
    : score >= 40
    ? 'Orta'
    : 'Zayıf';
