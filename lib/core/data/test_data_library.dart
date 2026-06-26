import '../models/dish_model.dart';
import '../models/food_log_model.dart';
import '../models/ingredient_model.dart';
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

    final totalCal = days.fold(0.0, (sum, d) => sum + d.totalCalories);

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
}
