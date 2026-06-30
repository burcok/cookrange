import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coach_profile_model.dart';
import '../models/dish_model.dart';
import '../models/food_log_model.dart';
import '../models/gym_model.dart';
import '../models/ingredient_model.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/weekly_meal_plan_model.dart';

/// Static dummy data for Test Mode — max volume stress-test scenarios.
/// Uses real dish IDs so DishService lookups are bypassed entirely via [dishCache].
class TestDataLibrary {
  TestDataLibrary._();

  // Dish IDs used in the test plan
  static const _breakfast1 = 'geleneksel_menemen';
  static const _breakfast2 = 'sebzeli_omlet';
  static const _breakfast3 = 'yulaf_muz';
  static const _breakfast4 = 'avokadolu_yumurta';
  static const _breakfast5 = 'yogurt_granola';
  static const _lunch1 = 'izgara_steak_salata';
  static const _lunch2 = 'somonlu_kinoa_bowl';
  static const _lunch3 = 'ton_balikli_salata';
  static const _lunch4 = 'nohutlu_sebze_bowl';
  static const _lunch5 = 'izgara_tavuk_salata';
  static const _dinner1 = 'izgara_somon_sebze';
  static const _dinner2 = 'etli_nohut';
  static const _dinner3 = 'etli_makarna';
  static const _dinner4 = 'izgara_kofte_bulgur';
  static const _dinner5 = 'dana_bonfile_patates';
  static const _snack1 = 'smoothie_bowl_protein';
  static const _snack2 = 'yulaf_kirmizi_meyve';

