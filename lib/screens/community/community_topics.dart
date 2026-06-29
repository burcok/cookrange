import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Hardcoded community topic constants.
/// DO NOT make these dynamic or configurable — they are intentional design
/// decisions aligned with the brand's nutrition+fitness positioning.
class CommunityTopics {
  CommunityTopics._();

  static const String fatLoss = 'fat_loss';
  static const String muscleBuilding = 'muscle_building';
  static const String vegetarian = 'vegetarian';
  static const String endurance = 'endurance';
  static const String wellness = 'wellness';

  /// All topic constants in display order.
  static const List<String> all = [
    fatLoss,
    muscleBuilding,
    vegetarian,
    endurance,
    wellness,
  ];

  /// Maps a topic constant to a brand-aligned semantic color.
  static Color colorFor(String topic, AppPalette palette) {
    switch (topic) {
      case fatLoss:
        return palette.error; // red/warm = fat burn
      case muscleBuilding:
        return palette.protein; // blue/cool = muscle
      case vegetarian:
        return palette.success; // green = plant-based
      case endurance:
        return palette.energy; // teal = endurance
      default:
        return AppPalette.brand; // orange = wellness/general
    }
  }

  /// Returns the i18n key for the given topic constant.
  static String labelKeyFor(String topic) {
    switch (topic) {
      case fatLoss:
        return 'community.topic_fat_loss';
      case muscleBuilding:
        return 'community.topic_muscle';
      case vegetarian:
        return 'community.topic_vegetarian';
      case endurance:
        return 'community.topic_endurance';
      default:
        return 'community.topic_wellness';
    }
  }
}
