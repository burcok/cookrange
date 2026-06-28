import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Review screen for a single pending coach or gym application.
/// Admin can approve, reject (with notes), or request more info.
class ApplicationReviewScreen extends StatefulWidget {
  final CoachApplicationModel? coachApp;
  final GymApplicationModel? gymApp;

  const ApplicationReviewScreen.forCoach(CoachApplicationModel app, {super.key})
      : coachApp = app,
        gymApp = null;

  const ApplicationReviewScreen.forGym(GymApplicationModel app, {super.key})
      : gymApp = app,
        coachApp = null;

  @override
  State<ApplicationReviewScreen> createState() =>
      _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen> {
  bool _actioning = false;
  final _notesCtrl = TextEditingController();

  bool get _isCoach => widget.coachApp != null;

  String get _displayName => _isCoach
      ? (widget.coachApp!.displayName)
      : (widget.gymApp!.gymName);

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _actioning = true);
    try {
      if (_isCoach) {
        await AdminService().approveCoachApplication(widget.coachApp!);
      } else {
        await AdminService().approveGymApplication(widget.gymApp!);
      }
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(context,
          AppLocalizations.of(context).translate('admin.action_approved'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context,
            AppLocalizations.of(context).translate('errors.general'));
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    final notes = await _showNotesDialog(l10n);
    if (notes == null || !mounted) return;

    setState(() => _actioning = true);
    try {
      if (_isCoach) {
        await AdminService()
            .rejectCoachApplication(widget.coachApp!, notes);
      } else {
        await AdminService()
            .rejectGymApplication(widget.gymApp!, notes);
      }
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.error(
          context, l10n.translate('admin.action_rejected'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, l10n.translate('errors.general'));
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<String?> _showNotesDialog(AppLocalizations l10n) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final noteCtrl = TextEditingController();
        return AlertDialog(
          title: Text(l10n.translate('admin.reject_notes_title')),
          content: TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.translate('admin.reject_notes_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.translate('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(noteCtrl.text.trim()),
              child: Text(l10n.translate('admin.reject_confirm')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('admin.review_title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCoach
                          ? Icons.fitness_center_rounded
                          : Icons.business_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName,
                            style: t.titleM.copyWith(
                                fontWeight: FontWeight.w800)),
                        Text(
                          _isCoach
                              ? widget.coachApp!.applicantUid
                              : widget.gymApp!.applicantUid,
                          style: t.bodyM.copyWith(
                              color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isCoach) _buildCoachDetails(palette, l10n, t),
            if (!_isCoach) _buildGymDetails(palette, l10n, t),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.translate('admin.action_reject'),
                    variant: AppButtonVariant.destructive,
                    onPressed: _actioning ? null : _reject,
                    loading: _actioning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: l10n.translate('admin.action_approve'),
                    onPressed: _actioning ? null : _approve,
                    loading: _actioning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachDetails(AppPalette palette, AppLocalizations l10n,
      AppText t) {
    final app = widget.coachApp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.translate('coach.field_bio'), t: t),
        _InfoBox(app.bio, palette: palette, t: t),
        const SizedBox(height: 16),
        _SectionTitle(l10n.translate('coach.field_specializations'), t: t),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: app.specializations
              .map((s) => Chip(
                    label: Text(s, style: t.labelS),
                    backgroundColor: palette.surfaceVariant,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatChip(
              icon: Icons.star_rounded,
              label: '${app.experienceYears} yrs',
              palette: palette,
              t: t,
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: Icons.currency_lira,
              label: '₺${app.hourlyRate}/hr',
              palette: palette,
              t: t,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(l10n.translate('admin.evidence_docs'), t: t),
        ...app.evidenceUrls.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DocTile(
                label: app.evidenceLabels.length > e.key
                    ? app.evidenceLabels[e.key]
                    : 'Document ${e.key + 1}',
                url: e.value,
                palette: palette,
                t: t,
              ),
            )),
        const SizedBox(height: 16),
        _SectionTitle(l10n.translate('admin.references'), t: t),
        ...app.references.map((ref) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref['name'] ?? '',
                        style:
                            t.labelL.copyWith(fontWeight: FontWeight.w700)),
                    Text(ref['contact'] ?? '',
                        style: t.bodyM.copyWith(
                            color: palette.textSecondary)),
                    if ((ref['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(ref['description'] ?? '',
                          style: t.bodyM),
                    ],
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildGymDetails(AppPalette palette, AppLocalizations l10n,
      AppText t) {
    final app = widget.gymApp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.translate('gym.description'), t: t),
        _InfoBox(app.description, palette: palette, t: t),
        const SizedBox(height: 16),
        _SectionTitle(l10n.translate('gym.address'), t: t),
        _InfoBox('${app.address}, ${app.city}', palette: palette, t: t),
        const SizedBox(height: 16),
        _SectionTitle(l10n.translate('gym.contact'), t: t),
        _InfoBox(app.contactPhone, palette: palette, t: t),
        const SizedBox(height: 16),
        _SectionTitle(l10n.translate('admin.evidence_docs'), t: t),
        if (app.businessDocUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DocTile(
              label: l10n.translate('admin.business_doc'),
              url: app.businessDocUrl!,
              palette: palette,
              t: t,
            ),
          ),
        ...app.photoUrls.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DocTile(
                label: '${l10n.translate('admin.gym_photo')} ${e.key + 1}',
                url: e.value,
                palette: palette,
                t: t,
                isImage: true,
              ),
            )),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final AppText t;

  const _SectionTitle(this.title, {required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: t.labelL.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final AppPalette palette;
  final AppText t;

  const _InfoBox(this.text, {required this.palette, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: t.bodyM),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;
  final AppText t;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: t.labelM),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String label;
  final String url;
  final bool isImage;
  final AppPalette palette;
  final AppText t;

  const _DocTile({
    required this.label,
    required this.url,
    this.isImage = false,
    required this.palette,
    required this.t,
  });

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: _open,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                color: primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: t.bodyM.copyWith(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.open_in_new_rounded,
                color: palette.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