  /// 7-day meal plan starting Monday of the current week.
  static WeeklyMealPlanModel weeklyPlan(String uid) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    const breakfasts = [
      _breakfast1, _breakfast2, _breakfast3, _breakfast4, _breakfast5,
      _breakfast1, _breakfast2,
    ];
    const lunches = [
      _lunch1, _lunch2, _lunch3, _lunch4, _lunch5,
      _lunch1, _lunch2,
    ];
    const dinners = [
      _dinner1, _dinner2, _dinner3, _dinner4, _dinner5,
      _dinner1, _dinner2,
    ];
    const snacks = [
      _snack1, _snack2, _snack1, _snack2, _snack1,
      _snack2, _snack1,
    ];
    const dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];

    final days = List.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      final breakfast = _dishMacros[breakfasts[i]]!;
      final lunch = _dishMacros[lunches[i]]!;
      final dinner = _dishMacros[dinners[i]]!;
      final snack = _dishMacros[snacks[i]]!;
      final totalCal = breakfast['cal']! + lunch['cal']! + dinner['cal']! + snack['cal']!;

      return DayMealPlan(
        date: date,
        dayName: dayNames[i],
        meals: {
          'breakfast': breakfasts[i],
          'lunch': lunches[i],
          'dinner': dinners[i],
          'snack': snacks[i],
        },
        totalCalories: totalCal,
        macros: {
          'protein': breakfast['protein']! + lunch['protein']! + dinner['protein']! + snack['protein']!,
          'carbs': breakfast['carbs']! + lunch['carbs']! + dinner['carbs']! + snack['carbs']!,
          'fat': breakfast['fat']! + lunch['fat']! + dinner['fat']! + snack['fat']!,
        },
      );
    });

    final totalCal = days.fold(0.0, (acc, d) => acc + d.totalCalories);

    return WeeklyMealPlanModel(
      id: 'test_plan',
      userId: uid,
      weekStartDate: weekStart,
      days: days,
      totalCalories: totalCal,
      avgDailyCalories: totalCal / 7,
      avgMacros: {
        'protein': 130,
        'carbs': 195,
        'fat': 70,
      },
      createdAt: now,
      expiresAt: now.add(const Duration(days: 7)),
      generationPromptHash: 'test',
      isAiGenerated: false,
    );
  }

  /// Pre-built dish cache — avoids all Firestore fetches in test mode.
  static Map<String, DishModel> dishCache() {
    final now = DateTime.now();
    return {
      for (final entry in _dishData.entries)
        entry.key: DishModel(
          id: entry.key,
          name: entry.value['name'] as String,
          nameEn: entry.value['nameEn'] as String,
          description: entry.value['desc'] as String,
          descriptionEn: entry.value['descEn'] as String,
          calories: (entry.value['cal'] as num).toDouble(),
          protein: (entry.value['protein'] as num).toDouble(),
          carbs: (entry.value['carbs'] as num).toDouble(),
          fat: (entry.value['fat'] as num).toDouble(),
          fiber: (entry.value['fiber'] as num? ?? 4).toDouble(),
          category: entry.value['category'] as String,
          tags: List<String>.from(entry.value['tags'] as List),
          mealType: entry.value['mealType'] as String,
          prepTimeMinutes: (entry.value['prep'] as int? ?? 15),
          cookTimeMinutes: (entry.value['cook'] as int? ?? 20),
          difficulty: 'medium',
          ingredients: const [],
          instructions: const [],
          createdAt: now,
          updatedAt: now,
        ),
    };
  }

  /// 10 food log entries for today — stress-tests the nutrition totals and meal type display.
  static List<FoodLog> todayFoodLogs(String uid) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    const entries = [
      (_breakfast1, 'breakfast', 320.0, 18.0, 22.0, 18.0, 'Geleneksel Köy Menemeni'),
      (_breakfast2, 'breakfast', 280.0, 20.0, 12.0, 16.0, 'Renkli Sebzeli Fit Omlet'),
      (_lunch1,    'lunch',     520.0, 42.0, 18.0, 28.0, 'Izgara Fit Steak & Akdeniz Yeşillikleri'),
      (_lunch3,    'lunch',     340.0, 32.0, 14.0, 12.0, 'Ton Balıklı Salata'),
      (_dinner1,   'dinner',    480.0, 40.0, 16.0, 22.0, 'Izgara Somon & Buharda Sebzeler'),
      (_dinner2,   'dinner',    560.0, 36.0, 48.0, 18.0, 'Geleneksel Etli Nohut Yemeği'),
      (_snack1,    'snack',     280.0, 18.0, 38.0,  6.0, 'Proteinli Orman Meyveli Smoothie Bowl'),
      (_snack2,    'snack',     320.0, 10.0, 54.0,  8.0, 'Yulaf & Kırmızı Meyveli Bowl'),
      (_lunch2,    'lunch',     480.0, 36.0, 38.0, 18.0, 'Somonlu & Avokadolu Kinoa Bowl'),
      (_breakfast5,'breakfast', 360.0, 14.0, 48.0, 10.0, 'Yoğurtlu & Granolalı Kase'),
    ];

    return [
      for (int i = 0; i < entries.length; i++)
        FoodLog(
          id: 'test_log_$i',
          userId: uid,
          mealType: entries[i].$2,
          dishId: entries[i].$1,
          dishName: entries[i].$7,
          calories: entries[i].$3,
          protein: entries[i].$4,
          carbs: entries[i].$5,
          fat: entries[i].$6,
          loggedAt: now.subtract(Duration(hours: 8 - i)),
          date: today,
        ),
    ];
  }

  /// Synthetic weekly food logs for analytics screen in test mode.
  static Map<String, List<FoodLog>> weeklyFoodLogs(
      String uid, DateTime start, DateTime end) {
    final result = <String, List<FoodLog>>{};
    final cals = [1800.0, 2100.0, 0.0, 1950.0, 2200.0, 1700.0, 2050.0];
    final proteins = [120.0, 140.0, 0.0, 130.0, 150.0, 110.0, 135.0];
    final carbs = [200.0, 230.0, 0.0, 210.0, 240.0, 190.0, 220.0];
    final fats = [60.0, 70.0, 0.0, 65.0, 75.0, 55.0, 68.0];
    int i = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final idx = i % cals.length;
      if (cals[idx] == 0) {
        result[key] = [];
      } else {
        result[key] = [
          FoodLog(
            id: 'test_weekly_${key}_1',
            userId: uid,
            mealType: 'breakfast',
            dishId: 'test_dish',
            dishName: 'Test Meal',
            calories: cals[idx],
            protein: proteins[idx],
            carbs: carbs[idx],
            fat: fats[idx],
            loggedAt: d,
            date: key,
          ),
        ];
      }
      i++;
    }
    return result;
  }

  /// 20-item shopping list — stress-tests list rendering and grouping.
  static List<Ingredient> shoppingList() => const [
        Ingredient(name: 'Yumurta', amount: 12, unit: 'adet', calories: 72),
        Ingredient(name: 'Domates', amount: 500, unit: 'g', calories: 90),
        Ingredient(name: 'Ispanak', amount: 200, unit: 'g', calories: 46),
        Ingredient(name: 'Avokado', amount: 3, unit: 'adet', calories: 160),
        Ingredient(name: 'Tavuk Göğsü', amount: 800, unit: 'g', calories: 165),
        Ingredient(name: 'Somon Fileto', amount: 600, unit: 'g', calories: 208),
        Ingredient(name: 'Kinoa', amount: 300, unit: 'g', calories: 368),
        Ingredient(name: 'Yulaf Ezmesi', amount: 500, unit: 'g', calories: 389),
        Ingredient(name: 'Muz', amount: 4, unit: 'adet', calories: 89),
        Ingredient(name: 'Fıstık Ezmesi', amount: 250, unit: 'g', calories: 588),
        Ingredient(name: 'Nohut', amount: 400, unit: 'g', calories: 364),
        Ingredient(name: 'Granola', amount: 300, unit: 'g', calories: 471),
        Ingredient(name: 'Tam Tahıllı Ekmek', amount: 1, unit: 'somun', calories: 265),
        Ingredient(name: 'Biber (Karışık)', amount: 300, unit: 'g', calories: 31),
        Ingredient(name: 'Zeytinyağı', amount: 250, unit: 'ml', calories: 884),
        Ingredient(name: 'Dana Kıyma', amount: 500, unit: 'g', calories: 254),
        Ingredient(name: 'Bulgur', amount: 400, unit: 'g', calories: 342),
        Ingredient(name: 'Ton Balığı (Konserve)', amount: 4, unit: 'kutu', calories: 128),
        Ingredient(name: 'Yunan Yoğurdu', amount: 500, unit: 'g', calories: 97),
        Ingredient(name: 'Limon', amount: 4, unit: 'adet', calories: 29),
      ];

  // ─── Discovery mock data ─────────────────────────────────────────────────────

  static List<GymModel> gyms() {
    final now = DateTime(2025);
    return [
      GymModel(id: 'gym_01', ownerUid: 'test_owner_1', name: 'Iron Palace Gym', description: 'İstanbul\'un en modern fitness merkezi. 1500 m² alan, olimpik havuz ve 3 group ders salonu.', address: 'Bağcılar Mahallesi, Bağcılar Cad. No:12', city: 'İstanbul', district: 'Bağcılar', country: 'TR', isPublic: true, memberCount: 842, subscriptionTier: GymSubscriptionTier.premium, tags: ['powerlifting', 'cardio', 'pool', 'group_classes'], createdAt: now, updatedAt: now, latitude: 41.0389, longitude: 28.8559, isVerified: true),
      GymModel(id: 'gym_02', ownerUid: 'test_owner_2', name: 'FitZone Kadıköy', description: 'Kadıköy\'ün kalbinde 24 saat açık profesyonel spor merkezi. CrossFit ve yoga ağırlıklı program.', address: 'Moda Cad. No:45', city: 'İstanbul', district: 'Kadıköy', country: 'TR', isPublic: true, memberCount: 637, subscriptionTier: GymSubscriptionTier.standard, tags: ['crossfit', 'yoga', 'open_24h'], createdAt: now, updatedAt: now, latitude: 40.9890, longitude: 29.0264, isVerified: true),
      GymModel(id: 'gym_03', ownerUid: 'test_owner_3', name: 'Ankara Sport Club', description: 'Başkentin prestijli spor kulübü. 2 olimpik yüzme havuzu, tenis kortları ve kapalı atletizm pisti.', address: 'Çankaya Bul. No:88', city: 'Ankara', district: 'Çankaya', country: 'TR', isPublic: true, memberCount: 1240, subscriptionTier: GymSubscriptionTier.premium, tags: ['pool', 'tennis', 'athletics', 'sauna'], createdAt: now, updatedAt: now, latitude: 39.9208, longitude: 32.8541, isVerified: true),
      GymModel(id: 'gym_04', ownerUid: 'test_owner_4', name: 'Pulse Fitness Beşiktaş', description: 'Boğaz manzaralı butik spor salonu. Özel antrenman programları ve beslenme danışmanlığı.', address: 'Barbaros Bul. No:67', city: 'İstanbul', district: 'Beşiktaş', country: 'TR', isPublic: true, memberCount: 389, subscriptionTier: GymSubscriptionTier.standard, tags: ['boutique', 'personal_training', 'nutrition'], createdAt: now, updatedAt: now, latitude: 41.0438, longitude: 29.0073),
      GymModel(id: 'gym_05', ownerUid: 'test_owner_5', name: 'SmartFit İzmir', description: 'İzmir\'in en hızlı büyüyen fitness zinciri. AI destekli antrenman takibi ve akıllı ekipmanlar.', address: 'Alsancak Mah. No:23', city: 'İzmir', district: 'Konak', country: 'TR', isPublic: true, memberCount: 520, subscriptionTier: GymSubscriptionTier.premium, tags: ['ai_training', 'smart_equipment', 'cardio'], createdAt: now, updatedAt: now, latitude: 38.4189, longitude: 27.1287, isVerified: true),
      GymModel(id: 'gym_06', ownerUid: 'test_owner_6', name: 'BodyCraft Gym Şişli', description: 'Vücut geliştirme ve powerlifting odaklı profesyonel salon. 500+ makine ve serbest ağırlık alanı.', address: 'Halaskargazi Cad. No:102', city: 'İstanbul', district: 'Şişli', country: 'TR', isPublic: true, memberCount: 478, subscriptionTier: GymSubscriptionTier.standard, tags: ['bodybuilding', 'powerlifting', 'heavy_weights'], createdAt: now, updatedAt: now, latitude: 41.0579, longitude: 28.9931),
      GymModel(id: 'gym_07', ownerUid: 'test_owner_7', name: 'Zen Wellness Nişantaşı', description: 'Pilates, yoga ve meditasyon odaklı bütünsel wellness merkezi. Sauna ve spa hizmetleri dahil.', address: 'Teşvikiye Cad. No:18', city: 'İstanbul', district: 'Nişantaşı', country: 'TR', isPublic: true, memberCount: 215, subscriptionTier: GymSubscriptionTier.premium, tags: ['yoga', 'pilates', 'meditation', 'spa', 'sauna'], createdAt: now, updatedAt: now, latitude: 41.0490, longitude: 28.9972, isVerified: true),
      GymModel(id: 'gym_08', ownerUid: 'test_owner_8', name: 'Champion Bursa', description: 'Bursa\'nın şampiyonlar salonu. Profesyonel boks, güreş ve mücadele sanatları ekipmanları.', address: 'Osmangazi Cad. No:55', city: 'Bursa', district: 'Osmangazi', country: 'TR', isPublic: true, memberCount: 310, subscriptionTier: GymSubscriptionTier.standard, tags: ['boxing', 'wrestling', 'martial_arts', 'mma'], createdAt: now, updatedAt: now, latitude: 40.1826, longitude: 29.0669),
    ];
  }

  static List<CoachProfileModel> coaches() {
    final now = DateTime(2025);
    return [
      CoachProfileModel(uid: 'coach_01', displayName: 'Ahmet Yılmaz', bio: 'NASM sertifikalı kişisel antrenör. 10 yıllık deneyimle vücut geliştirme ve fonksiyonel antrenman uzmanlığı.', specializations: ['bodybuilding', 'functional_training', 'nutrition'], certifications: ['NASM-CPT', 'PN1'], isAcceptingClients: true, clientCount: 48, hourlyRate: 350, isPublic: true, createdAt: now, updatedAt: now, city: 'İstanbul', district: 'Kadıköy', avgRating: 4.9, ratingCount: 127, isVerified: true, latitude: 40.9897, longitude: 29.0280),
      CoachProfileModel(uid: 'coach_02', displayName: 'Zeynep Kaya', bio: 'Kadın antrenmanı ve pre/post natal fitness uzmanı. ACE ve AFAA sertifikalı. Online ve yüz yüze program.', specializations: ['womens_fitness', 'prenatal', 'yoga', 'pilates'], certifications: ['ACE-CPT', 'AFAA-PFT'], isAcceptingClients: true, clientCount: 62, hourlyRate: 400, isPublic: true, createdAt: now, updatedAt: now, city: 'İstanbul', district: 'Beşiktaş', avgRating: 4.8, ratingCount: 94, isVerified: true),
      CoachProfileModel(uid: 'coach_03', displayName: 'Mehmet Demir', bio: 'Eski milli güreşçi, şimdi CrossFit Level 2 antrenör. Kondisyon, güç ve dayanıklılık programları.', specializations: ['crossfit', 'strength', 'conditioning', 'wrestling'], certifications: ['CF-L2', 'CSCS'], isAcceptingClients: true, clientCount: 35, hourlyRate: 500, isPublic: true, createdAt: now, updatedAt: now, city: 'Ankara', district: 'Çankaya', avgRating: 4.7, ratingCount: 56, isVerified: true),
      CoachProfileModel(uid: 'coach_04', displayName: 'Selin Arslan', bio: 'Beslenme bilimi mezunu sporcu diyetisyen & fitness koç. Kilo yönetimi ve spor performansı odaklı.', specializations: ['nutrition', 'weight_loss', 'sports_performance'], certifications: ['RD', 'CISSN', 'ACE-CHC'], isAcceptingClients: true, clientCount: 87, hourlyRate: 450, isPublic: true, createdAt: now, updatedAt: now, city: 'İstanbul', district: 'Şişli', avgRating: 4.9, ratingCount: 203, isVerified: true),
      CoachProfileModel(uid: 'coach_05', displayName: 'Burak Şahin', bio: 'Powerlifting ve olimpik halter uzmanı. IPF milli takım antrenörü, 3 kez Türkiye şampiyonu.', specializations: ['powerlifting', 'olympic_weightlifting', 'strength'], certifications: ['NSCA-CSCS', 'USAW-L2'], isAcceptingClients: false, clientCount: 24, hourlyRate: 600, isPublic: true, createdAt: now, updatedAt: now, city: 'İzmir', district: 'Konak', avgRating: 5.0, ratingCount: 41, isVerified: true),
      CoachProfileModel(uid: 'coach_06', displayName: 'Elif Bozkurt', bio: 'Yoga ve meditasyon rehberi. Hatha, Vinyasa ve Restoratif yoga öğretmeni. Stres yönetimi programları.', specializations: ['yoga', 'meditation', 'mindfulness', 'flexibility'], certifications: ['RYT-500', 'YACEP'], isAcceptingClients: true, clientCount: 71, hourlyRate: 300, isPublic: true, createdAt: now, updatedAt: now, city: 'İstanbul', district: 'Nişantaşı', avgRating: 4.8, ratingCount: 118, isVerified: true),
      CoachProfileModel(uid: 'coach_07', displayName: 'Kerem Doğan', bio: 'Bisiklet ve koşu antrenörü. Triatlon bitirme garantisi programı. Online ve yüz yüze coaching.', specializations: ['cycling', 'running', 'triathlon', 'endurance'], certifications: ['USA-T', 'USAC-L2'], isAcceptingClients: true, clientCount: 29, hourlyRate: 380, isPublic: true, createdAt: now, updatedAt: now, city: 'Ankara', district: 'Keçiören', avgRating: 4.6, ratingCount: 37),
      CoachProfileModel(uid: 'coach_08', displayName: 'Ayşe Güven', bio: 'Pilates ve rehabilitasyon uzmanı. Sakatlık sonrası geri dönüş ve postür düzeltme programları.', specializations: ['pilates', 'rehabilitation', 'posture', 'injury_recovery'], certifications: ['STOTT-PILATES', 'PMA-CPT'], isAcceptingClients: true, clientCount: 53, hourlyRate: 420, isPublic: true, createdAt: now, updatedAt: now, city: 'Bursa', district: 'Nilüfer', avgRating: 4.7, ratingCount: 79, isVerified: true),
    ];
  }

  /// 10-entry leaderboard for a test gym — stress-tests the leaderboard display.
  static List<LeaderboardEntryModel> gymLeaderboard() => const [
        LeaderboardEntryModel(uid: 'member_01', displayName: 'Elif Kaya', checkInCount: 28, streak: 14, rank: 1),
        LeaderboardEntryModel(uid: 'member_02', displayName: 'Ahmet Çelik', checkInCount: 24, streak: 12, rank: 2),
        LeaderboardEntryModel(uid: 'member_03', displayName: 'Zeynep Demir', checkInCount: 21, streak: 10, rank: 3),
        LeaderboardEntryModel(uid: 'member_04', displayName: 'Mert Yıldız', checkInCount: 19, streak: 8, rank: 4),
        LeaderboardEntryModel(uid: 'member_05', displayName: 'Selin Arslan', checkInCount: 17, streak: 7, rank: 5),
        LeaderboardEntryModel(uid: 'member_06', displayName: 'Burak Öztürk', checkInCount: 15, streak: 5, rank: 6),
        LeaderboardEntryModel(uid: 'member_07', displayName: 'Ayşe Güneş', checkInCount: 13, streak: 4, rank: 7),
        LeaderboardEntryModel(uid: 'member_08', displayName: 'Kerem Yılmaz', checkInCount: 11, streak: 3, rank: 8),
        LeaderboardEntryModel(uid: 'member_09', displayName: 'Fatma Şahin', checkInCount: 9, streak: 2, rank: 9),
        LeaderboardEntryModel(uid: 'member_10', displayName: 'Ali Koç', checkInCount: 7, streak: 1, rank: 10),
      ];

  // --- Private helpers ---

  static const _dishMacros = <String, Map<String, double>>{
    _breakfast1: {'cal': 320, 'protein': 18, 'carbs': 22, 'fat': 18},
    _breakfast2: {'cal': 280, 'protein': 20, 'carbs': 12, 'fat': 16},
    _breakfast3: {'cal': 380, 'protein': 12, 'carbs': 52, 'fat': 14},
    _breakfast4: {'cal': 340, 'protein': 16, 'carbs': 14, 'fat': 24},
    _breakfast5: {'cal': 360, 'protein': 14, 'carbs': 48, 'fat': 10},
    _lunch1:     {'cal': 520, 'protein': 42, 'carbs': 18, 'fat': 28},
    _lunch2:     {'cal': 480, 'protein': 36, 'carbs': 38, 'fat': 18},
    _lunch3:     {'cal': 340, 'protein': 32, 'carbs': 14, 'fat': 12},
    _lunch4:     {'cal': 380, 'protein': 18, 'carbs': 48, 'fat': 12},
    _lunch5:     {'cal': 420, 'protein': 38, 'carbs': 22, 'fat': 14},
    _dinner1:    {'cal': 480, 'protein': 40, 'carbs': 16, 'fat': 22},
    _dinner2:    {'cal': 560, 'protein': 36, 'carbs': 48, 'fat': 18},
    _dinner3:    {'cal': 620, 'protein': 34, 'carbs': 64, 'fat': 22},
    _dinner4:    {'cal': 580, 'protein': 38, 'carbs': 48, 'fat': 26},
    _dinner5:    {'cal': 640, 'protein': 44, 'carbs': 42, 'fat': 28},
    _snack1:     {'cal': 280, 'protein': 18, 'carbs': 38, 'fat':  6},
    _snack2:     {'cal': 320, 'protein': 10, 'carbs': 54, 'fat':  8},
  };

  static const _dishData = <String, Map<String, Object>>{
    _breakfast1: {
      'name': 'Geleneksel Köy Menemeni',
      'nameEn': 'Traditional Village Menemen',
      'desc': 'Sulu domates, biber ve yumurtadan yapılan klasik Türk kahvaltısı.',
      'descEn': 'Classic Turkish breakfast made with juicy tomatoes, peppers and eggs.',
      'cal': 320, 'protein': 18, 'carbs': 22, 'fat': 18,
      'category': 'breakfast', 'mealType': 'breakfast',
      'tags': ['turkish_classic', 'protein'], 'prep': 5, 'cook': 15,
    },
    _breakfast2: {
      'name': 'Renkli Sebzeli Fit Omlet',
      'nameEn': 'Colorful Vegetable Fit Omelette',
      'desc': 'Ispanak, domates ve biberle hazırlanan düşük kalorili protein omlet.',
      'descEn': 'Low-calorie protein omelette with spinach, tomatoes and peppers.',
      'cal': 280, 'protein': 20, 'carbs': 12, 'fat': 16,
      'category': 'breakfast', 'mealType': 'breakfast',
      'tags': ['low_carb', 'high_protein', 'fit'], 'prep': 5, 'cook': 10,
    },
    _breakfast3: {
      'name': 'Muzlu & Fıstık Ezmeli Yulaf',
      'nameEn': 'Banana & Peanut Butter Oat Bowl',
      'desc': 'Muz, fıstık ezmesi ve bal ile zenginleştirilmiş kremalı yulaf lapası.',
      'descEn': 'Creamy oatmeal enriched with banana, peanut butter and honey.',
      'cal': 380, 'protein': 12, 'carbs': 52, 'fat': 14,
      'category': 'breakfast', 'mealType': 'breakfast',
      'tags': ['energy', 'fiber'], 'prep': 5, 'cook': 10,
    },
    _breakfast4: {
      'name': 'Avokadolu Yumurta Tabağı',
      'nameEn': 'Avocado Egg Plate',
      'desc': 'Tam tahıllı ekmek üzerinde avokado kreması ve haşlanmış yumurta.',
      'descEn': 'Whole grain toast with avocado cream and soft boiled eggs.',
      'cal': 340, 'protein': 16, 'carbs': 14, 'fat': 24,
      'category': 'breakfast', 'mealType': 'breakfast',
      'tags': ['healthy_fat', 'protein'], 'prep': 10, 'cook': 10,
    },
    _breakfast5: {
      'name': 'Yoğurtlu & Granolalı Kase',
      'nameEn': 'Yogurt & Granola Bowl',
      'desc': 'Ev yapımı granola, taze mevsim meyveleri ve yoğurtla hazırlanan kase.',
      'descEn': 'Bowl with homemade granola, fresh seasonal fruits and yogurt.',
      'cal': 360, 'protein': 14, 'carbs': 48, 'fat': 10,
      'category': 'breakfast', 'mealType': 'breakfast',
      'tags': ['fiber', 'calcium'], 'prep': 5, 'cook': 0,
    },
    _lunch1: {
      'name': 'Izgara Fit Steak & Akdeniz Yeşillikleri',
      'nameEn': 'Grilled Fit Steak & Mediterranean Greens',
      'desc': 'Izgara bonfile, roka, cherry domates ve zeytinyağı ile Akdeniz salatası.',
      'descEn': 'Grilled sirloin, arugula, cherry tomatoes and olive oil Mediterranean salad.',
      'cal': 520, 'protein': 42, 'carbs': 18, 'fat': 28,
      'category': 'meat', 'mealType': 'lunch',
      'tags': ['high_protein', 'low_carb', 'keto_friendly'], 'prep': 10, 'cook': 15,
    },
    _lunch2: {
      'name': 'Somonlu & Avokadolu Kinoa Bowl',
      'nameEn': 'Salmon & Avocado Quinoa Bowl',
      'desc': 'Izgara somon, avokado, edamame ve kinoa ile hazırlanan omega-3 açısından zengin kase.',
      'descEn': 'Grilled salmon, avocado, edamame and quinoa bowl rich in omega-3.',
      'cal': 480, 'protein': 36, 'carbs': 38, 'fat': 18,
      'category': 'fish', 'mealType': 'lunch',
      'tags': ['omega3', 'high_protein', 'balanced'], 'prep': 15, 'cook': 20,
    },
    _lunch3: {
      'name': 'Ton Balıklı Akdeniz Salatası',
      'nameEn': 'Tuna Mediterranean Salad',
      'desc': 'Konserve ton balığı, fasulye, zeytin ve bol sebze ile hafif öğle salatası.',
      'descEn': 'Canned tuna, beans, olives and greens light lunch salad.',
      'cal': 340, 'protein': 32, 'carbs': 14, 'fat': 12,
      'category': 'fish', 'mealType': 'lunch',
      'tags': ['diet', 'high_protein', 'quick'], 'prep': 10, 'cook': 0,
    },
    _lunch4: {
      'name': 'Nohutlu & Izgara Sebze Bowl',
      'nameEn': 'Chickpea & Grilled Vegetable Bowl',
      'desc': 'Közlenmiş sebzeler, nohut, tahini sos ve taze otlar ile doyurucu bowl.',
      'descEn': 'Roasted vegetables, chickpeas, tahini sauce and fresh herbs filling bowl.',
      'cal': 380, 'protein': 18, 'carbs': 48, 'fat': 12,
      'category': 'vegetarian', 'mealType': 'lunch',
      'tags': ['vegan', 'fiber', 'plant_protein'], 'prep': 10, 'cook': 20,
    },
    _lunch5: {
      'name': 'Izgara Tavuk & Yeşil Salata',
      'nameEn': 'Grilled Chicken & Green Salad',
      'desc': 'Marine edilmiş ızgara tavuk göğsü ve karışık yeşil yaprak salatası.',
      'descEn': 'Marinated grilled chicken breast with mixed green leaf salad.',
      'cal': 420, 'protein': 38, 'carbs': 22, 'fat': 14,
      'category': 'chicken', 'mealType': 'lunch',
      'tags': ['high_protein', 'diet', 'quick'], 'prep': 10, 'cook': 15,
    },
    _dinner1: {
      'name': 'Izgara Somon & Buharda Sebzeler',
      'nameEn': 'Grilled Salmon & Steamed Vegetables',
      'desc': 'Limonlu ızgara somon filetosu, buharda pişirilmiş brokoli ve havuç.',
      'descEn': 'Lemon grilled salmon fillet with steamed broccoli and carrots.',
      'cal': 480, 'protein': 40, 'carbs': 16, 'fat': 22,
      'category': 'fish', 'mealType': 'dinner',
      'tags': ['omega3', 'high_protein', 'balanced'], 'prep': 10, 'cook': 20,
    },
    _dinner2: {
      'name': 'Geleneksel Etli Nohut Yemeği',
      'nameEn': 'Traditional Meat & Chickpea Stew',
      'desc': 'Dana etiyle pişirilmiş geleneksel Türk nohut yemeği, yanında pilav.',
      'descEn': 'Traditional Turkish chickpea stew cooked with beef, served with rice.',
      'cal': 560, 'protein': 36, 'carbs': 48, 'fat': 18,
      'category': 'turkish_classic', 'mealType': 'dinner',
      'tags': ['turkish_classic', 'high_protein', 'fiber'], 'prep': 15, 'cook': 90,
    },
    _dinner3: {
      'name': 'Ev Yapımı Soslu Etli Makarna',
      'nameEn': 'Homemade Meat Sauce Pasta',
      'desc': 'Ev yapımı bolonez sos ve tam tahıllı makarna ile klasik İtalyan tarifi.',
      'descEn': 'Classic Italian recipe with homemade bolognese sauce and whole grain pasta.',
      'cal': 620, 'protein': 34, 'carbs': 64, 'fat': 22,
      'category': 'meat', 'mealType': 'dinner',
      'tags': ['high_protein', 'energy'], 'prep': 15, 'cook': 45,
    },
    _dinner4: {
      'name': 'Geleneksel Izgara Köfte & Domatesli Bulgur',
      'nameEn': 'Traditional Grilled Meatballs & Tomato Bulgur',
      'desc': 'Baharatlı köfte ve tereyağlı domatesli bulgur pilavı klasik Türk yemeği.',
      'descEn': 'Spiced meatballs with buttery tomato bulgur pilaf classic Turkish dish.',
      'cal': 580, 'protein': 38, 'carbs': 48, 'fat': 26,
      'category': 'turkish_classic', 'mealType': 'dinner',
      'tags': ['turkish_classic', 'high_protein', 'fiber'], 'prep': 20, 'cook': 30,
    },
    _dinner5: {
      'name': 'Dana Bonfile & Fırın Patates',
      'nameEn': 'Beef Tenderloin & Oven Potatoes',
      'desc': 'Aromalı dana bonfile, fırınlanmış patates ve ratatouille yanında.',
      'descEn': 'Aromatic beef tenderloin, roasted potatoes and ratatouille side.',
      'cal': 640, 'protein': 44, 'carbs': 42, 'fat': 28,
      'category': 'meat', 'mealType': 'dinner',
      'tags': ['high_protein', 'gourmet'], 'prep': 20, 'cook': 35,
    },
    _snack1: {
      'name': 'Proteinli Orman Meyveli Smoothie Bowl',
      'nameEn': 'Protein Forest Berry Smoothie Bowl',
      'desc': 'Protein tozu, orman meyveleri, muz ve granola ile doyurucu smoothie bowl.',
      'descEn': 'Filling smoothie bowl with protein powder, forest berries, banana and granola.',
      'cal': 280, 'protein': 18, 'carbs': 38, 'fat': 6,
      'category': 'sport', 'mealType': 'snack',
      'tags': ['high_protein', 'sport', 'quick'], 'prep': 5, 'cook': 0,
    },
    _snack2: {
      'name': 'Yulaf & Kırmızı Meyveli Bowl',
      'nameEn': 'Oat & Red Berry Bowl',
      'desc': 'Yulaf ezmesi, çilek, ahududu ve bal ile antioksidan açısından zengin kase.',
      'descEn': 'Antioxidant-rich bowl with oatmeal, strawberries, raspberries and honey.',
      'cal': 320, 'protein': 10, 'carbs': 54, 'fat': 8,
      'category': 'breakfast', 'mealType': 'snack',
      'tags': ['fiber', 'antioxidant', 'quick'], 'prep': 5, 'cook': 5,
    },
  };

  // ── Admin: mock users (Test Mode) ─────────────────────────────────────────
  /// User maps shaped like Firestore `users/{uid}` docs for the admin panel.
  static List<Map<String, dynamic>> adminUsers() {
    final base = DateTime(2025, 3);
    final rows = <List<dynamic>>[
      // [name, email, role, banned, daysAgo]
      ['Ayşe Yılmaz', 'ayse@example.com', 'consumer', false, 3],
      ['Mehmet Demir', 'mehmet@example.com', 'coach', false, 12],
      ['Zeynep Kaya', 'zeynep@example.com', 'gym_owner', false, 25],
      ['Can Öztürk', 'can@example.com', 'consumer', true, 40],
      ['Elif Şahin', 'elif@example.com', 'admin', false, 60],
      ['Burak Aydın', 'burak@example.com', 'consumer', false, 70],
      ['Deniz Arslan', 'deniz@example.com', 'coach', false, 95],
      ['Selin Doğan', 'selin@example.com', 'consumer', false, 110],
    ];
    return [
      for (var i = 0; i < rows.length; i++)
        {
          'uid': 'test_user_$i',
          'display_name': rows[i][0],
          'email': rows[i][1],
          'user_role': rows[i][2],
          'is_banned': rows[i][3],
          'created_at':
              Timestamp.fromDate(base.subtract(Duration(days: rows[i][4] as int))),
        },
    ];
  }
}
