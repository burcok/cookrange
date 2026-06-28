import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_client_model.dart';
import '../../core/services/ai/ai_service.dart';
import '../../core/services/coach_service.dart';
import '../../core/widgets/ds/ds.dart';

class CoachClientDetailScreen extends StatefulWidget {
  final CoachClientModel client;
  const CoachClientDetailScreen({super.key, required this.client});

  @override
  State<CoachClientDetailScreen> createState() =>
      _CoachClientDetailScreenState();
}

class _CoachClientDetailScreenState extends State<CoachClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isGeneratingReport = false;
  Map<String, dynamic>? _aiReport;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: AppMotion.normal);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _endCoaching() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('coach.client_end_coaching')),
        content: Text(l10n.translate('coach.client_end_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('coach.client_end_coaching'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await CoachService()
          .endCoaching(widget.client.coachUid, widget.client.clientUid);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('CoachClientDetailScreen._endCoaching error: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not end coaching. Try again.');
    }
  }

  Future<void> _generateAiReport() async {
    if (!AIService().isConfigured) {
      AppSnackBar.warning(
          context, 'AI reports require AI configuration.');
      return;
    }

    setState(() => _isGeneratingReport = true);
    final l10n = AppLocalizations.of(context);

    try {
      final clientName =
          widget.client.clientDisplayName ?? 'the client';
      final streak = widget.client.clientStreak ?? 0;
      final daysSince = widget.client.daysSinceLastLog;
      final linkedDays = DateTime.now()
          .difference(widget.client.linkedAt)
          .inDays;

      final prompt =
          'You are a fitness coach assistant. Generate a brief progress report for '
          'my client $clientName based on: streak=$streak days, '
          'last logged ${daysSince == 999 ? "never" : "$daysSince days ago"}, '
          'coaching started $linkedDays days ago. '
          'Include motivation level, recommended focus areas, and next steps.';

      const structure = '''
{
  "summary": "string",
  "motivationLevel": "low|medium|high",
  "focusAreas": ["string"],
  "nextSteps": ["string"]
}''';

      final result = await AIService().generateJson(
        prompt: prompt,
        jsonStructure: structure,
      );

      if (!mounted) return;
      setState(() => _aiReport = result);
    } catch (e) {
      debugPrint('CoachClientDetailScreen._generateAiReport error: $e');
      if (!mounted) return;
      AppSnackBar.error(
          context, l10n.translate('coach.client_ai_report_error'));
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;
    final client = widget.client;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text(
          client.clientDisplayName ?? l10n.translate('coach.client_detail_title'),
          style: AppText.of(context)
              .headlineS
              .copyWith(color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.link_off_rounded, color: palette.error),
            tooltip: l10n.translate('coach.client_end_coaching'),
            onPressed: _endCoaching,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClientHeader(context, client, palette, primary),
              const SizedBox(height: 24),
              _buildStatsSection(context, client, palette),
              const SizedBox(height: 24),

              // AI Report
              Text(
                l10n.translate('coach.client_ai_report'),
                style: AppText.of(context).titleM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_aiReport != null)
                _AiReportCard(report: _aiReport!, palette: palette)
              else if (_isGeneratingReport)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: primary)),
                      const SizedBox(width: 12),
                      Text(
                        l10n.translate('coach.client_ai_report_generating'),
                        style: AppText.of(context)
                            .bodyM
                            .copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                AppButton(
                  label: l10n.translate('coach.client_ai_report'),
                  onPressed: _generateAiReport,
                ),

              const SizedBox(height: 24),

              // Send Message
              AppButton(
                label: l10n.translate('coach.client_send_message'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: client.clientUid,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientHeader(BuildContext context, CoachClientModel client,
      AppPalette palette, Color primary) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: primary.withValues(alpha: 0.15),
          backgroundImage: client.clientPhotoURL != null
              ? NetworkImage(client.clientPhotoURL!)
              : null,
          child: client.clientPhotoURL == null
              ? Icon(Icons.person_rounded, color: primary, size: 32)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.clientDisplayName ?? 'Client',
                style: AppText.of(context).headlineS.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Active',
                      style: AppText.of(context).overline.copyWith(
                          color: palette.success,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Since ${_formatDate(client.linkedAt)}',
                    style: AppText.of(context)
                        .labelS
                        .copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context, CoachClientModel client,
      AppPalette palette) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFF97300),
            value: client.clientStreak?.toString() ?? '—',
            label: 'Day Streak',
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            iconColor: client.isAtRisk ? palette.warning : palette.info,
            value: client.daysSinceLastLog == 999
                ? 'Never'
                : '${client.daysSinceLastLog}d',
            label: 'Since Last Log',
            palette: palette,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final AppPalette palette;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(value,
              style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.bold)),
          Text(label,
              style: AppText.of(context)
                  .labelS
                  .copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

class _AiReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final AppPalette palette;
  const _AiReportCard({required this.report, required this.palette});

  Color _motivationColor() {
    final level = report['motivationLevel'] as String? ?? 'medium';
    return switch (level) {
      'high' => palette.success,
      'low' => palette.error,
      _ => palette.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final motColor = _motivationColor();
    final focusAreas = List<String>.from(report['focusAreas'] as List? ?? []);
    final nextSteps = List<String>.from(report['nextSteps'] as List? ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: primary),
              const SizedBox(width: 6),
              Text('AI Report',
                  style: AppText.of(context).labelS.copyWith(
                      color: primary, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: motColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Motivation: ${(report['motivationLevel'] as String? ?? 'medium').toUpperCase()}',
                  style: AppText.of(context).overline.copyWith(
                      color: motColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report['summary'] != null) ...[
            Text(report['summary'] as String,
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textSecondary)),
            const SizedBox(height: 12),
          ],
          if (focusAreas.isNotEmpty) ...[
            Text('Focus Areas',
                style: AppText.of(context).labelS.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...focusAreas.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 6, color: palette.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(f,
                              style: AppText.of(context)
                                  .bodyM
                                  .copyWith(color: palette.textSecondary))),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],
          if (nextSteps.isNotEmpty) ...[
            Text('Next Steps',
                style: AppText.of(context).labelS.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...nextSteps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key + 1}.',
                          style: AppText.of(context).labelS.copyWith(
                              color: primary, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.value,
                              style: AppText.of(context)
                                  .bodyM
                                  .copyWith(color: palette.textSecondary))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
