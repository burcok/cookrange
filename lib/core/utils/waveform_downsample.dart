/// Downsamples a raw amplitude sample stream into a fixed-length, storage-
/// ready waveform.
///
/// Input shape matches what `record`'s `AudioRecorder.onAmplitudeChanged`
/// stream actually reports (checked against v7.1.1's API): each tick is an
/// `Amplitude` with a `current` field — a **dBFS double**, i.e. 0.0 at full
/// scale and increasingly negative toward silence (the package's own floor
/// is -160dBFS). A recording UI collects `Amplitude.current` into a
/// `List<double>` over the life of the recording (one sample per
/// `onAmplitudeChanged` tick) and hands the whole list to [downsample] once
/// to build the value persisted on `MessageAttachment.peaks`.
///
/// Pure, Firebase-free — unit-tested at `test/waveform_downsample_test.dart`,
/// following `chat_list_filter.dart`'s precedent (`docs/SERVICES.md`).
class WaveformDownsampler {
  const WaveformDownsampler._();

  /// Fixed bucket count stored on `MessageAttachment.peaks` — small enough to
  /// be a cheap Firestore field, dense enough to read as a real waveform.
  static const int defaultBucketCount = 48;

  /// dBFS treated as silence (normalizes to 0). Deliberately well above
  /// `record`'s own -160dBFS floor: normal mic noise floor during a pause in
  /// speech rarely drops past this, so clamping here (rather than at -160)
  /// keeps quiet-but-present speech from reading as a flatlined waveform.
  static const double silenceFloorDb = -45.0;

  /// Downsamples [rawDbfsSamples] to exactly [bucketCount] entries, each a
  /// 0-100 normalized amplitude (100 = 0dBFS / full scale, 0 = [floorDb] or
  /// quieter). Always returns a list of length [bucketCount], regardless of
  /// how many samples came in:
  ///  - empty input → all-zero buckets (silence, nothing recorded).
  ///  - fewer samples than buckets → each source sample fans out across a
  ///    contiguous run of output buckets (no interpolation/fabricated data
  ///    between real samples).
  ///  - more samples than buckets → each output bucket is the average of its
  ///    (roughly equal-sized) chunk of source samples.
  static List<int> downsample(
    List<double> rawDbfsSamples, {
    int bucketCount = defaultBucketCount,
    double floorDb = silenceFloorDb,
  }) {
    assert(bucketCount > 0, 'bucketCount must be positive');
    if (rawDbfsSamples.isEmpty) return List<int>.filled(bucketCount, 0);

    final normalized = rawDbfsSamples
        .map((db) => _normalize(db, floorDb))
        .toList(growable: false);

    return List<int>.generate(bucketCount, (i) {
      var start = (i * normalized.length / bucketCount).floor();
      var end = ((i + 1) * normalized.length / bucketCount).floor();
      if (end <= start) end = start + 1;
      if (end > normalized.length) end = normalized.length;
      if (start >= normalized.length) start = normalized.length - 1;

      final chunk = normalized.sublist(start, end);
      final avg = chunk.reduce((a, b) => a + b) / chunk.length;
      return _clampInt(avg.round(), 0, 100);
    }, growable: false);
  }

  /// Maps a single dBFS reading to a 0-100 double, clamped to [floorDb, 0].
  static double _normalize(double db, double floorDb) {
    final clamped = db.clamp(floorDb, 0.0);
    return (clamped - floorDb) / (-floorDb) * 100;
  }

  static int _clampInt(int value, int lo, int hi) {
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
  }
}
