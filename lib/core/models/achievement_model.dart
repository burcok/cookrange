import 'package:cloud_firestore/cloud_firestore.dart';

/// All achievable badge keys. Stored as the enum `.name` in Firestore.
enum AchievementKey {
  firstMealLogged,
  firstPhotoLog,
  firstPost,
  firstCook,
  streak7,
  streak30,
  streak100,
  tierActive,
  tierContributor,
  tierExpert,
  tierLegend,
}

/// Static definition for a badge (never stored — catalog lives in code).
class AchievementDef {
  final AchievementKey key;
  final String emoji;
  final String titleKey;
  final String descKey;
  final int points;

  const AchievementDef({
    required this.key,
    required this.emoji,
    required this.titleKey,
    required this.descKey,
    required this.points,
  });
}

/// Static catalog — single source of truth for badge metadata.
const Map<AchievementKey, AchievementDef> kAchievementCatalog = {
  AchievementKey.firstMealLogged: AchievementDef(
    key: AchievementKey.firstMealLogged,
    emoji: '🍽️',
    titleKey: 'achievements.first_meal.title',
    descKey: 'achievements.first_meal.desc',
    points: 10,
  ),
  AchievementKey.firstPhotoLog: AchievementDef(
    key: AchievementKey.firstPhotoLog,
    emoji: '📸',
    titleKey: 'achievements.first_photo.title',
    descKey: 'achievements.first_photo.desc',
    points: 15,
  ),
  AchievementKey.firstPost: AchievementDef(
    key: AchievementKey.firstPost,
    emoji: '✍️',
    titleKey: 'achievements.first_post.title',
    descKey: 'achievements.first_post.desc',
    points: 10,
  ),
  AchievementKey.firstCook: AchievementDef(
    key: AchievementKey.firstCook,
    emoji: '🍳',
    titleKey: 'achievements.first_cook.title',
    descKey: 'achievements.first_cook.desc',
    points: 20,
  ),
  AchievementKey.streak7: AchievementDef(
    key: AchievementKey.streak7,
    emoji: '🔥',
    titleKey: 'achievements.streak_7.title',
    descKey: 'achievements.streak_7.desc',
    points: 30,
  ),
  AchievementKey.streak30: AchievementDef(
    key: AchievementKey.streak30,
    emoji: '💫',
    titleKey: 'achievements.streak_30.title',
    descKey: 'achievements.streak_30.desc',
    points: 75,
  ),
  AchievementKey.streak100: AchievementDef(
    key: AchievementKey.streak100,
    emoji: '🏅',
    titleKey: 'achievements.streak_100.title',
    descKey: 'achievements.streak_100.desc',
    points: 200,
  ),
  AchievementKey.tierActive: AchievementDef(
    key: AchievementKey.tierActive,
    emoji: '💪',
    titleKey: 'achievements.tier_active.title',
    descKey: 'achievements.tier_active.desc',
    points: 20,
  ),
  AchievementKey.tierContributor: AchievementDef(
    key: AchievementKey.tierContributor,
    emoji: '🌟',
    titleKey: 'achievements.tier_contributor.title',
    descKey: 'achievements.tier_contributor.desc',
    points: 50,
  ),
  AchievementKey.tierExpert: AchievementDef(
    key: AchievementKey.tierExpert,
    emoji: '🏆',
    titleKey: 'achievements.tier_expert.title',
    descKey: 'achievements.tier_expert.desc',
    points: 100,
  ),
  AchievementKey.tierLegend: AchievementDef(
    key: AchievementKey.tierLegend,
    emoji: '👑',
    titleKey: 'achievements.tier_legend.title',
    descKey: 'achievements.tier_legend.desc',
    points: 250,
  ),
};

/// A badge the user has earned (stored in Firestore).
class AchievementRecord {
  final AchievementKey key;
  final DateTime earnedAt;

  const AchievementRecord({required this.key, required this.earnedAt});

  AchievementDef get def => kAchievementCatalog[key]!;

  factory AchievementRecord.fromFirestore(
      String keyName, Map<String, dynamic> data) {
    final key = AchievementKey.values.firstWhere(
      (k) => k.name == keyName,
      orElse: () => AchievementKey.firstMealLogged,
    );
    return AchievementRecord(
      key: key,
      earnedAt: (data['earned_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'earned_at': Timestamp.fromDate(earnedAt),
      };
}
