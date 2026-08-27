// synth_sounds.dart
//
// Generates the alarm-sound WAV assets used by this app under
// assets/audio/ (buzzer.wav, chime.wav, siren.wav, birds.wav).
//
// These files are produced purely by the arithmetic in this script (simple
// square/sine oscillators, exponential decay envelopes, and short linear
// fades). No external audio, sample library, or third-party asset is read
// or embedded anywhere in this file. The resulting WAV files are therefore
// original works of this repository, generated deterministically (no
// randomness is used, so re-running this script produces byte-identical
// output) and released under the same license as the rest of the
// repository.
//
// Usage (from the repository root):
//   dart run tool/synth_sounds.dart
//
// Each generated file is a seamless loop: every waveform starts and ends the
// buffer at zero amplitude, and the total buffer length is built from a
// whole number of repetitions of the underlying pattern period, so the
// alarm plugin can loop the file with no audible click or discontinuity at
// the wrap point. Every discrete tone/burst additionally gets a short
// (~5 ms) linear fade in/out so no internal edge clicks either. Peak
// amplitude is kept around 0.6 of full scale so nothing clips.
//
// Only dart:io, dart:math, and dart:typed_data are used - no Flutter and no
// third-party packages are required to run this script.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int kSampleRate = 44100;
const double kPeak = 0.6; // peak amplitude, fraction of full scale
final int kFadeSamples = (kSampleRate * 0.005).round(); // ~5 ms fade

/// A simple mutable audio buffer of samples in the range [-1.0, 1.0].
class AudioBuffer {
  final Float64List samples;
  AudioBuffer(int length) : samples = Float64List(length);

  int get length => samples.length;
}

/// Applies a short linear fade-in and fade-out to [buffer] in place, over
/// [fadeSamples] samples at each end (or half the buffer length if the
/// buffer is shorter than 2 * fadeSamples).
void applyFade(AudioBuffer buffer, {int? fadeSamples}) {
  final int n = buffer.length;
  if (n == 0) return;
  final int fade = math.min(fadeSamples ?? kFadeSamples, n ~/ 2);
  for (int i = 0; i < fade; i++) {
    final double g = i / fade;
    buffer.samples[i] *= g;
    buffer.samples[n - 1 - i] *= g;
  }
}

/// Writes [src] into [dst] starting at sample offset [offset], adding to
/// (mixing with) any existing content.
void mixInto(AudioBuffer dst, AudioBuffer src, int offset) {
  for (int i = 0; i < src.length; i++) {
    final int j = offset + i;
    if (j < 0 || j >= dst.length) continue;
    dst.samples[j] += src.samples[i];
  }
}

/// Generates a square wave burst at [freq] Hz for [seconds], with a short
/// fade in/out applied.
AudioBuffer squareBurst(double freq, double seconds, {double amp = 1.0}) {
  final int n = (kSampleRate * seconds).round();
  final buffer = AudioBuffer(n);
  final double period = kSampleRate / freq;
  for (int i = 0; i < n; i++) {
    final double phase = (i % period) / period;
    buffer.samples[i] = (phase < 0.5 ? 1.0 : -1.0) * amp;
  }
  applyFade(buffer);
  return buffer;
}

/// Generates a sine wave burst at [freq] Hz for [seconds], with an
/// exponential decay envelope (decayRate per second) and a short fade
/// in/out applied on top.
AudioBuffer sineBurst(
  double freq,
  double seconds, {
  double amp = 1.0,
  double decayRate = 0.0,
}) {
  final int n = (kSampleRate * seconds).round();
  final buffer = AudioBuffer(n);
  for (int i = 0; i < n; i++) {
    final double t = i / kSampleRate;
    final double envelope = decayRate > 0 ? math.exp(-decayRate * t) : 1.0;
    buffer.samples[i] = math.sin(2 * math.pi * freq * t) * amp * envelope;
  }
  applyFade(buffer);
  return buffer;
}

