import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/meal_plan_template_model.dart';
import '../../../core/services/meal_plan_template_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Faz 3 §3.3 path 3 ("var olandan türet") — pick a template to fork FROM.
///
/// Three tabs, each backed by one of `MealPlanTemplateService`'s three query
/// shapes: "Mine" (`streamMyTemplates`), "My gym's shared pool"
/// (`streamGymSharedTemplates` — only shown when the current author is
/// gym-affiliated; this is the "another author's shared template, if
/// permitted by share_scope" source), and "Public" (`streamPublicTemplates`
/// — the marketplace/discovery source, open regardless of affiliation).
/// Returns the picked [MealPlanTemplate] (the SOURCE, unmodified) — the
/// caller is responsible for actually forking it
/// (`MealPlanTemplateService.forkTemplate`).
class TemplateSourcePickerSheet {
  static Future<MealPlanTemplate?> show(
    BuildContext context, {
    required String currentUid,
    required String authorType,
    String? gymId,
  }) {
    return AppSheet.show<MealPlanTemplate>(
      context: context,
      title: AppLocalizations.of(context)
          .translate('template_builder.source_picker.title'),
      child: _SourcePickerBody(
        currentUid: currentUid,
        authorType: authorType,
        gymId: gymId,
      ),
    );
  }
}

class _SourcePickerBody extends StatefulWidget {
  final String currentUid;
  final String authorType;
  final String? gymId;

  const _SourcePickerBody({
    required this.currentUid,
    required this.authorType,
    required this.gymId,
  });

  @override
  State<_SourcePickerBody> createState() => _SourcePickerBodyState();
}

class _SourcePickerBodyState extends State<_SourcePickerBody> {
  int _tab = 0;
  bool get _hasGymTab => widget.gymId != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.translate('template_builder.source_picker.tab_mine'),
      if (_hasGymTab) l10n.translate('template_builder.source_picker.tab_gym'),
      l10n.translate('template_builder.source_picker.tab_public'),
    ];

    return SizedBox(
      height: 0.7.sh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSegmentedControl(
            labels: labels,
            selectedIndex: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: AppSpacing.md.h),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isGymTab = _hasGymTab && _tab == 1;
    final isPublicTab = _hasGymTab ? _tab == 2 : _tab == 1;

    final Stream<List<MealPlanTemplate>> stream;
    if (_tab == 0) {
      stream = MealPlanTemplateService().streamMyTemplates(widget.currentUid);
    } else if (isGymTab) {
      stream =
          MealPlanTemplateService().streamGymSharedTemplates(widget.gymId!);
    } else {
      stream = MealPlanTemplateService().streamPublicTemplates();
    }

    return StreamBuilder<List<MealPlanTemplate>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppSkeletonList(itemCount: 4, itemHeight: 72);
        }
        final templates = snapshot.data!;
        if (templates.isEmpty) {
          return AppEmptyState(
            icon: Icons.dynamic_feed_rounded,
            title: l10n.translate(isPublicTab
                ? 'template_builder.source_picker.empty_public'
                : isGymTab
                    ? 'template_builder.source_picker.empty_gym'
                    : 'template_builder.source_picker.empty_mine'),
            compact: true,
          );
        }
        return ListView.separated(
          itemCount: templates.length,
          separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
          itemBuilder: (context, i) {
            final tpl = templates[i];
            return _SourceCard(
              template: tpl,
              onTap: () => Navigator.of(context).pop(tpl),
            );
          },
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  final MealPlanTemplate template;
  final VoidCallback onTap;

  const _SourceCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    template.name.isEmpty
                        ? l10n.translate('template_builder.library.untitled')
                        : template.name,
                    style: t.titleM,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Text(
                  l10n.translate('template_builder.library.day_count',
                      variables: {'n': '${template.days.length}'}),
                  style: t.labelS.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: palette.textTertiary, size: 20.r),
        ],
      ),
    );
  }
}
