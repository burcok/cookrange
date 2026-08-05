import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/dish_model.dart';
import '../../core/models/meal_plan_template_model.dart';
import '../../core/services/crashlytics_service.dart';
import '../../core/services/dish_service.dart';
import '../../core/services/meal_plan_template_service.dart';
import '../../core/services/sharing_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'template_creator_screen.dart';

/// Faz 3 §3.3 — the saved template library: search, tags, duplicate, export.
/// The "+" action is the entry point into [MealPlanTemplateCreatorScreen]'s
/// 3-path picker; tapping a card opens the same screen in edit mode.
///
/// Deliberately only ever lists the current author's OWN templates
/// (`streamMyTemplates`) — browsing a gym's shared pool or the public
/// marketplace is [TemplateSourcePickerSheet]'s job (reached from inside the
/// creator's "fork existing" path), not this screen's; conflating the two
/// would turn "my library" into an undifferentiated everyone's-templates
/// list.
///
/// **No folder concept** — none exists anywhere else in this app (checked
/// before building this screen), so none is invented here; tags are the
/// only organizational axis, matching the model's existing `tags` field
/// (a plain string list). **No version-history browser** — `version` is a
/// counter (see `MealPlanTemplateService.saveEdits`' doc comment), not a
/// stored history of past `days` snapshots; the badge here shows the current
/// number only.
class MealPlanTemplateLibraryScreen extends StatefulWidget {
  final String authorType;
  final String? gymId;

  /// Faz 3 §3.5 — when set, the library opens in PICKER mode: tapping a
  /// template calls this instead of opening the editor, and the per-card
  /// duplicate/export/delete menu is hidden (those are library-management
  /// actions, not relevant to "pick a template to send"). Null (default)
  /// preserves every existing §3.3 behavior unchanged.
  final ValueChanged<MealPlanTemplate>? onPick;

  const MealPlanTemplateLibraryScreen({
    super.key,
    required this.authorType,
    this.gymId,
    this.onPick,
  });

  @override
  State<MealPlanTemplateLibraryScreen> createState() =>
      _MealPlanTemplateLibraryScreenState();
}

