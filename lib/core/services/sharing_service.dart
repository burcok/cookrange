import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';

/// Handles native social sharing for recipes, progress, and community content.
///
/// Uses the OS share sheet via share_plus. Degrades gracefully on unsupported platforms.
class SharingService {
  SharingService._internal();
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;

  static const _appTag = '#Cookrange';
  static const _baseUrl = 'https://cookrange.app';

  /// Share a recipe with name, macros, calories, and a deep link.
  Future<void> shareRecipe(BuildContext context, {
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    String? recipeId,
    Rect? sharePositionOrigin,
  }) async {
    final link = recipeId != null ? '\n$_baseUrl/recipe/$recipeId' : '';
    final l10n = AppLocalizations.of(context);
    
    final text = l10n.translate('sharing.recipe_title', variables: {
      'name': name,
      'calories': calories.toStringAsFixed(0),
      'protein': protein.toStringAsFixed(0),
      'carbs': carbs.toStringAsFixed(0),
      'fat': fat.toStringAsFixed(0),
      'appTag': _appTag,
      'link': link,
    });
    
    final subject = l10n.translate('sharing.recipe_subject', variables: {'name': name});

    await Share.share(text, subject: subject, sharePositionOrigin: sharePositionOrigin);
  }

  /// Share a quick progress snapshot (consumed vs target calories).
  Future<void> shareProgress(BuildContext context, {
    required double consumed,
    required double target,
    int? streakDays,
    Rect? sharePositionOrigin,
  }) async {
    final pct = target > 0 ? (consumed / target * 100).toStringAsFixed(0) : '0';
    final l10n = AppLocalizations.of(context);
    
    final streakLine = streakDays != null && streakDays > 0
        ? l10n.translate('sharing.streak_line', variables: {'days': streakDays.toString()})
        : '';

    final text = l10n.translate('sharing.progress_text', variables: {
      'consumed': consumed.toStringAsFixed(0),
      'target': target.toStringAsFixed(0),
      'pct': pct,
      'streak': streakLine,
      'appTag': _appTag,
    });
    
    final subject = l10n.translate('sharing.progress_subject');

    await Share.share(text, subject: subject, sharePositionOrigin: sharePositionOrigin);
  }

  /// Share a community post caption with an optional deep link.
  Future<void> sharePost(BuildContext context, {
    required String caption,
    String? authorName,
    String? postId,
    Rect? sharePositionOrigin,
  }) async {
    final link = postId != null ? '\n$_baseUrl/post/$postId' : '';
    final l10n = AppLocalizations.of(context);
    
    final authorLine = authorName != null 
        ? l10n.translate('sharing.post_author_line', variables: {'author': authorName}) 
        : l10n.translate('sharing.post_on_line');

    final text = l10n.translate('sharing.post_text', variables: {
      'caption': caption,
      'authorLine': authorLine,
      'appTag': _appTag,
      'link': link,
    });
    
    final subject = l10n.translate('sharing.post_subject');

    await Share.share(text, subject: subject, sharePositionOrigin: sharePositionOrigin);
  }

  /// Share a shopping list as plain text.
  ///
  /// If [title] is provided, it is included at the top of the share sheet.
  Future<void> shareShoppingList(BuildContext context, List<String> items,
      {String? title, Rect? sharePositionOrigin}) async {
    final list = items.map((i) => '• $i').join('\n');
    final l10n = AppLocalizations.of(context);

    final prefix = title != null
        ? l10n.translate('sharing.shopping_list_prefix', variables: {'title': title})
        : l10n.translate('sharing.shopping_list_default_prefix', variables: {'date': DateFormat('dd.MM.yyyy').format(DateTime.now())});

    final text = '$prefix$list\n\n$_appTag';
    final subject = title ?? l10n.translate('sharing.shopping_list_subject', variables: {'date': DateFormat('dd.MM.yyyy').format(DateTime.now())});

    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share a challenge invite link so others can join.
  Future<void> shareChallenge(BuildContext context, {
    required String name,
    required String challengeId,
    String? goal,
    Rect? sharePositionOrigin,
  }) async {
    final link = '$_baseUrl/challenge/$challengeId';
    final l10n = AppLocalizations.of(context);
    
    final goalLine = goal != null ? l10n.translate('sharing.challenge_goal', variables: {'goal': goal}) : '';
    
    final text = l10n.translate('sharing.challenge_text', variables: {
      'name': name,
      'goalLine': goalLine,
      'link': link,
      'appTag': _appTag,
    });
    
    final subject = l10n.translate('sharing.challenge_subject', variables: {'name': name});
    
    await Share.share(text, subject: subject, sharePositionOrigin: sharePositionOrigin);
  }

  /// Share a referral invite link.
  Future<void> shareReferral(BuildContext context, {
    required String code,
    String baseUrl = 'https://cookrangeapp.com/invite',
    Rect? sharePositionOrigin,
  }) async {
    final link = '$baseUrl/$code';
    final l10n = AppLocalizations.of(context);
    
    final text = l10n.translate('sharing.referral_text', variables: {
      'code': code,
      'rewardDays': _rewardDaysLabel,
      'link': link,
      'appTag': _appTag,
    });
    
    final subject = l10n.translate('sharing.referral_subject');
    
    await Share.share(text, subject: subject, sharePositionOrigin: sharePositionOrigin);
  }

  static const _rewardDaysLabel = '7 days';
}
