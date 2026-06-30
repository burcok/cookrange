import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/notification_model.dart';
import '../theme/app_palette.dart';

/// Renders user-facing notification text, icon and color from the structured
/// [NotificationModel] data — dynamically, in the current app language.
///
/// Legacy documents (created before the structured redesign) still carry a
/// pre-rendered title/body; those fall through to [NotificationModel.legacyTitle]
/// / [NotificationModel.legacyBody] so nothing breaks during the transition.
class NotificationPresenter {
  const NotificationPresenter._();

  static String _actor(BuildContext context, NotificationModel n) {
    final name = n.actorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return AppLocalizations.of(context).translate('notifications.feed.someone');
  }

  /// The bold headline line.
  static String titleFor(BuildContext context, NotificationModel n) {
    if (n.isLegacy) {
      return n.legacyTitle ?? n.legacyBody ?? '';
    }
    final l10n = AppLocalizations.of(context);
    final actor = _actor(context, n);
    final emoji = n.metadata?['emoji']?.toString() ?? '';
    final days = n.metadata?['streakDays']?.toString() ??
        n.metadata?['rewardDays']?.toString() ??
        '';
    switch (n.type) {
      case NotificationType.likePost:
      case NotificationType.like:
        return l10n.translate('notifications.feed.like_post',
            variables: {'actor': actor});
      case NotificationType.likeComment:
        return l10n.translate('notifications.feed.like_comment',
            variables: {'actor': actor});
      case NotificationType.reaction:
        final key = (n.metadata?['commentId'] != null)
            ? 'notifications.feed.reaction_comment'
            : 'notifications.feed.reaction_post';
        return l10n.translate(key, variables: {'actor': actor, 'emoji': emoji});
      case NotificationType.comment:
        return l10n.translate('notifications.feed.comment_post',
            variables: {'actor': actor});
      case NotificationType.friendRequest:
        return l10n.translate('notifications.feed.friend_request',
            variables: {'actor': actor});
      case NotificationType.friendAccepted:
      case NotificationType.follow:
        return l10n.translate('notifications.feed.friend_accepted',
            variables: {'actor': actor});
      case NotificationType.referral:
        return l10n.translate('notifications.feed.referral_title');
      case NotificationType.streakMilestone:
        return l10n.translate('notifications.feed.streak_title',
            variables: {'days': days});
      case NotificationType.mealPlan:
        return l10n.translate('notifications.feed.meal_plan_title');
      case NotificationType.system:
        return l10n.translate('notifications.feed.system_title');
      case NotificationType.coachApplicationApproved:
        return l10n.translate('notifications.feed.coach_application_approved');
      case NotificationType.coachApplicationRejected:
        return l10n.translate('notifications.feed.coach_application_rejected');
      case NotificationType.gymApplicationApproved:
        return l10n.translate('notifications.feed.gym_application_approved');
      case NotificationType.gymApplicationRejected:
        return l10n.translate('notifications.feed.gym_application_rejected');
      case NotificationType.streakFreezeUsed:
        return l10n.translate('notifications.feed.streak_freeze_used_title',
            variables: {'days': days});
      case NotificationType.achievementEarned:
        final name = n.metadata?['achievementName']?.toString() ?? '';
        return l10n.translate('notifications.feed.achievement_earned_title',
            variables: {'name': name});
      case NotificationType.mealReminder:
        return l10n.translate('notifications.feed.meal_reminder_title');
      case NotificationType.streakAtRisk:
        return l10n.translate('notifications.feed.streak_at_risk_title');
      case NotificationType.weeklyPlanReady:
        return l10n.translate('notifications.feed.weekly_plan_ready_title');
    }
  }

  /// Optional secondary line. Null when the headline says it all.
  static String? bodyFor(BuildContext context, NotificationModel n) {
    if (n.isLegacy) {
      // Avoid duplicating the headline when only one legacy field exists.
      if (n.legacyTitle != null && n.legacyBody != null) return n.legacyBody;
      return null;
    }
    final l10n = AppLocalizations.of(context);
    final days = n.metadata?['streakDays']?.toString() ??
        n.metadata?['rewardDays']?.toString() ??
        '';
    switch (n.type) {
      case NotificationType.referral:
        return l10n.translate('notifications.feed.referral_body',
            variables: {'days': days});
      case NotificationType.streakMilestone:
        return l10n.translate('notifications.feed.streak_body',
            variables: {'days': days});
      case NotificationType.mealPlan:
        return l10n.translate('notifications.feed.meal_plan_body');
      case NotificationType.system:
        return l10n.translate('notifications.feed.system_body');
      case NotificationType.streakFreezeUsed:
        return l10n.translate('notifications.feed.streak_freeze_used_body',
            variables: {'days': days});
      case NotificationType.achievementEarned:
        final desc = n.metadata?['achievementDesc']?.toString() ?? '';
        return desc.isNotEmpty ? desc : null;
      case NotificationType.mealReminder:
        return l10n.translate('notifications.feed.meal_reminder_body');
      case NotificationType.streakAtRisk:
        return l10n.translate('notifications.feed.streak_at_risk_body');
      case NotificationType.weeklyPlanReady:
        return l10n.translate('notifications.feed.weekly_plan_ready_body');
      default:
        return null;
    }
  }

