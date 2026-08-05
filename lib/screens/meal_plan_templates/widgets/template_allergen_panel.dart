import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/dish_model.dart';
import '../../../core/models/meal_plan_template_model.dart';
import '../../../core/models/user_nutrition_profile.dart';
import '../../../core/utils/allergen_safety.dart';
import '../../../core/widgets/ds/ds.dart';

class _Conflict {
  final int dayIndex;
  final String mealType;
  final String dishName;
  const _Conflict(
      {required this.dayIndex, required this.mealType, required this.dishName});
}

/// Faz 3 §3.3 — "alerjen çakışması anında kırmızı uyarı". Reuses
/// `AllergenSafety` exactly as `WeeklyMealPlanService` already does (never
/// re-implements the match logic), checked against [ownProfile] — the
/// signed-in author's own declared allergies/avoid-ingredients.
///
/// **Scope note, decided in this task**: the plan text this screen was built
/// from also asked for checking against a SPECIFIC MEMBER's allergen profile
/// when "previewing for" them. That was investigated and deliberately NOT
/// built:
///
/// - `UserNutritionProfile`'s source fields (`allergies`, `dietary_
///   restrictions`, `disliked_foods`, `personal_info`) live in
///   `users/{uid}/private/nutrition` (Faz 0 §0.2's PII migration — verified
///   against `onboarding_provider.dart`'s `_toPrivateMap()` and
///   `firestore_service.dart`'s `getPrivateNutritionData`, NOT just the
///   plan's own summary of that migration, which only named 5 fields but
///   the actual shipped migration covers more).
/// - `private/{docId}` is owner-only in `firestore.rules` (`allow read,
///   write: if isOwner(uid)`) with no admin or coach/gym override — unlike
///   `private/account`, which does grant admin read. So `FirestoreService().
///   getUserData(memberUid).profile` — the normal "view another user"
///   pattern (`profile_screen.dart`) — returns an allergy-empty profile for
///   anyone who isn't the caller: the fields simply aren't on the doc that
///   read can reach.
/// - Faz 4 (§4.1/§4.2, not built) is where a real per-member view is
///   supposed to live: tiered consent (`progress_sharing/{scopeId}`) plus a
///   server callable that only releases data the member has actually opted
///   into sharing. Building a "pick a member, see their allergies" control
///   here — before that consent gate exists — would either silently show
///   "no conflicts" for every member regardless of their real allergies
///   (false reassurance on a safety check) or require standing up Faz 4's
///   consent infrastructure, which is out of scope for §3.3.
///
/// So: own-profile-only, clearly labeled as such, is the honest scope for
/// this task. Whoever builds Faz 4 (or a dedicated allergen-sharing consent
/// purpose) should extend this panel rather than re-solve the lookup.
class TemplateAllergenPanel extends StatelessWidget {
  final List<TemplateDay> days;
  final Map<String, DishModel> dishCatalog;
  final UserNutritionProfile ownProfile;
  final String ownLabel;

  const TemplateAllergenPanel({
    super.key,
    required this.days,
    required this.dishCatalog,
    required this.ownProfile,
    required this.ownLabel,
  });

  List<_Conflict> _computeConflicts() {
    final unsafe = AllergenSafety.buildUnsafeTerms(
      allergyIds: ownProfile.allergyIds,
      avoidIngredients: ownProfile.avoidIngredients,
    );
    if (unsafe.isEmpty) return const [];

    final out = <_Conflict>[];
    final sortedDays = [...days]
      ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
    for (final day in sortedDays) {
      for (final meal in day.meals) {
        final dish = meal.dishId != null ? dishCatalog[meal.dishId] : null;
        if (dish != null && AllergenSafety.dishIsUnsafe(dish, unsafe)) {
          out.add(_Conflict(
              dayIndex: day.dayIndex,
              mealType: meal.mealType,
              dishName: dish.name));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    final conflicts = _computeConflicts();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon_rounded,
                  size: 16.r,
                  color: conflicts.isEmpty ? palette.success : palette.error),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(l10n.translate('template_builder.allergen.title'),
                    style: t.titleM),
              ),
              Text(
                l10n.translate('template_builder.allergen.checking_own',
                    variables: {'name': ownLabel}),
                style: t.labelS.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (conflicts.isEmpty)
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14.r, color: palette.success),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    l10n.translate('template_builder.allergen.no_conflicts'),
                    style: t.bodyM.copyWith(color: palette.textSecondary),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: EdgeInsets.all(AppSpacing.sm.r),
              decoration: BoxDecoration(
                color: palette.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
                border: Border.all(color: palette.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('template_builder.allergen.conflicts_found',
                        variables: {'n': '${conflicts.length}'}),
                    style: t.labelM.copyWith(
                        color: palette.error, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6.h),
                  ...conflicts.map((c) => Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          l10n.translate(
                              'template_builder.allergen.conflict_line',
                              variables: {
                                'day': '${c.dayIndex + 1}',
                                'meal': l10n
                                    .translate('food_scan.meal.${c.mealType}'),
                                'dish': c.dishName,
                              }),
                          style: t.labelS.copyWith(color: palette.error),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
