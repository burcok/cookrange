import 'package:flutter/material.dart';

class OnboardingOptions {
  // Activity Levels
  static const Map<String, Map<String, dynamic>> activityLevels = {
    'sedentary': {
      'label': 'onboarding.page2.activity_level.sedentary',
      'icon': Icons.weekend,
    },
    'light': {
      'label': 'onboarding.page2.activity_level.light',
      'icon': Icons.directions_walk,
    },
    'moderate': {
      'label': 'onboarding.page2.activity_level.moderate',
      'icon': Icons.directions_run,
    },
    'active': {
      'label': 'onboarding.page2.activity_level.active',
      'icon': Icons.emoji_events,
    },
  };

  // Primary Goals
  static const Map<String, Map<String, dynamic>> primaryGoals = {
    'lose_weight': {
      'label': 'onboarding.page2.primary_goal.lose_weight',
      'icon': Icons.trending_down,
    },
    'gain_weight': {
      'label': 'onboarding.page2.primary_goal.gain_weight',
      'icon': Icons.trending_up,
    },
    'maintain_weight': {
      'label': 'onboarding.page2.primary_goal.maintain_weight',
      'icon': Icons.balance,
    },
    'feel_energetic': {
      'label': 'onboarding.page2.primary_goal.feel_energetic',
      'icon': Icons.flash_on,
    },
    'mental_clarity': {
      'label': 'onboarding.page2.primary_goal.mental_clarity',
      'icon': Icons.psychology,
    },
    'healthy_eating': {
      'label': 'onboarding.page2.primary_goal.healthy_eating',
      'icon': Icons.favorite,
    },
    'save_time': {
      'label': 'onboarding.page2.primary_goal.save_time',
      'icon': Icons.schedule,
    },
    'improve_sleep': {
      'label': 'onboarding.page2.primary_goal.improve_sleep',
      'icon': Icons.bedtime,
    },
    'increase_muscle': {
      'label': 'onboarding.page2.primary_goal.increase_muscle',
      'icon': Icons.fitness_center,
    },
    'body_shaping': {
      'label': 'onboarding.page2.primary_goal.body_shaping',
      'icon': Icons.accessibility_new,
    },
    'stress_management': {
      'label': 'onboarding.page2.primary_goal.stress_management',
      'icon': Icons.self_improvement,
    },
    'digestive_health': {
      'label': 'onboarding.page2.primary_goal.digestive_health',
      'icon': Icons.healing,
    },
    'immune_boost': {
      'label': 'onboarding.page2.primary_goal.immune_boost',
      'icon': Icons.health_and_safety,
    },
    'sustainable_lifestyle': {
      'label': 'onboarding.page2.primary_goal.sustainable_lifestyle',
      'icon': Icons.eco,
    },
  };

  // Cooking Levels
  static const Map<String, Map<String, dynamic>> cookingLevels = {
    'beginner': {
      'label': 'onboarding.page4.cooking_level.beginner',
      'icon': Icons.school,
    },
    'intermediate': {
      'label': 'onboarding.page4.cooking_level.intermediate',
      'icon': Icons.restaurant,
    },
    'advanced': {
      'label': 'onboarding.page4.cooking_level.advanced',
      'icon': Icons.star,
    },
  };

  // Kitchen Equipment
  static const Map<String, String> kitchenEquipment = {
    'stove': 'onboarding.page4.kitchen_equipment.stove',
    'oven': 'onboarding.page4.kitchen_equipment.oven',
    'microwave': 'onboarding.page4.kitchen_equipment.microwave',
    'pressure_cooker': 'onboarding.page4.kitchen_equipment.pressure_cooker',
    'electric_kettle': 'onboarding.page4.kitchen_equipment.electric_kettle',
    'coffee_maker': 'onboarding.page4.kitchen_equipment.coffee_maker',
    'grinder': 'onboarding.page4.kitchen_equipment.grinder',
    'toaster': 'onboarding.page4.kitchen_equipment.toaster',
    'blender': 'onboarding.page4.kitchen_equipment.blender',
    'hand_mixer': 'onboarding.page4.kitchen_equipment.hand_mixer',
    'stand_mixer': 'onboarding.page4.kitchen_equipment.stand_mixer',
    'air_fryer': 'onboarding.page4.kitchen_equipment.air_fryer',
    'electric_grill': 'onboarding.page4.kitchen_equipment.electric_grill',
    'samovar': 'onboarding.page4.kitchen_equipment.samovar',
    'turkish_coffee_pot':
        'onboarding.page4.kitchen_equipment.turkish_coffee_pot',
    'tea_pot': 'onboarding.page4.kitchen_equipment.tea_pot',
  };

