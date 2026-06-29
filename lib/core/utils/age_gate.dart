/// Age gating for KVKK/GDPR children's-data compliance.
///
/// Cookrange processes health data, so we apply a conservative minimum age.
/// 16 is the GDPR Art. 8 default for digital consent without guardian approval;
/// some regions permit 13. Confirm the exact threshold with legal counsel and
/// adjust [kMinimumAgeYears] if a per-region policy is adopted.
class AgeGate {
  AgeGate._();

  static const int kMinimumAgeYears = 16;

  /// The most recent birth date that still satisfies the minimum age today.
  /// Use as the date picker's `maxDate` so under-age dates can't be selected.
  static DateTime maxAllowedBirthDate([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year - kMinimumAgeYears, n.month, n.day);
  }

  /// Whole-year age for [birthDate] as of [now].
  static int ageInYears(DateTime birthDate, [DateTime? now]) {
    final n = now ?? DateTime.now();
    var age = n.year - birthDate.year;
    final hadBirthday =
        (n.month > birthDate.month) ||
        (n.month == birthDate.month && n.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// True if [birthDate] is below the minimum age (defensive check).
  static bool isUnderMinimumAge(DateTime birthDate, [DateTime? now]) =>
      ageInYears(birthDate, now) < kMinimumAgeYears;
}