/// Generates a sine wave whose instantaneous frequency sweeps linearly
/// between [freqStart] and [freqEnd] over [seconds] (a "chirp"), with a
/// short fade in/out applied.
AudioBuffer sweepBurst(
  double freqStart,
  double freqEnd,
  double seconds, {
  double amp = 1.0,
}) {
  final int n = (kSampleRate * seconds).round();
  final buffer = AudioBuffer(n);
  // Instantaneous frequency f(t) = freqStart + (freqEnd-freqStart)*t/seconds
  // Phase is the integral of 2*pi*f(t) dt.
  final double k = (freqEnd - freqStart) / seconds;
  for (int i = 0; i < n; i++) {
    final double t = i / kSampleRate;
    final double phase = 2 * math.pi * (freqStart * t + 0.5 * k * t * t);
    buffer.samples[i] = math.sin(phase) * amp;
  }
  applyFade(buffer);
  return buffer;
}

/// Concatenates a list of buffers (and raw silence gaps, as AudioBuffers of
/// zeros) into one buffer.
AudioBuffer concat(List<AudioBuffer> parts) {
  final int total = parts.fold(0, (sum, p) => sum + p.length);
  final out = AudioBuffer(total);
  int offset = 0;
  for (final p in parts) {
    for (int i = 0; i < p.length; i++) {
      out.samples[offset + i] = p.samples[i];
    }
    offset += p.length;
  }
  return out;
}

AudioBuffer silence(double seconds) => AudioBuffer((kSampleRate * seconds).round());

/// Repeats [pattern] [times] times back to back.
AudioBuffer repeat(AudioBuffer pattern, int times) {
  final out = AudioBuffer(pattern.length * times);
  for (int r = 0; r < times; r++) {
    final int offset = r * pattern.length;
    for (int i = 0; i < pattern.length; i++) {
      out.samples[offset + i] = pattern.samples[i];
    }
  }
  return out;
}

/// Clamps every sample to [-limit, limit] to guarantee no clipping even
/// after mixing multiple partials together.
void clampBuffer(AudioBuffer buffer, double limit) {
  for (int i = 0; i < buffer.length; i++) {
    final double v = buffer.samples[i];
    if (v > limit) {
      buffer.samples[i] = limit;
    } else if (v < -limit) {
      buffer.samples[i] = -limit;
    }
  }
}

/// Encodes [buffer] as a 16-bit PCM mono WAV file at kSampleRate.
Uint8List encodeWav(AudioBuffer buffer) {
  final int numSamples = buffer.length;
  final int dataSize = numSamples * 2; // 16-bit mono
  final int byteRate = kSampleRate * 1 * 16 ~/ 8;
  const int blockAlign = 1 * 16 ~/ 8;
  final int riffSize = 4 + (8 + 16) + (8 + dataSize);

  final bytes = BytesBuilder();

  void writeAscii(String s) => bytes.add(s.codeUnits);
  void writeU32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    bytes.add(b.buffer.asUint8List());
  }

  void writeU16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    bytes.add(b.buffer.asUint8List());
  }

  // RIFF header
  writeAscii('RIFF');
  writeU32(riffSize);
  writeAscii('WAVE');

  // fmt chunk
  writeAscii('fmt ');
  writeU32(16); // chunk size
  writeU16(1); // PCM
  writeU16(1); // mono
  writeU32(kSampleRate);
  writeU32(byteRate);
  writeU16(blockAlign);
  writeU16(16); // bits per sample

  // data chunk
  writeAscii('data');
  writeU32(dataSize);
  final pcm = ByteData(dataSize);
  for (int i = 0; i < numSamples; i++) {
    double s = buffer.samples[i];
    if (s > 1.0) s = 1.0;
    if (s < -1.0) s = -1.0;
    final int sample = (s * 32767.0).round();
    pcm.setInt16(i * 2, sample, Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());

  return bytes.toBytes();
}

/// Ensures the buffer starts and ends at (effectively) zero amplitude so a
/// loop wrap has no discontinuity. applyFade() already forces the very
/// first/last samples of a burst to 0; this helper does the same for a
/// buffer assembled from silence/bursts by forcing sample 0 and the last
/// sample to exactly 0.0 (they are already ~0 from fades/silence, so this
/// is just a defensive guarantee).
void forceZeroEdges(AudioBuffer buffer) {
  if (buffer.length == 0) return;
  buffer.samples[0] = 0.0;
  buffer.samples[buffer.length - 1] = 0.0;
}

