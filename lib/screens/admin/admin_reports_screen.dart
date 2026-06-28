import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/report_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Moderation queue screen — pending and reviewed community content reports.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('admin.reports_title'),
          style: t.titleM
              .copyWith(color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: palette.textPrimary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: primary,
          labelStyle: t.labelM.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: t.labelM,
          tabs: [
            Tab(text: l10n.translate('admin.reports_pending_tab')),
            Tab(text: l10n.translate('admin.reports_reviewed_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ReportList(
            stream: AdminService().pendingReportsStream(),
            showActions: true,
          ),
          _ReportList(
            stream: AdminService().reviewedReportsStream(),
            showActions: false,
          ),
        ],
      ),
    );
  }
}

// ── Report List ───────────────────────────────────────────────────────────────

class _ReportList extends StatelessWidget {
  final Stream<List<ReportModel>> stream;
  final bool showActions;

  const _ReportList({required this.stream, required this.showActions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<ReportModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: AppSkeletonList(itemCount: 5),
          );
        }

        if (snap.hasError) {
          return AppErrorState(
            title: 'Error',
            message: snap.error.toString(),
          );
        }

        final reports = snap.data ?? [];

        if (reports.isEmpty) {
          final title = showActions
              ? l10n.translate('admin.reports_empty')
              : l10n.translate('admin.reports_reviewed_empty');
          final message =
              showActions ? l10n.translate('admin.reports_empty_msg') : '';

          return AppEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: title,
            message: message,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          itemCount: reports.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, i) => _ReportCard(
            report: reports[i],
            showActions: showActions,
          ),
        );
      },
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final bool showActions;

  const _ReportCard({required this.report, required this.showActions});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    final isPost = report.targetType == 'post';
    final typeLabel = isPost
        ? l10n.translate('admin.reports_type_post')
        : l10n.translate('admin.reports_type_comment');

    final badgeColor =
        report.status == 'pending' ? palette.error : palette.textSecondary;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(14.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    typeLabel,
                    style: t.labelS.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(report.timestamp),
                  style: t.labelS.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // ── Content ──
            _InfoRow(
              label: l10n.translate('admin.reports_author'),
              value: report.authorId ?? '—',
            ),
            SizedBox(height: 4.h),
            _InfoRow(
              label: l10n.translate('admin.reports_reported_by'),
              value: report.reporterId,
            ),
            SizedBox(height: 4.h),
            _InfoRow(
              label: l10n.translate('admin.reports_reason'),
              value: report.reason,
              valueItalic: true,
            ),
            SizedBox(height: 12.h),

            // ── Actions / Status ──
            if (showActions)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.translate('admin.reports_dismiss'),
                      variant: AppButtonVariant.ghost,
                      onPressed: () => _dismiss(context, report, l10n),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: AppButton(
                      label: l10n.translate('admin.reports_remove'),
                      variant: AppButtonVariant.destructive,
                      onPressed: () => _confirmRemove(context, report, l10n),
                    ),
                  ),
                ],
              )
            else
              _StatusChip(status: report.status),
          ],
        ),
      ),
    );
  }

  void _dismiss(
      BuildContext context, ReportModel report, AppLocalizations l10n) {
    AdminService().dismissReport(report);
  }

  void _confirmRemove(
      BuildContext context, ReportModel report, AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final isPost = report.targetType == 'post';
    final typeLabel = isPost
        ? l10n.translate('admin.reports_type_post')
        : l10n.translate('admin.reports_type_comment');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          l10n.translate('admin.reports_remove_confirm'),
          style:
              t.titleM.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n
              .translate('admin.reports_remove_msg')
              .replaceAll('{type}', typeLabel),
          style: t.bodyM.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.translate('admin.reports_remove_no'),
              style: t.labelM.copyWith(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AdminService().removeReportedContent(report);
            },
            child: Text(
              l10n.translate('admin.reports_remove_yes'),
              style: t.labelM.copyWith(
                  color: palette.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool valueItalic;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueItalic = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: t.labelS.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: t.labelS.copyWith(
              color: palette.textPrimary,
              fontStyle:
                  valueItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    final isDismissed = status == 'dismissed';
    final label = isDismissed
        ? l10n.translate('admin.reports_status_dismissed')
        : l10n.translate('admin.reports_status_removed');
    final color = isDismissed ? palette.textSecondary : palette.error;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
