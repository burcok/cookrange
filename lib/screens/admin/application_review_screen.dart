import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Review screen for a single pending coach or gym application.
/// Admin can approve or reject (with notes) via a glassmorphism UI.
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

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _actioning = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool get _isCoach => widget.coachApp != null;

  String get _displayName =>
      _isCoach ? widget.coachApp!.displayName : widget.gymApp!.gymName;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: AppMotion.normal);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: AppMotion.standard);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
        AppSnackBar.error(
            context, AppLocalizations.of(context).translate('errors.general'));
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    final notes = await _showNotesSheet(l10n);
    if (notes == null || !mounted) return;

    setState(() => _actioning = true);
    try {
      if (_isCoach) {
        await AdminService().rejectCoachApplication(widget.coachApp!, notes);
      } else {
        await AdminService().rejectGymApplication(widget.gymApp!, notes);
      }
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.error(context, l10n.translate('admin.action_rejected'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, l10n.translate('errors.general'));
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<String?> _showNotesSheet(AppLocalizations l10n) {
    final noteCtrl = TextEditingController();
    return AppSheet.show<String?>(
      context: context,
      title: l10n.translate('admin.reject_notes_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: noteCtrl,
            hintText: l10n.translate('admin.reject_notes_hint'),
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (ctx) => Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.translate('common.cancel'),
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: l10n.translate('admin.reject_confirm'),
                    variant: AppButtonVariant.destructive,
                    onPressed: () =>
                        Navigator.of(ctx).pop(noteCtrl.text.trim()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
      body: Stack(
        children: [
          // Mesh-glow background
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.error.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header glass card
                  AppGlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(colors: [
                              primary.withValues(alpha: 0.25),
                              primary.withValues(alpha: 0.08),
                            ]),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            _isCoach
                                ? Icons.fitness_center_rounded
                                : Icons.business_rounded,
                            color: primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_displayName,
                                  style: t.titleL
                                      .copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                _isCoach
                                    ? widget.coachApp!.applicantUid
                                    : widget.gymApp!.applicantUid,
                                style: t.bodyM
                                    .copyWith(color: palette.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              _StatusBadge(
                                label: _isCoach
                                    ? l10n.translate('admin.type_coach')
                                    : l10n.translate('admin.type_gym'),
                                color: primary,
                                t: t,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isCoach) _buildCoachDetails(palette, l10n, t, primary),
                  if (!_isCoach) _buildGymDetails(palette, l10n, t, primary),
                ],
              ),
            ),
          ),
        ],
      ),
      // Floating action bar
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.85),
              border: Border(
                  top:
                      BorderSide(color: palette.border.withValues(alpha: 0.5))),
            ),
            child: Row(
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
          ),
        ),
      ),
    );
  }

  Widget _buildCoachDetails(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
    final app = widget.coachApp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassSectionCard(
          title: l10n.translate('coach.field_bio'),
          palette: palette,
          t: t,
          child: Text(app.bio, style: t.bodyM),
        ),
        const SizedBox(height: 12),

        // Specs row
        Row(
          children: [
            _StatChip(
              icon: Icons.workspace_premium_rounded,
              label: '${app.experienceYears} yrs',
              primary: primary,
              palette: palette,
              t: t,
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: Icons.currency_lira,
              label: '₺${app.hourlyRate}/hr',
              primary: primary,
              palette: palette,
              t: t,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _GlassSectionCard(
          title: l10n.translate('coach.field_specializations'),
          palette: palette,
          t: t,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: app.specializations
                .map((s) => _TagChip(label: s, primary: primary, t: t))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        if (app.evidenceUrls.isNotEmpty)
          _GlassSectionCard(
            title: l10n.translate('admin.evidence_docs'),
            palette: palette,
            t: t,
            child: Column(
              children: app.evidenceUrls
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: EdgeInsets.only(
                            bottom:
                                e.key < app.evidenceUrls.length - 1 ? 8 : 0),
                        child: _DocTile(
                          label: app.evidenceLabels.length > e.key
                              ? app.evidenceLabels[e.key]
                              : 'Document ${e.key + 1}',
                          url: e.value,
                          primary: primary,
                          palette: palette,
                          t: t,
                        ),
                      ))
                  .toList(),
            ),
          ),

        if (app.references.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GlassSectionCard(
            title: l10n.translate('admin.references'),
            palette: palette,
            t: t,
            child: Column(
              children: app.references.asMap().entries.map((entry) {
                final i = entry.key;
                final ref = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: i < app.references.length - 1 ? 10 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i > 0)
                        Divider(
                            color: palette.border.withValues(alpha: 0.4),
                            height: 20),
                      Text(ref['name'] ?? '',
                          style:
                              t.labelL.copyWith(fontWeight: FontWeight.w700)),
                      Text(ref['contact'] ?? '',
                          style:
                              t.bodyM.copyWith(color: palette.textSecondary)),
                      if ((ref['description'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(ref['description'] ?? '', style: t.bodyM),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGymDetails(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
    final app = widget.gymApp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassSectionCard(
          title: l10n.translate('gym.description'),
          palette: palette,
          t: t,
          child: Text(app.description, style: t.bodyM),
        ),
        const SizedBox(height: 12),
        _GlassSectionCard(
          title: l10n.translate('gym.address'),
          palette: palette,
          t: t,
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, color: primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${app.address}, ${app.city}', style: t.bodyM),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassSectionCard(
          title: l10n.translate('gym.contact'),
          palette: palette,
          t: t,
          child: Row(
            children: [
              Icon(Icons.phone_rounded, color: primary, size: 18),
              const SizedBox(width: 8),
              Text(app.contactPhone, style: t.bodyM),
            ],
          ),
        ),
        if (app.latitude != null && app.longitude != null) ...[
          const SizedBox(height: 12),
          _GlassSectionCard(
            title: l10n.translate('gym.location'),
            palette: palette,
            t: t,
            child: Text(
              '${app.city}  (${app.latitude!.toStringAsFixed(5)}, ${app.longitude!.toStringAsFixed(5)})',
              style: t.bodyM.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
        if (app.brandColor != null && app.brandColor!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GlassSectionCard(
            title: l10n.translate('gym.brand_color'),
            palette: palette,
            t: t,
            child:
                _BrandColorSwatch(hex: app.brandColor!, palette: palette, t: t),
          ),
        ],
        const SizedBox(height: 12),
        _GlassSectionCard(
          title: l10n.translate('admin.evidence_docs'),
          palette: palette,
          t: t,
          child: Column(
            children: [
              if (app.businessDocUrl != null)
                _DocTile(
                  label: l10n.translate('admin.business_doc'),
                  url: app.businessDocUrl!,
                  primary: primary,
                  palette: palette,
                  t: t,
                ),
              if (app.businessDocUrl != null && app.idDocUrl != null)
                const SizedBox(height: 8),
              if (app.idDocUrl != null)
                _DocTile(
                  label: l10n.translate('admin.id_doc'),
                  url: app.idDocUrl!,
                  primary: primary,
                  palette: palette,
                  t: t,
                ),
              if (app.businessDocUrl == null && app.idDocUrl == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: palette.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: palette.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.translate('admin.no_docs_warning'),
                          style: t.bodyM.copyWith(
                              color: palette.warning,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              if (app.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...app.photoUrls.asMap().entries.map((e) => Padding(
                      padding: EdgeInsets.only(
                          bottom: e.key < app.photoUrls.length - 1 ? 8 : 0),
                      child: _DocTile(
                        label:
                            '${l10n.translate('admin.gym_photo')} ${e.key + 1}',
                        url: e.value,
                        primary: primary,
                        palette: palette,
                        t: t,
                        isImage: true,
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── DS Widgets ──────────────────────────────────────────────────────────────

class _GlassSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final AppPalette palette;
  final AppText t;

  const _GlassSectionCard({
    required this.title,
    required this.child,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: t.labelS.copyWith(
              color: palette.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final AppText t;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: t.labelS.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color primary;
  final AppText t;

  const _TagChip({required this.label, required this.primary, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: t.labelS.copyWith(
          color: primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primary;
  final AppPalette palette;
  final AppText t;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.primary,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: primary),
          const SizedBox(width: 6),
          Text(label,
              style: t.labelM
                  .copyWith(color: primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _BrandColorSwatch extends StatelessWidget {
  final String hex;
  final AppPalette palette;
  final AppText t;

  const _BrandColorSwatch({
    required this.hex,
    required this.palette,
    required this.t,
  });

  Color? _parse() {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return value != null ? Color(value) : null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _parse();
    if (color == null) return Text(hex, style: t.bodyM);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          hex.toUpperCase(),
          style: t.bodyM.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  final String label;
  final String url;
  final bool isImage;
  final Color primary;
  final AppPalette palette;
  final AppText t;

  const _DocTile({
    required this.label,
    required this.url,
    this.isImage = false,
    required this.primary,
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
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                color: primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: t.bodyM.copyWith(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.open_in_new_rounded,
                color: palette.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