  /// Short colored category label shown above the headline.
  static String categoryFor(BuildContext context, NotificationType type) {
    final l10n = AppLocalizations.of(context);
    switch (type) {
      case NotificationType.likePost:
      case NotificationType.like:
      case NotificationType.likeComment:
      case NotificationType.reaction:
      case NotificationType.comment:
        return l10n.translate('notifications.feed.cat_activity');
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
      case NotificationType.follow:
        return l10n.translate('notifications.feed.cat_friends');
      case NotificationType.referral:
        return l10n.translate('notifications.feed.cat_reward');
      case NotificationType.streakMilestone:
        return l10n.translate('notifications.feed.cat_streak');
      case NotificationType.mealPlan:
        return l10n.translate('notifications.feed.cat_meal');
      case NotificationType.system:
        return l10n.translate('notifications.feed.cat_system');
      case NotificationType.coachApplicationApproved:
      case NotificationType.coachApplicationRejected:
      case NotificationType.gymApplicationApproved:
      case NotificationType.gymApplicationRejected:
        return l10n.translate('notifications.feed.cat_system');
      case NotificationType.streakFreezeUsed:
        return l10n.translate('notifications.feed.cat_streak');
      case NotificationType.achievementEarned:
        return l10n.translate('notifications.feed.cat_reward');
      case NotificationType.mealReminder:
      case NotificationType.streakAtRisk:
      case NotificationType.weeklyPlanReady:
        return l10n.translate('notifications.feed.cat_reminders');
    }
  }

  static IconData iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.likePost:
      case NotificationType.like:
      case NotificationType.likeComment:
        return Icons.favorite;
      case NotificationType.reaction:
        return Icons.emoji_emotions;
      case NotificationType.comment:
        return Icons.chat_bubble;
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.friendAccepted:
      case NotificationType.follow:
        return Icons.how_to_reg;
      case NotificationType.referral:
        return Icons.card_giftcard;
      case NotificationType.streakMilestone:
        return Icons.local_fire_department;
      case NotificationType.mealPlan:
        return Icons.restaurant;
      case NotificationType.system:
        return Icons.system_update;
      case NotificationType.coachApplicationApproved:
      case NotificationType.gymApplicationApproved:
        return Icons.check_circle_rounded;
      case NotificationType.coachApplicationRejected:
      case NotificationType.gymApplicationRejected:
        return Icons.cancel_rounded;
      case NotificationType.streakFreezeUsed:
        return Icons.ac_unit_rounded;
      case NotificationType.achievementEarned:
        return Icons.emoji_events_rounded;
      case NotificationType.mealReminder:
        return Icons.restaurant_rounded;
      case NotificationType.streakAtRisk:
        return Icons.local_fire_department_rounded;
      case NotificationType.weeklyPlanReady:
        return Icons.calendar_today_rounded;
    }
  }

  static Color colorFor(
      NotificationType type, AppPalette palette, Color primary) {
    switch (type) {
      case NotificationType.likePost:
      case NotificationType.like:
      case NotificationType.likeComment:
        return palette.error;
      case NotificationType.reaction:
        return palette.calories;
      case NotificationType.comment:
        return palette.info;
      case NotificationType.friendRequest:
        return palette.fat;
      case NotificationType.friendAccepted:
      case NotificationType.follow:
        return palette.success;
      case NotificationType.referral:
        return primary;
      case NotificationType.streakMilestone:
        return palette.warning;
      case NotificationType.mealPlan:
        return palette.success;
      case NotificationType.system:
        return palette.warning;
      case NotificationType.coachApplicationApproved:
      case NotificationType.gymApplicationApproved:
        return palette.success;
      case NotificationType.coachApplicationRejected:
      case NotificationType.gymApplicationRejected:
        return palette.error;
      case NotificationType.streakFreezeUsed:
        return palette.info;
      case NotificationType.achievementEarned:
        return palette.calories;
      case NotificationType.mealReminder:
        return palette.success;
      case NotificationType.streakAtRisk:
        return palette.warning;
      case NotificationType.weeklyPlanReady:
        return primary;
    }
  }
}