class _MealPlanTemplateLibraryScreenState
    extends State<MealPlanTemplateLibraryScreen> {
  String _search = '';
  final Set<String> _activeTags = {};
  Map<String, DishModel> _dishCatalog = const {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadCatalogForExport();
  }

  // Only needed for the "export" action's nutrition summary — fetched once,
  // lazily, not blocking the rest of the screen from rendering.
  Future<void> _loadCatalogForExport() async {
    final dishes = await DishService().getAllDishes();
    if (!mounted) return;
    setState(() => _dishCatalog = {for (final d in dishes) d.id: d});
  }

  Future<void> _createNew() async {
    await Navigator.of(context).push(AppTransitions.slideUp(
      MealPlanTemplateCreatorScreen(
        authorType: widget.authorType,
        gymId: widget.gymId,
      ),
    ));
    // No manual refresh needed — streamMyTemplates is a live Firestore
    // listener, the new/edited doc appears on its own.
  }

  Future<void> _openForEdit(MealPlanTemplate tpl) async {
    await Navigator.of(context).push(
        AppTransitions.slideUp(MealPlanTemplateCreatorScreen(existing: tpl)));
  }

  Future<void> _duplicate(MealPlanTemplate tpl) async {
    final l10n = AppLocalizations.of(context);
    try {
      await MealPlanTemplateService().forkTemplate(
        tpl,
        authorUid: _uid,
        authorType: widget.authorType,
        gymId: widget.gymId,
        nameOverride:
            '${tpl.name} ${l10n.translate('template_builder.library.copy_suffix')}'
                .trim(),
      );
      if (!mounted) return;
      AppSnackBar.success(
          context, l10n.translate('template_builder.library.duplicated'));
    } catch (e, stack) {
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'TemplateLibrary._duplicate id=${tpl.id}'));
      if (!mounted) return;
      AppSnackBar.error(
          context, l10n.translate('template_builder.library.action_error'));
    }
  }

  Future<void> _export(MealPlanTemplate tpl) async {
    await SharingService()
        .shareMealPlanTemplate(context, tpl, dishCatalog: _dishCatalog);
  }

  Future<void> _delete(MealPlanTemplate tpl) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('template_builder.library.delete_title')),
        content:
            Text(l10n.translate('template_builder.library.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('common.delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MealPlanTemplateService().deleteTemplate(tpl.id);
    } catch (e, stack) {
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'TemplateLibrary._delete id=${tpl.id}'));
      if (!mounted) return;
      AppSnackBar.error(
          context, l10n.translate('template_builder.library.action_error'));
    }
  }

  List<MealPlanTemplate> _filter(List<MealPlanTemplate> all) {
    final q = _search.trim().toLowerCase();
    return all.where((t) {
      if (_activeTags.isNotEmpty && !_activeTags.every(t.tags.contains)) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(widget.onPick != null
            ? l10n.translate('template_builder.library.picker_title')
            : l10n.translate('template_builder.library.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createNew,
            tooltip: l10n.translate('template_builder.library.new_tooltip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, 0),
            child: AppTextField(
              hintText: l10n.translate('template_builder.library.search_hint'),
              prefixIcon:
                  Icon(Icons.search_rounded, color: palette.textSecondary),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Expanded(
            child: StreamBuilder<List<MealPlanTemplate>>(
              stream: MealPlanTemplateService().streamMyTemplates(_uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const AppSkeletonList(itemCount: 5, itemHeight: 104);
                }
                final all = snapshot.data!;
                if (all.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.menu_book_rounded,
                    title:
                        l10n.translate('template_builder.library.empty_title'),
                    message: l10n
                        .translate('template_builder.library.empty_message'),
                    actionLabel:
                        l10n.translate('template_builder.library.empty_cta'),
                    onAction: _createNew,
                  );
                }

                final allTags = <String>{for (final t in all) ...t.tags};
                final filtered = _filter(all);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (allTags.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                        child: AppFilterBar(
                          children: allTags
                              .map((tag) => AppFilterPill(
                                    label: tag,
                                    active: _activeTags.contains(tag),
                                    onTap: () => setState(() {
                                      if (_activeTags.contains(tag)) {
                                        _activeTags.remove(tag);
                                      } else {
                                        _activeTags.add(tag);
                                      }
                                    }),
                                  ))
                              .toList(),
                        ),
                      ),
                    Expanded(
                      child: filtered.isEmpty
                          ? AppEmptyState(
                              icon: Icons.search_off_rounded,
                              title: l10n.translate(
                                  'template_builder.library.no_results'),
                              compact: true,
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 0,
                                  AppSpacing.lg.w, AppSpacing.xl.h),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: AppSpacing.sm.h),
                              itemBuilder: (context, i) {
                                final tpl = filtered[i];
                                return _TemplateCard(
                                  template: tpl,
                                  onTap: widget.onPick != null
                                      ? () => widget.onPick!(tpl)
                                      : () => _openForEdit(tpl),
                                  onDuplicate: () => _duplicate(tpl),
                                  onExport: () => _export(tpl),
                                  onDelete: () => _delete(tpl),
                                  showManagementMenu: widget.onPick == null,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final MealPlanTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  /// Faz 3 §3.5 — false in picker mode (`MealPlanTemplateLibraryScreen
  /// .onPick` set): duplicate/export/delete are library-management actions,
  /// not relevant when the whole point of this list is "pick one to send".
  final bool showManagementMenu;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onDuplicate,
    required this.onExport,
    required this.onDelete,
    this.showManagementMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name.isEmpty
                      ? l10n.translate('template_builder.library.untitled')
                      : template.name,
                  style: t.titleM,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Text(
                  l10n.translate('template_builder.library.version_badge',
                      variables: {'n': '${template.version}'}),
                  style: t.labelS
                      .copyWith(color: primary, fontWeight: FontWeight.w700),
                ),
              ),
              if (showManagementMenu)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: palette.textSecondary),
                  onSelected: (v) {
                    switch (v) {
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'export':
                        onExport();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(
                          l10n.translate('template_builder.library.duplicate')),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Text(
                          l10n.translate('template_builder.library.export')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.translate('common.delete'),
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                )
              else
                Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
            ],
          ),
          if (template.tags.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Wrap(
              spacing: 4.w,
              runSpacing: 4.h,
              children: template.tags
                  .map((tag) => Text('#$tag',
                      style: t.labelS.copyWith(color: palette.textTertiary)))
                  .toList(),
            ),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded,
                  size: 13.r, color: palette.textSecondary),
              SizedBox(width: 4.w),
              Text(
                l10n.translate('template_builder.library.day_count',
                    variables: {'n': '${template.days.length}'}),
                style: t.labelS.copyWith(color: palette.textSecondary),
              ),
              SizedBox(width: AppSpacing.md.w),
              if (template.targetCalories > 0) ...[
                Icon(Icons.local_fire_department_rounded,
                    size: 13.r, color: palette.calories),
                SizedBox(width: 4.w),
                Text('${template.targetCalories.round()} kcal',
                    style: t.labelS.copyWith(color: palette.textSecondary)),
                SizedBox(width: AppSpacing.md.w),
              ],
              Icon(Icons.send_rounded,
                  size: 13.r, color: palette.textSecondary),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  template.usageCount > 0
                      ? l10n.translate('template_builder.library.sent_count',
                          variables: {'n': '${template.usageCount}'})
                      : l10n.translate('template_builder.library.not_sent'),
                  style: t.labelS.copyWith(color: palette.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            l10n.translate('template_builder.library.updated_at', variables: {
              'date': DateFormat('dd.MM.yyyy').format(template.updatedAt)
            }),
            style: t.labelS.copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}
