import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_insight_model.dart';
import '../models/user_model.dart';
import 'analytics_service.dart';
import 'food_log_service.dart';
import 'storage_service.dart';
import 'ai/ai_service.dart';
import 'ai/prompt_service.dart';
import '../utils/calorie_calculator.dart';

class AiInsightService {
  static final AiInsightService _instance = AiInsightService._internal();
  factory AiInsightService() => _instance;
  AiInsightService._internal();

  // SharedPrefs key prefix — locale is appended so EN/TR are stored separately.
  static const String _kGeneratedAt = 'ai_insight_generated_at';
  static const String _kMessage = 'ai_insight_message';
  static const String _kTips = 'ai_insight_tips';

  // ─── Risk Detection (client-side, no AI call) ──────────────────────────────

  Future<AiRiskLevel> detectRiskLevel(String uid) async {
    try {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final logs =
          await FoodLogService().getLogsForDateRange(uid, threeDaysAgo, now);

      final recentLogCount = logs.values.expand((l) => l).length;
      if (recentLogCount == 0) return AiRiskLevel.high;

      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final todayLogs = logs[todayKey] ?? [];

      if (todayLogs.isEmpty && now.hour >= 14) return AiRiskLevel.medium;
      if (todayLogs.isEmpty && now.hour >= 10) return AiRiskLevel.low;
      return AiRiskLevel.none;
    } catch (e) {
      debugPrint('AiInsightService.detectRiskLevel error: $e');
      return AiRiskLevel.none;
    }
  }

  // ─── Daily Accountability Insight ─────────────────────────────────────────

  /// Generates (or returns today's cached) accountability insight.
  /// [locale] must be read BEFORE the first await at the call site.
  /// Cache is keyed by date + locale so switching languages forces a fresh call.
  Future<AiInsightModel> generateAccountabilityInsight(
    UserModel user, {
    String locale = 'en',
  }) async {
    final todayStr = _dateKey(DateTime.now());
    final cacheKeyDate = '${_kGeneratedAt}_$locale';
    final cacheKeyMsg = '${_kMessage}_$locale';
    final cacheKeyTips = '${_kTips}_$locale';

    // Check cache first (date + locale match)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(cacheKeyDate);
      if (cachedDate == todayStr) {
        final msg = prefs.getString(cacheKeyMsg) ?? '';
        final tipsRaw = prefs.getString(cacheKeyTips) ?? '[]';
        final tips = List<String>.from(jsonDecode(tipsRaw) as List? ?? []);
        if (msg.isNotEmpty) {
          debugPrint(
              'AiInsightService: returning cached insight for $todayStr ($locale)');
          unawaited(AnalyticsService().logEvent(
            name: 'ai_cache_hit',
            parameters: {'type': 'accountability_insight'},
          ));
          return AiInsightModel.fromJson({'message': msg, 'tips': tips});
        }
      }
    } catch (e) {
      debugPrint('AiInsightService: cache read error: $e');
    }

    if (!AIService().isConfigured) return _fallbackInsight(user, locale);

