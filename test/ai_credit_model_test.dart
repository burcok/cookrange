import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/ai_credit_model.dart';

void main() {
  group('AiCreditModel', () {
    Timestamp future() =>
        Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1)));
    Timestamp past() =>
        Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1)));

    test('fresh free model is not exhausted, full remaining', () {
      final m = AiCreditModel.fresh();
      expect(m.used, 0);
      expect(m.isPremium, false);
      expect(m.isExhausted, false);
      expect(m.remaining, AiCreditModel.freeDailyLimit);
    });

    test('premium has the higher daily limit', () {
      expect(AiCreditModel.fresh(isPremium: true).remaining,
          AiCreditModel.premiumDailyLimit);
    });

    test('exhausted when used >= limit + bonus', () {
      final m = AiCreditModel.fromFirestore({
        'used_today': AiCreditModel.freeDailyLimit,
        'reset_at': future(),
        'bonus': 0,
      });
      expect(m.isExhausted, true);
      expect(m.remaining, 0);
    });

    test('bonus credits extend the limit', () {
      final m = AiCreditModel.fromFirestore({
        'used_today': AiCreditModel.freeDailyLimit,
        'reset_at': future(),
        'bonus': 5,
      });
      expect(m.isExhausted, false);
      expect(m.remaining, 5);
    });

    test('parses the new server-ledger field names', () {
      final m = AiCreditModel.fromFirestore(
          {'used_today': 1, 'reset_at': future(), 'bonus': 2});
      expect(m.used, 1);
      expect(m.bonus, 2);
    });

    test('rollover: used treated as 0 once reset_at has passed', () {
      final m = AiCreditModel.fromFirestore(
          {'used_today': 2, 'reset_at': past(), 'bonus': 0});
      expect(m.used, 0);
      expect(m.isExhausted, false);
    });
  });
}
