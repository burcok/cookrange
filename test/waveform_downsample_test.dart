import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/utils/waveform_downsample.dart';

void main() {
  group('WaveformDownsampler.downsample', () {
    test('empty input returns all-zero buckets at the requested length', () {
      final result = WaveformDownsampler.downsample([], bucketCount: 5);
      expect(result, [0, 0, 0, 0, 0]);
    });

    test('empty input at the default bucket count', () {
      final result = WaveformDownsampler.downsample([]);
      expect(result, hasLength(WaveformDownsampler.defaultBucketCount));
      expect(result.every((v) => v == 0), isTrue);
    });

    test(
        'fewer samples than buckets fans each sample across a contiguous '
        'run of output buckets, in order, with no data between real samples',
        () {
      // -45dBFS -> 0, -22.5dBFS -> 50, 0dBFS -> 100 (silenceFloorDb = -45).
      final result = WaveformDownsampler.downsample([-45.0, -22.5, 0.0]);

      expect(result, hasLength(WaveformDownsampler.defaultBucketCount));
      // 48 buckets / 3 samples split into three even 16-wide runs.
      expect(result.sublist(0, 16), List.filled(16, 0));
      expect(result.sublist(16, 32), List.filled(16, 50));
      expect(result.sublist(32, 48), List.filled(16, 100));
    });

    test('more samples than buckets averages each bucket\'s chunk', () {
      final result = WaveformDownsampler.downsample(
        [
          -45.0, -45.0, // chunk 0 -> normalize 0, 0 -> avg 0
          -22.5, -22.5, // chunk 1 -> normalize 50, 50 -> avg 50
          0.0, 0.0, // chunk 2 -> normalize 100, 100 -> avg 100
          -11.25, -11.25, // chunk 3 -> normalize 75, 75 -> avg 75
        ],
        bucketCount: 4,
      );

      expect(result, [0, 50, 100, 75]);
    });

    test(
        'all-same-value input normalizes to one constant value across '
        'every bucket', () {
      final result = WaveformDownsampler.downsample(
        List.filled(20, -20.0),
        bucketCount: 6,
      );

      // (-20 - (-45)) / 45 * 100 = 55.55... -> rounds to 56.
      expect(result, [56, 56, 56, 56, 56, 56]);
    });

    test('output length always matches bucketCount regardless of input size',
        () {
      expect(WaveformDownsampler.downsample([1.0], bucketCount: 10),
          hasLength(10));
      expect(
          WaveformDownsampler.downsample(List.filled(1000, -5.0),
              bucketCount: 10),
          hasLength(10));
    });

    test('values are always clamped into 0-100 even for out-of-range dBFS', () {
      final result = WaveformDownsampler.downsample(
        [5.0, -1000.0], // above full scale / far below the silence floor
        bucketCount: 2,
      );
      expect(result, [100, 0]);
    });
  });
}