  // Lifestyle Profiles
  static const Map<String, Map<String, dynamic>> lifestyleProfiles = {
    'early_bird': {
      'label': 'onboarding.page5.profiles.early_bird.name',
      'image': 'assets/images/onboarding/onboarding-5-1.png',
      'mealTimes': ['07:00', '12:00', '18:00'],
    },
    'worker': {
      'label': 'onboarding.page5.profiles.worker.name',
      'image': 'assets/images/onboarding/onboarding-5-2.png',
      'mealTimes': ['08:00', '13:00', '19:00'],
    },
    'night_owl': {
      'label': 'onboarding.page5.profiles.night_owl.name',
      'image': 'assets/images/onboarding/onboarding-5-3.png',
      'mealTimes': ['11:00', '16:00', '21:00'],
    },
    'rotating_shifts': {
      'label': 'onboarding.page5.profiles.rotating_shifts.name',
      'image': 'assets/images/onboarding/onboarding-5-4.png',
      'mealTimes': [],
    },
    'irregular_schedule': {
      'label': 'onboarding.page5.profiles.irregular_schedule.name',
      'image': 'assets/images/onboarding/onboarding-5-5.png',
      'mealTimes': [],
    },
  };

  // Disliked Foods (Predefined ones from page 3)
  static const Map<String, Map<String, dynamic>> predefinedIngredients = {
    // Vegetables
    'broccoli': {
      'label': 'ingredients.vegetables.broccoli',
      'icon': Icons.eco,
    },
    'cauliflower': {
      'label': 'ingredients.vegetables.cauliflower',
      'icon': Icons.eco,
    },
    'spinach': {
      'label': 'ingredients.vegetables.spinach',
      'icon': Icons.eco,
    },
    'kale': {
      'label': 'ingredients.vegetables.kale',
      'icon': Icons.eco,
    },
    'lettuce': {
      'label': 'ingredients.vegetables.lettuce',
      'icon': Icons.eco,
    },
    'arugula': {
      'label': 'ingredients.vegetables.arugula',
      'icon': Icons.eco,
    },
    'cabbage': {
      'label': 'ingredients.vegetables.cabbage',
      'icon': Icons.eco,
    },
    'brussels_sprouts': {
      'label': 'ingredients.vegetables.brussels_sprouts',
      'icon': Icons.eco,
    },
    'asparagus': {
      'label': 'ingredients.vegetables.asparagus',
      'icon': Icons.eco,
    },
    'green_beans': {
      'label': 'ingredients.vegetables.green_beans',
      'icon': Icons.eco,
    },
    // Fruits
    'apples': {
      'label': 'ingredients.fruits.apples',
      'icon': Icons.circle,
    },
    'bananas': {
      'label': 'ingredients.fruits.bananas',
      'icon': Icons.circle,
    },
    'oranges': {
      'label': 'ingredients.fruits.oranges',
      'icon': Icons.circle,
    },
    'strawberries': {
      'label': 'ingredients.fruits.strawberries',
      'icon': Icons.circle,
    },
    'blueberries': {
      'label': 'ingredients.fruits.blueberries',
      'icon': Icons.circle,
    },
    'raspberries': {
      'label': 'ingredients.fruits.raspberries',
      'icon': Icons.circle,
    },
    'grapes': {
      'label': 'ingredients.fruits.grapes',
      'icon': Icons.circle,
    },
    'pineapple': {
      'label': 'ingredients.fruits.pineapple',
      'icon': Icons.circle,
    },
    'mango': {
      'label': 'ingredients.fruits.mango',
      'icon': Icons.circle,
    },
    'kiwi': {
      'label': 'ingredients.fruits.kiwi',
      'icon': Icons.circle,
    },
    // Proteins
    'chicken': {
      'label': 'ingredients.proteins.chicken',
      'icon': Icons.fitness_center,
    },
    'beef': {
      'label': 'ingredients.proteins.beef',
      'icon': Icons.fitness_center,
    },
    'pork': {
      'label': 'ingredients.proteins.pork',
      'icon': Icons.fitness_center,
    },
    'lamb': {
      'label': 'ingredients.proteins.lamb',
      'icon': Icons.fitness_center,
    },
    'turkey': {
      'label': 'ingredients.proteins.turkey',
      'icon': Icons.fitness_center,
    },
    'duck': {
      'label': 'ingredients.proteins.duck',
      'icon': Icons.fitness_center,
    },
    'fish': {
      'label': 'ingredients.proteins.fish',
      'icon': Icons.water_drop,
    },
    'salmon': {
      'label': 'ingredients.proteins.salmon',
      'icon': Icons.water_drop,
    },
    'tuna': {
      'label': 'ingredients.proteins.tuna',
      'icon': Icons.water_drop,
    },
    'shrimp': {
      'label': 'ingredients.proteins.shrimp',
      'icon': Icons.water_drop,
    },
    // Dairy & Eggs
    'milk': {
      'label': 'ingredients.dairy_eggs.milk',
      'icon': Icons.water_drop,
    },
    'cheese': {
      'label': 'ingredients.dairy_eggs.cheese',
      'icon': Icons.circle,
    },
    'yogurt': {
      'label': 'ingredients.dairy_eggs.yogurt',
      'icon': Icons.circle,
    },
    'butter': {
      'label': 'ingredients.dairy_eggs.butter',
      'icon': Icons.circle,
    },
    'cream': {
      'label': 'ingredients.dairy_eggs.cream',
      'icon': Icons.circle,
    },
    'eggs': {
      'label': 'ingredients.dairy_eggs.eggs',
      'icon': Icons.circle,
    },
    'cottage_cheese': {
      'label': 'ingredients.dairy_eggs.cottage_cheese',
      'icon': Icons.circle,
    },
    'sour_cream': {
      'label': 'ingredients.dairy_eggs.sour_cream',
      'icon': Icons.circle,
    },
    'ice_cream': {
      'label': 'ingredients.dairy_eggs.ice_cream',
      'icon': Icons.circle,
    },
    'whipped_cream': {
      'label': 'ingredients.dairy_eggs.whipped_cream',
      'icon': Icons.circle,
    },
    // Grains
    'rice': {
      'label': 'ingredients.grains.rice',
      'icon': Icons.grain,
    },
    'pasta': {
      'label': 'ingredients.grains.pasta',
      'icon': Icons.grain,
    },
    'bread': {
      'label': 'ingredients.grains.bread',
      'icon': Icons.grain,
    },
    'oats': {
      'label': 'ingredients.grains.oats',
      'icon': Icons.grain,
    },
    'quinoa': {
      'label': 'ingredients.grains.quinoa',
      'icon': Icons.grain,
    },
    'barley': {
      'label': 'ingredients.grains.barley',
      'icon': Icons.grain,
    },
    'wheat': {
      'label': 'ingredients.grains.wheat',
      'icon': Icons.grain,
    },
    'corn': {
      'label': 'ingredients.grains.corn',
      'icon': Icons.grain,
    },
    'buckwheat': {
      'label': 'ingredients.grains.buckwheat',
      'icon': Icons.grain,
    },
    'millet': {
      'label': 'ingredients.grains.millet',
      'icon': Icons.grain,
    },
    // Nuts & Seeds
    'almonds': {
      'label': 'ingredients.nuts_seeds.almonds',
      'icon': Icons.circle,
    },
    'walnuts': {
      'label': 'ingredients.nuts_seeds.walnuts',
      'icon': Icons.circle,
    },
    'cashews': {
      'label': 'ingredients.nuts_seeds.cashews',
      'icon': Icons.circle,
    },
    'pistachios': {
      'label': 'ingredients.nuts_seeds.pistachios',
      'icon': Icons.circle,
    },
    'pecans': {
      'label': 'ingredients.nuts_seeds.pecans',
      'icon': Icons.circle,
    },
    'hazelnuts': {
      'label': 'ingredients.nuts_seeds.hazelnuts',
      'icon': Icons.circle,
    },
    'sunflower_seeds': {
      'label': 'ingredients.nuts_seeds.sunflower_seeds',
      'icon': Icons.circle,
    },
    'pumpkin_seeds': {
      'label': 'ingredients.nuts_seeds.pumpkin_seeds',
      'icon': Icons.circle,
    },
    'chia_seeds': {
      'label': 'ingredients.nuts_seeds.chia_seeds',
      'icon': Icons.circle,
    },
    'flax_seeds': {
      'label': 'ingredients.nuts_seeds.flax_seeds',
      'icon': Icons.circle,
    },
  };
}
