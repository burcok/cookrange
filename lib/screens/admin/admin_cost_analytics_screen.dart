import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/cost_analytics_model.dart';
import '../../core/services/cost_analytics_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Admin-only **cost & profit estimation** dashboard. All figures are estimates
/// derived from live usage counts × unit prices (see [CostAnalyticsService]).
class AdminCostAnalyticsScreen extends StatefulWidget {
  const AdminCostAnalyticsScreen({super.key});

  @override
  State<AdminCostAnalyticsScreen> createState() =>
      _AdminCostAnalyticsScreenState();
}

class _AdminCostAnalyticsScreenState extends State<AdminCostAnalyticsScreen> {
  final _service = CostAnalyticsService();
  late Future<CostAnalytics> _future;
  late Future<AiUsageStats> _aiFuture;
  final _uidCtrl = TextEditingController();
  Future<List<AiUsageLogEntry>>? _userLogsFuture;
  static const _assumptions = UsageAssumptions();
  static const _projectionPoints = [1000, 10000, 100000, 1000000];

  @override
  void initState() {
    super.initState();
    _future = _service.compute(assumptions: _assumptions);
    _aiFuture = _service.fetchAiUsageStats();
  }

  @override
  void dispose() {
    _uidCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.compute(assumptions: _assumptions);
      _aiFuture = _service.fetchAiUsageStats();
    });
  }

  void _lookupUser() {
    final uid = _uidCtrl.text.trim();
    if (uid.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _userLogsFuture = _service.fetchUserAiLogs(uid);
    });
  }

  String _usd4(double v) =>
      v >= 1 ? _usd(v) : '\$${v.toStringAsFixed(4)}';

  String _usd(double v) {
    final neg = v < 0;
    final a = v.abs();
    String s;
    if (a >= 1000000) {
      s = '\$${(a / 1000000).toStringAsFixed(2)}M';
    } else if (a >= 1000) {
      s = '\$${(a / 1000).toStringAsFixed(1)}k';
    } else {
      s = '\$${a.toStringAsFixed(2)}';
    }
    return neg ? '-$s' : s;
  }

  String _intK(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text(l10n.translate('admin.cost_title'), style: t.titleL),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<CostAnalytics>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return AppErrorState(
              title: l10n.translate('admin.cost_error_title'),
              message: l10n.translate('admin.cost_error'),
              onRetry: _reload,
            );
          }
          return _buildContent(context, snap.data!, l10n, palette, t);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, CostAnalytics a,
      AppLocalizations l10n, AppPalette palette, AppText t) {
    final profitColor =
        a.monthlyProfitUsd >= 0 ? palette.success : palette.error;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
      children: [
        // Disclaimer
        Container(
          padding: EdgeInsets.all(12.r),
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            color: palette.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: palette.warning.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18.r, color: palette.warning),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(l10n.translate('admin.cost_estimate_disclaimer'),
                    style: t.labelS.copyWith(color: palette.textSecondary)),
              ),
            ],
          ),
        ),

        // ── Hero: monthly profit ──
        AppGlassCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('admin.cost_monthly_profit'),
                    style: t.labelM.copyWith(color: palette.textSecondary)),
                SizedBox(height: 6.h),
                Text(_usd(a.monthlyProfitUsd),
                    style: t.displayM.copyWith(color: profitColor)),
                SizedBox(height: 4.h),
                Text(
                  '${l10n.translate('admin.cost_margin')}: '
                  '${a.marginPercent.toStringAsFixed(0)}%',
                  style: t.labelM.copyWith(color: palette.textTertiary),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(t, palette,
                          l10n.translate('admin.cost_revenue'),
                          _usd(a.monthlyRevenueUsd), palette.success),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _miniStat(t, palette,
                          l10n.translate('admin.cost_cost'),
                          _usd(a.monthlyCostUsd), palette.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),

        // ── Cost breakdown ──
        _sectionCard(
          t,
          palette,
          l10n.translate('admin.cost_breakdown'),
          Column(
            children: a.costLines.map((line) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('admin.cost_line_${line.key}'),
                            style: t.bodyM,
                          ),
                          if (line.detail.isNotEmpty)
                            Text(line.detail,
                                style: t.labelS
                                    .copyWith(color: palette.textTertiary)),
                        ],
                      ),
                    ),
                    Text(_usd(line.monthlyUsd),
                        style: t.titleM.copyWith(color: palette.textPrimary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 12.h),

        // ── REAL AI usage (measured from proxy logs) ──
        _buildRealAiSection(l10n, palette, t),
        SizedBox(height: 12.h),

        // ── Revenue & per-user ──
        _sectionCard(
          t,
          palette,
          l10n.translate('admin.cost_revenue_per_user'),
          Column(
            children: [
              _metricRow(t, palette, l10n.translate('admin.cost_total_users'),
                  _intK(a.counts.totalUsers)),
              _metricRow(t, palette, l10n.translate('admin.cost_premium_users'),
                  _intK(a.counts.premiumUsers)),
              _metricRow(t, palette, l10n.translate('admin.cost_arpu'),
                  _usd(a.arpuUsd)),
              _metricRow(t, palette, l10n.translate('admin.cost_per_user'),
                  _usd(a.costPerUserUsd)),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // ── Projection / what-if ──
        _sectionCard(
          t,
          palette,
          l10n.translate('admin.cost_projection'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('admin.cost_projection_hint'),
                  style: t.labelS.copyWith(color: palette.textTertiary)),
              SizedBox(height: 8.h),
              ..._projectionPoints.map((users) {
                final sim = _service.simulateAt(users, a, _assumptions);
                final c = sim.monthlyProfitUsd >= 0
                    ? palette.success
                    : palette.error;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64.w,
                        child: Text(_intK(users),
                            style: t.titleM
                                .copyWith(color: palette.textPrimary)),
                      ),
                      Expanded(
                        child: Text(
                          '${l10n.translate('admin.cost_revenue')} ${_usd(sim.monthlyRevenueUsd)}  ·  '
                          '${l10n.translate('admin.cost_cost')} ${_usd(sim.monthlyCostUsd)}',
                          style: t.labelS
                              .copyWith(color: palette.textSecondary),
                        ),
                      ),
                      Text(_usd(sim.monthlyProfitUsd),
                          style: t.titleM.copyWith(color: c)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // ── Assumptions footnote ──
        _sectionCard(
          t,
          palette,
          l10n.translate('admin.cost_assumptions'),
          Column(
            children: [
              _metricRow(t, palette,
                  l10n.translate('admin.cost_assumption_reads'),
                  '${a.assumptions.readsPerActiveUserPerDay}'),
              _metricRow(t, palette,
                  l10n.translate('admin.cost_assumption_writes'),
                  '${a.assumptions.writesPerActiveUserPerDay}'),
              _metricRow(t, palette,
                  l10n.translate('admin.cost_assumption_image'),
                  '${a.assumptions.avgImageKb.toStringAsFixed(0)} KB'),
              _metricRow(t, palette,
                  l10n.translate('admin.cost_assumption_dau'),
                  '${(a.assumptions.dailyActiveFraction * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(
      AppText t, AppPalette palette, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelS.copyWith(color: palette.textSecondary)),
          SizedBox(height: 4.h),
          Text(value, style: t.titleM.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _sectionCard(
      AppText t, AppPalette palette, String title, Widget child) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleM.copyWith(color: palette.textPrimary)),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }

  Widget _metricRow(
      AppText t, AppPalette palette, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.bodyM.copyWith(color: palette.textSecondary)),
          Text(value, style: t.titleM.copyWith(color: palette.textPrimary)),
        ],
      ),
    );
  }

  String _dt(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  // ── REAL AI usage (measured) + per-user lookup ──
  Widget _buildRealAiSection(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    return FutureBuilder<AiUsageStats>(
      future: _aiFuture,
      builder: (context, snap) {
        final stats = snap.data ?? const AiUsageStats();
        final children = <Widget>[
          Text(l10n.translate('admin.ai_usage_note'),
              style: t.labelS.copyWith(color: palette.textTertiary)),
          SizedBox(height: 10.h),
        ];

        if (snap.connectionState == ConnectionState.waiting) {
          children.add(const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          ));
        } else if (stats.isEmpty) {
          children.add(Text(l10n.translate('admin.ai_usage_empty'),
              style: t.bodyM.copyWith(color: palette.textSecondary)));
        } else {
          children.addAll([
            Row(children: [
              Expanded(
                child: _miniStat(
                    t,
                    palette,
                    l10n.translate('admin.ai_usage_total_cost'),
                    _usd4(stats.totalCostUsd),
                    palette.error),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _miniStat(
                    t,
                    palette,
                    l10n.translate('admin.ai_usage_requests'),
                    _intK(stats.totalRequests),
                    palette.textPrimary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _miniStat(
                    t,
                    palette,
                    l10n.translate('admin.ai_usage_tokens'),
                    _intK(stats.totalTokens),
                    palette.textPrimary),
              ),
            ]),
            SizedBox(height: 12.h),
            Text(l10n.translate('admin.ai_usage_by_type'),
                style: t.labelM.copyWith(color: palette.textSecondary)),
            ...stats.byType.entries.map((e) => _metricRow(
                t,
                palette,
                '${e.key} (${_intK(e.value.requests)})',
                _usd4(e.value.costUsd))),
            SizedBox(height: 8.h),
            Text(l10n.translate('admin.ai_usage_by_model'),
                style: t.labelM.copyWith(color: palette.textSecondary)),
            ...stats.byModel.entries.map((e) => _metricRow(
                t,
                palette,
                '${e.key} (${_intK(e.value.requests)})',
                _usd4(e.value.costUsd))),
          ]);
        }

        // Per-user lookup.
        children.addAll([
          SizedBox(height: 14.h),
          Divider(color: palette.border, height: 1),
          SizedBox(height: 12.h),
          Text(l10n.translate('admin.ai_usage_per_user'),
              style: t.labelM.copyWith(color: palette.textSecondary)),
          SizedBox(height: 8.h),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _uidCtrl,
                style: t.bodyM,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.translate('admin.ai_usage_uid_hint'),
                  hintStyle:
                      t.bodyM.copyWith(color: palette.textTertiary),
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _lookupUser(),
              ),
            ),
            SizedBox(width: 8.w),
            AppButton(
              label: l10n.translate('admin.ai_usage_show'),
              onPressed: _lookupUser,
              size: AppButtonSize.small,
              expand: false,
            ),
          ]),
          if (_userLogsFuture != null) _buildUserLogs(l10n, palette, t),
        ]);

        return _sectionCard(
            t, palette, l10n.translate('admin.ai_usage_title'),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
      },
    );
  }

  Widget _buildUserLogs(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    return FutureBuilder<List<AiUsageLogEntry>>(
      future: _userLogsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final logs = snap.data ?? const [];
        if (logs.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Text(l10n.translate('admin.ai_usage_no_logs'),
                style: t.bodyM.copyWith(color: palette.textSecondary)),
          );
        }
        return Column(
          children: logs.map((e) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 5.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.type} · ${e.model}',
                            style: t.bodyM.copyWith(
                                color: palette.textPrimary)),
                        Text(
                          '${_dt(e.createdAt)} · ${_intK(e.totalTokens)} tok',
                          style: t.labelS
                              .copyWith(color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Text(_usd4(e.costUsd),
                      style: t.titleM.copyWith(color: palette.textPrimary)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