    try {
      final streak = user.onboardingData?['streak'] as int? ?? 0;
      final goal = user.profile.primaryGoals.isNotEmpty
          ? user.profile.primaryGoals.first
          : 'general fitness';
      final weekdayName = _weekdayName(DateTime.now().weekday);

      final prompt = '''
You are a supportive fitness coach AI. Generate a brief motivational daily insight for this user:
- Name: ${user.displayName ?? 'User'}
- Primary goal: $goal
- Current streak: $streak days
- Activity level: ${user.profile.activityLevel}
- Today is $weekdayName

Return ONLY valid JSON matching this structure:
{"message": "one motivating sentence personalized to their goal", "tips": ["actionable tip 1", "actionable tip 2"]}
${PromptService().localeInstruction(locale)}''';

      const jsonStructure = '{"message": "string", "tips": ["string"]}';
      final result = await AIService()
          .generateJson(prompt: prompt, jsonStructure: jsonStructure);

      final insight = AiInsightModel.fromJson(result);

      // Cache with locale-tagged keys
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKeyDate, _dateKey(DateTime.now()));
        await prefs.setString(cacheKeyMsg, insight.message);
        await prefs.setString(cacheKeyTips, jsonEncode(insight.tips));
      } catch (e) {
        debugPrint('AiInsightService: cache write error: $e');
      }

      unawaited(AnalyticsService().logEvent(
        name: 'ai_generated',
        parameters: {'type': 'accountability_insight'},
      ));
      debugPrint(
          'AiInsightService: generated fresh accountability insight ($locale)');
      return insight;
    } catch (e) {
      debugPrint('AiInsightService.generateAccountabilityInsight error: $e');
      return _fallbackInsight(user, locale);
    }
  }

  // ─── Fitness Twin Projection ───────────────────────────────────────────────

  /// Generates a new fitness twin projection and saves it to Firestore.
  /// Always fires a real AI call — callers must have already checked credits.
  /// [locale] must be read BEFORE the first await at the call site.
  Future<Map<String, dynamic>> generateFitnessTwin(
    UserModel user, {
    String locale = 'en',
  }) async {
    if (!AIService().isConfigured) return _fallbackProjection(user, locale);

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final weightHistory = StorageService().getWeightHistory();
      final foodLogs = await FoodLogService()
          .getLogsForDateRange(user.uid, thirtyDaysAgo, now);

      final allLogs = foodLogs.values.expand((l) => l).toList();
      final daysWithLogs =
          foodLogs.values.where((l) => l.isNotEmpty).length;
      final avgCalories = daysWithLogs > 0
          ? allLogs.fold(0.0, (acc, l) => acc + l.calories) / daysWithLogs
          : 0.0;

      final recentWeights = weightHistory.where((w) {
        final d = DateTime.tryParse(w['date'] as String? ?? '');
        return d != null && now.difference(d).inDays <= 30;
      }).toList();

      final currentWeight = recentWeights.isNotEmpty
          ? (recentWeights.first['weight'] as num).toDouble()
          : (user.profile.weightKg ?? 70).toDouble();

      final oldestWeight = recentWeights.isNotEmpty
          ? (recentWeights.last['weight'] as num).toDouble()
          : currentWeight;

      final targetWeight =
          (user.onboardingData?['target_weight'] as num?)?.toDouble() ??
              currentWeight;

      final profile = user.profile;
      double bmr = 1800;
      if (profile.heightCm != null &&
          profile.age != null &&
          profile.gender != null) {
        bmr = CalorieCalculator.calculateBMR(
          weight: currentWeight,
          height: profile.heightCm!.toDouble(),
          age: profile.age!,
          gender: profile.gender!,
        );
      }
      final tdee = CalorieCalculator.calculateTDEE(
          bmr: bmr, activityLevel: profile.activityLevel);

      final prompt = '''
You are an expert fitness and nutrition AI. Analyze this user's data and provide a realistic body transformation projection.

User Profile:
- Goal: ${profile.primaryGoals.join(', ')}
- Current weight: ${currentWeight.toStringAsFixed(1)} kg
- Target weight: ${targetWeight.toStringAsFixed(1)} kg
- Height: ${profile.heightCm ?? '?'} cm, Age: ${profile.age ?? '?'}, Gender: ${profile.gender ?? '?'}
- Activity level: ${profile.activityLevel}
- Calculated TDEE: ${tdee.toStringAsFixed(0)} calories/day
- Average actual daily calories consumed: ${avgCalories.toStringAsFixed(0)} (from last $daysWithLogs days of logs)
- Weight trend: ${oldestWeight.toStringAsFixed(1)} kg → ${currentWeight.toStringAsFixed(1)} kg over last ${recentWeights.length} data points
- Current streak: ${user.onboardingData?['streak'] ?? 0} days

Provide a realistic projection. Be honest but encouraging.
Return ONLY valid JSON:
{
  "currentStatus": "brief 1-2 sentence assessment of their current trajectory",
  "weeklyWeightChange": 0.3,
  "projection30days": "what they will likely achieve in 30 days at current pace",
  "projection60days": "60-day realistic outcome",
  "projection90days": "90-day realistic outcome",
  "goalDateEstimate": "realistic timeframe to reach target weight (e.g. 3 months, already close, 8 months)",
  "calorieGap": 150,
  "recommendations": ["specific actionable recommendation 1", "specific actionable recommendation 2", "specific actionable recommendation 3"],
  "motivationScore": 75
}
${PromptService().localeInstruction(locale)}''';

      const jsonStructure =
          '{"currentStatus": "string", "weeklyWeightChange": 0.0, "projection30days": "string", "projection60days": "string", "projection90days": "string", "goalDateEstimate": "string", "calorieGap": 0, "recommendations": ["string"], "motivationScore": 0}';

      final result = await AIService()
          .generateJson(prompt: prompt, jsonStructure: jsonStructure);

      unawaited(AnalyticsService().logEvent(
        name: 'ai_generated',
        parameters: {'type': 'fitness_twin'},
      ));
      debugPrint('AiInsightService: generated fitness twin projection ($locale)');
      // Persist to Firestore — fire-and-forget, does not block UI
      unawaited(_saveTwinProjection(user.uid, locale, result));
      return result;
    } catch (e) {
      debugPrint('AiInsightService.generateFitnessTwin error: $e');
      return _fallbackProjection(user, locale);
    }
  }

  // ─── Twin Projection Persistence ──────────────────────────────────────────

  /// Saves a projection snapshot to `users/{uid}/ai_twin_projections`.
  Future<void> _saveTwinProjection(
    String uid,
    String locale,
    Map<String, dynamic> result,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('ai_twin_projections')
          .add({
        ...result,
        'locale': locale,
        'generatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          'AiInsightService: saved twin projection for $uid (locale=$locale)');
    } catch (e) {
      debugPrint('AiInsightService._saveTwinProjection error: $e');
    }
  }

  /// Stream of the most recent saved projection for [uid].
  /// Locale-agnostic — shows the latest projection regardless of the language it
  /// was generated in. Returns null if no document exists → "generate" CTA.
  Stream<DocumentSnapshot?> getLatestProjectionStream(
      String uid, String locale) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ai_twin_projections')
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty ? s.docs.first : null);
  }

  /// Stream of the last 10 projections across all locales — used in history UI.
  Stream<List<QueryDocumentSnapshot>> getProjectionHistoryStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ai_twin_projections')
        .orderBy('generatedAt', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  AiInsightModel _fallbackInsight(UserModel user, String locale) {
    final goal = user.profile.primaryGoals.isNotEmpty
        ? user.profile.primaryGoals.first
        : 'general fitness';
    if (locale == 'tr') {
      return AiInsightModel.fromJson({
        'message': 'Her adım hedefine giden yolda önemlidir — harika gidiyorsun!',
        'tips': [
          'Öğünlerini düzenli olarak kayıt et.',
          'Gün boyunca bol su iç.',
        ],
      });
    }
    return AiInsightModel.fromJson({
      'message':
          'Every step counts on your journey to $goal — keep up the great work!',
      'tips': [
        'Log your meals consistently to track your progress.',
        'Drink plenty of water throughout the day.',
      ],
    });
  }

  Map<String, dynamic> _fallbackProjection(UserModel user, String locale) {
    if (locale == 'tr') {
      return {
        'currentStatus': 'Kişiselleştirilmiş projeksiyon için AI\'ı etkinleştirin.',
        'weeklyWeightChange': 0.0,
        'projection30days': 'AI projeksiyonu mevcut değil',
        'projection60days': 'AI projeksiyonu mevcut değil',
        'projection90days': 'AI projeksiyonu mevcut değil',
        'goalDateEstimate': 'Bilinmiyor',
        'calorieGap': 0,
        'recommendations': [
          'Doğru takip için öğünlerini her gün kayıt et.',
          'İlerlemeyi izlemek için düzenli tartıl.',
          'Aktivite düzeyine tutarlı kal.',
        ],
        'motivationScore': 70,
      };
    }
    return {
      'currentStatus':
          'Enable AI for a personalized projection of your fitness journey.',
      'weeklyWeightChange': 0.0,
      'projection30days': 'AI projection unavailable',
      'projection60days': 'AI projection unavailable',
      'projection90days': 'AI projection unavailable',
      'goalDateEstimate': 'Unknown',
      'calorieGap': 0,
      'recommendations': [
        'Log your meals daily for accurate tracking.',
        'Weigh yourself regularly to monitor progress.',
        'Stay consistent with your activity level.',
      ],
      'motivationScore': 70,
    };
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekdayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }
}