// ---------------------------------------------------------------------------
// buzzer.wav: harsh square-wave buzz, ~2s, 220Hz square gated
// 0.25s on / 0.15s off.
// ---------------------------------------------------------------------------
AudioBuffer buildBuzzer() {
  const double onTime = 0.25;
  const double offTime = 0.15;
  const double freq = 220.0;
  final onBurst = squareBurst(freq, onTime, amp: kPeak);
  final offBurst = silence(offTime);
  // One on/off pattern period = 0.4s. ~2s / 0.4s = 5 repeats exactly.
  final pattern = concat([onBurst, offBurst]);
  const int repeats = 5; // 5 * 0.4s = 2.0s
  final full = repeat(pattern, repeats);
  forceZeroEdges(full);
  return full;
}

// ---------------------------------------------------------------------------
// chime.wav: gentle bell-like chime, ~3s: a few decaying sine partials
// (880/1320/1760 Hz) repeated.
// ---------------------------------------------------------------------------
AudioBuffer buildChime() {
  const double strikeSeconds = 1.0; // one bell strike, mostly decayed by end
  const double gapSeconds = 0.5; // silence before next strike
  final strike = AudioBuffer((kSampleRate * strikeSeconds).round());
  const partials = [
    (freq: 880.0, amp: 0.45, decay: 4.5),
    (freq: 1320.0, amp: 0.25, decay: 6.0),
    (freq: 1760.0, amp: 0.15, decay: 7.5),
  ];
  for (final p in partials) {
    final tone = sineBurst(
      p.freq,
      strikeSeconds,
      amp: p.amp,
      decayRate: p.decay,
    );
    mixInto(strike, tone, 0);
  }
  clampBuffer(strike, kPeak);
  applyFade(strike);
  final pattern = concat([strike, silence(gapSeconds)]);
  // Pattern period = 1.5s. 2 repeats = 3.0s.
  const int repeats = 2;
  final full = repeat(pattern, repeats);
  forceZeroEdges(full);
  return full;
}

// ---------------------------------------------------------------------------
// siren.wav: sine sweeping up and down between ~600 and ~1200 Hz over ~2s.
// ---------------------------------------------------------------------------
AudioBuffer buildSiren() {
  const double halfSweep = 1.0; // 1s up, 1s down = 2s period
  final up = sweepBurst(600.0, 1200.0, halfSweep, amp: kPeak);
  final down = sweepBurst(1200.0, 600.0, halfSweep, amp: kPeak);
  final pattern = concat([up, down]);
  const int repeats = 1; // one full up/down cycle = 2.0s
  final full = repeat(pattern, repeats);
  forceZeroEdges(full);
  return full;
}

// ---------------------------------------------------------------------------
// birds.wav: soft chirps, short frequency-swept sine bursts around
// 2.5-4kHz with silence between, ~3s total.
// ---------------------------------------------------------------------------
AudioBuffer buildBirds() {
  // A short chirp motif made of two quick upward sweeps, then silence.
  final chirp1 = sweepBurst(2600.0, 3800.0, 0.09, amp: kPeak);
  final microGap = silence(0.05);
  final chirp2 = sweepBurst(3000.0, 4000.0, 0.07, amp: kPeak);
  final motif = concat([chirp1, microGap, chirp2]);
  final tailGap = silence(1.0 - motif.length / kSampleRate);
  final pattern = concat([motif, tailGap]); // pattern period = 1.0s
  const int repeats = 3; // 3 * 1.0s = 3.0s
  final full = repeat(pattern, repeats);
  forceZeroEdges(full);
  return full;
}

void main() {
  final outputs = <String, AudioBuffer Function()>{
    'buzzer.wav': buildBuzzer,
    'chime.wav': buildChime,
    'siren.wav': buildSiren,
    'birds.wav': buildBirds,
  };

  final scriptDir = File(Platform.script.toFilePath()).parent;
  final repoRoot = scriptDir.parent;
  final audioDir = Directory('${repoRoot.path}/assets/audio');
  if (!audioDir.existsSync()) {
    audioDir.createSync(recursive: true);
  }

  for (final entry in outputs.entries) {
    final buffer = entry.value();
    final wavBytes = encodeWav(buffer);
    final outFile = File('${audioDir.path}/${entry.key}');
    outFile.writeAsBytesSync(wavBytes, flush: true);
    final seconds = buffer.length / kSampleRate;
    stdout.writeln(
      '${entry.key}: ${wavBytes.length} bytes, '
      '${seconds.toStringAsFixed(3)}s, ${buffer.length} samples',
    );
  }
}
