import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/app_config_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Admin-only editor for the remote app config (`app_config/global`).
///
/// Loads the current nested config on init, exposes each section as an
/// [AppCard] of controls, and writes a merge patch back via
/// [AdminService.updateAppConfig] — then refreshes [AppConfigService] so
/// changes take effect immediately for the running client.
class AdminAppConfigScreen extends StatefulWidget {
  const AdminAppConfigScreen({super.key});

  @override
  State<AdminAppConfigScreen> createState() => _AdminAppConfigScreenState();
}

class _AdminAppConfigScreenState extends State<AdminAppConfigScreen> {
  // ── AI ────────────────────────────────────────────────────────────────────
  final _aiTextModelCtrl = TextEditingController();
  final _aiVisionModelCtrl = TextEditingController();
  final _aiMaxTokensCtrl = TextEditingController();
  final _aiTemperatureCtrl = TextEditingController();
  final _aiTimeoutCtrl = TextEditingController();
  final _aiFreeLimitCtrl = TextEditingController();
  final _aiPremiumLimitCtrl = TextEditingController();
  bool _aiPhotoEnabled = true;
  bool _aiRecapEnabled = true;

  // ── Version ─────────────────────────────────────────────────────────────
  final _verMinAndroidCtrl = TextEditingController();
  final _verMinIosCtrl = TextEditingController();
  final _verLatestAndroidCtrl = TextEditingController();
  final _verLatestIosCtrl = TextEditingController();
  final _verAndroidUrlCtrl = TextEditingController();
  final _verIosUrlCtrl = TextEditingController();
  final _verMsgEnCtrl = TextEditingController();
  final _verMsgTrCtrl = TextEditingController();
  bool _verForceUpdate = false;

  // ── Maintenance ─────────────────────────────────────────────────────────
  final _maintMsgEnCtrl = TextEditingController();
  final _maintMsgTrCtrl = TextEditingController();
  bool _maintEnabled = false;

  // ── Announcement ────────────────────────────────────────────────────────
  final _annIdCtrl = TextEditingController();
  final _annTypeCtrl = TextEditingController();
  final _annCtaCtrl = TextEditingController();
  final _annMsgEnCtrl = TextEditingController();
  final _annMsgTrCtrl = TextEditingController();
  bool _annEnabled = false;
  bool _annDismissible = true;

  // ── Features ────────────────────────────────────────────────────────────
  static const _featureKeys = <String>[
    'community',
    'chat',
    'food_scan',
    'marketplace',
    'referral',
  ];
  final Map<String, bool> _features = {};

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _aiTextModelCtrl,
      _aiVisionModelCtrl,
      _aiMaxTokensCtrl,
      _aiTemperatureCtrl,
      _aiTimeoutCtrl,
      _aiFreeLimitCtrl,
      _aiPremiumLimitCtrl,
      _verMinAndroidCtrl,
      _verMinIosCtrl,
      _verLatestAndroidCtrl,
      _verLatestIosCtrl,
      _verAndroidUrlCtrl,
      _verIosUrlCtrl,
      _verMsgEnCtrl,
      _verMsgTrCtrl,
      _maintMsgEnCtrl,
      _maintMsgTrCtrl,
      _annIdCtrl,
      _annTypeCtrl,
      _annCtaCtrl,
      _annMsgEnCtrl,
      _annMsgTrCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    debugPrint('AdminAppConfigScreen: loading app config');
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cfg = await AdminService().getAppConfig();
      if (!mounted) return;
      _populate(cfg);
      setState(() => _loading = false);
    } catch (e, s) {
      debugPrint('AdminAppConfigScreen: load error — $e\n$s');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  Map<String, dynamic> _mapOf(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  String _str(dynamic v) => v == null ? '' : '$v';

  void _populate(Map<String, dynamic> cfg) {
    final ai = _mapOf(cfg['ai']);
    _aiTextModelCtrl.text = _str(ai['text_model']);
    _aiVisionModelCtrl.text = _str(ai['vision_model']);
    _aiMaxTokensCtrl.text = _str(ai['max_tokens']);
    _aiTemperatureCtrl.text = _str(ai['temperature']);
    _aiTimeoutCtrl.text = _str(ai['timeout_s']);
    _aiFreeLimitCtrl.text = _str(ai['free_daily_limit']);
    _aiPremiumLimitCtrl.text = _str(ai['premium_daily_limit']);
    _aiPhotoEnabled = ai['photo_analysis_enabled'] as bool? ?? true;
    _aiRecapEnabled = ai['weekly_recap_enabled'] as bool? ?? true;

    final version = _mapOf(cfg['version']);
    _verMinAndroidCtrl.text = _str(version['min_supported_android']);
    _verMinIosCtrl.text = _str(version['min_supported_ios']);
    _verLatestAndroidCtrl.text = _str(version['latest_android']);
    _verLatestIosCtrl.text = _str(version['latest_ios']);
    _verAndroidUrlCtrl.text = _str(version['android_store_url']);
    _verIosUrlCtrl.text = _str(version['ios_store_url']);
    _verForceUpdate = version['force_update'] as bool? ?? false;
    final verMsg = _mapOf(version['update_message']);
    _verMsgEnCtrl.text = _str(verMsg['en']);
    _verMsgTrCtrl.text = _str(verMsg['tr']);

    final maint = _mapOf(cfg['maintenance']);
    _maintEnabled = maint['enabled'] as bool? ?? false;
    final maintMsg = _mapOf(maint['message']);
    _maintMsgEnCtrl.text = _str(maintMsg['en']);
    _maintMsgTrCtrl.text = _str(maintMsg['tr']);

    final ann = _mapOf(cfg['announcement']);
    _annEnabled = ann['enabled'] as bool? ?? false;
    _annDismissible = ann['dismissible'] as bool? ?? true;
    _annIdCtrl.text = _str(ann['id']);
    _annTypeCtrl.text = _str(ann['type']);
    _annCtaCtrl.text = _str(ann['cta_url']);
    final annMsg = _mapOf(ann['message']);
    _annMsgEnCtrl.text = _str(annMsg['en']);
    _annMsgTrCtrl.text = _str(annMsg['tr']);

    final features = _mapOf(cfg['features']);
    for (final key in _featureKeys) {
      _features[key] = features[key] as bool? ?? true;
    }
  }

  /// Only puts a string value into [target] when non-empty, so a blank field
  /// never overwrites an existing server value on merge.
  void _putStr(Map<String, dynamic> target, String key, String raw) {
    final v = raw.trim();
    if (v.isNotEmpty) target[key] = v;
  }

  void _putInt(Map<String, dynamic> target, String key, String raw) {
    final v = int.tryParse(raw.trim());
    if (v != null) target[key] = v;
  }

  void _putDouble(Map<String, dynamic> target, String key, String raw) {
    final v = double.tryParse(raw.trim());
    if (v != null) target[key] = v;
  }

  Map<String, dynamic> _buildPatch() {
    final ai = <String, dynamic>{};
    _putStr(ai, 'text_model', _aiTextModelCtrl.text);
    _putStr(ai, 'vision_model', _aiVisionModelCtrl.text);
    _putInt(ai, 'max_tokens', _aiMaxTokensCtrl.text);
    _putDouble(ai, 'temperature', _aiTemperatureCtrl.text);
    _putInt(ai, 'timeout_s', _aiTimeoutCtrl.text);
    _putInt(ai, 'free_daily_limit', _aiFreeLimitCtrl.text);
    _putInt(ai, 'premium_daily_limit', _aiPremiumLimitCtrl.text);
    ai['photo_analysis_enabled'] = _aiPhotoEnabled;
    ai['weekly_recap_enabled'] = _aiRecapEnabled;

    final updateMessage = <String, dynamic>{};
    _putStr(updateMessage, 'en', _verMsgEnCtrl.text);
    _putStr(updateMessage, 'tr', _verMsgTrCtrl.text);
    final version = <String, dynamic>{};
    _putStr(version, 'min_supported_android', _verMinAndroidCtrl.text);
    _putStr(version, 'min_supported_ios', _verMinIosCtrl.text);
    _putStr(version, 'latest_android', _verLatestAndroidCtrl.text);
    _putStr(version, 'latest_ios', _verLatestIosCtrl.text);
    _putStr(version, 'android_store_url', _verAndroidUrlCtrl.text);
    _putStr(version, 'ios_store_url', _verIosUrlCtrl.text);
    version['force_update'] = _verForceUpdate;
    if (updateMessage.isNotEmpty) version['update_message'] = updateMessage;

    final maintMessage = <String, dynamic>{};
    _putStr(maintMessage, 'en', _maintMsgEnCtrl.text);
    _putStr(maintMessage, 'tr', _maintMsgTrCtrl.text);
    final maintenance = <String, dynamic>{'enabled': _maintEnabled};
    if (maintMessage.isNotEmpty) maintenance['message'] = maintMessage;

    final annMessage = <String, dynamic>{};
    _putStr(annMessage, 'en', _annMsgEnCtrl.text);
    _putStr(annMessage, 'tr', _annMsgTrCtrl.text);
    final announcement = <String, dynamic>{
      'enabled': _annEnabled,
      'dismissible': _annDismissible,
    };
    _putStr(announcement, 'id', _annIdCtrl.text);
    _putStr(announcement, 'type', _annTypeCtrl.text);
    _putStr(announcement, 'cta_url', _annCtaCtrl.text);
    if (annMessage.isNotEmpty) announcement['message'] = annMessage;

    final features = <String, dynamic>{
      for (final e in _features.entries) e.key: e.value,
    };

    return {
      'ai': ai,
      'version': version,
      'maintenance': maintenance,
      'announcement': announcement,
      'features': features,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      final patch = _buildPatch();
      debugPrint('AdminAppConfigScreen: saving patch keys=${patch.keys}');
      await AdminService().updateAppConfig(patch);
      await AppConfigService().refresh();
      if (!mounted) return;
      AppSnackBar.success(context, l10n.translate('admin.appconfig.saved'));
    } catch (e, s) {
      debugPrint('AdminAppConfigScreen: save error — $e\n$s');
      if (!mounted) return;
      AppSnackBar.error(context, l10n.translate('common.something_wrong'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('admin.appconfig.title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: AppSkeletonList(itemCount: 5),
            )
          : _loadError != null
              ? AppErrorState(
                  title: l10n.translate('common.something_wrong'),
                  message: _loadError.toString(),
                  onRetry: _load,
                )
              : _buildForm(palette, l10n, t),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: AppButton(
                label: l10n.translate('admin.appconfig.save'),
                onPressed: _save,
                loading: _saving,
                icon: Icons.save_rounded,
              ),
            ),
    );
  }

  Widget _buildForm(AppPalette palette, AppLocalizations l10n, AppText t) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      children: [
        // ── AI ────────────────────────────────────────────────────
        _Section(
          title: l10n.translate('admin.appconfig.section_ai'),
          icon: Icons.auto_awesome_rounded,
          palette: palette,
          t: t,
          children: [
            _field(_aiTextModelCtrl, l10n.translate('admin.appconfig.ai_text_model')),
            _field(_aiVisionModelCtrl, l10n.translate('admin.appconfig.ai_vision_model')),
            _numField(_aiMaxTokensCtrl, l10n.translate('admin.appconfig.ai_max_tokens')),
            _numField(_aiTemperatureCtrl, l10n.translate('admin.appconfig.ai_temperature'), decimal: true),
            _numField(_aiTimeoutCtrl, l10n.translate('admin.appconfig.ai_timeout')),
            _numField(_aiFreeLimitCtrl, l10n.translate('admin.appconfig.ai_free_limit')),
            _numField(_aiPremiumLimitCtrl, l10n.translate('admin.appconfig.ai_premium_limit')),
            _switch(l10n.translate('admin.appconfig.ai_photo'), _aiPhotoEnabled,
                (v) => setState(() => _aiPhotoEnabled = v), palette, t),
            _switch(l10n.translate('admin.appconfig.ai_recap'), _aiRecapEnabled,
                (v) => setState(() => _aiRecapEnabled = v), palette, t),
          ],
        ),
        // ── Version ───────────────────────────────────────────────
        _Section(
          title: l10n.translate('admin.appconfig.section_version'),
          icon: Icons.system_update_rounded,
          palette: palette,
          t: t,
          children: [
            _field(_verMinAndroidCtrl, l10n.translate('admin.appconfig.ver_min_android')),
            _field(_verMinIosCtrl, l10n.translate('admin.appconfig.ver_min_ios')),
            _field(_verLatestAndroidCtrl, l10n.translate('admin.appconfig.ver_latest_android')),
            _field(_verLatestIosCtrl, l10n.translate('admin.appconfig.ver_latest_ios')),
            _switch(l10n.translate('admin.appconfig.ver_force'), _verForceUpdate,
                (v) => setState(() => _verForceUpdate = v), palette, t),
            _field(_verAndroidUrlCtrl, l10n.translate('admin.appconfig.ver_android_url')),
            _field(_verIosUrlCtrl, l10n.translate('admin.appconfig.ver_ios_url')),
            _field(_verMsgEnCtrl, l10n.translate('admin.appconfig.message_en')),
            _field(_verMsgTrCtrl, l10n.translate('admin.appconfig.message_tr')),
          ],
        ),
        // ── Maintenance ───────────────────────────────────────────
        _Section(
          title: l10n.translate('admin.appconfig.section_maintenance'),
          icon: Icons.build_circle_rounded,
          palette: palette,
          t: t,
          children: [
            _switch(l10n.translate('admin.appconfig.enabled'), _maintEnabled,
                (v) => setState(() => _maintEnabled = v), palette, t),
            _field(_maintMsgEnCtrl, l10n.translate('admin.appconfig.message_en')),
            _field(_maintMsgTrCtrl, l10n.translate('admin.appconfig.message_tr')),
          ],
        ),
        // ── Announcement ──────────────────────────────────────────
        _Section(
          title: l10n.translate('admin.appconfig.section_announcement'),
          icon: Icons.campaign_rounded,
          palette: palette,
          t: t,
          children: [
            _switch(l10n.translate('admin.appconfig.enabled'), _annEnabled,
                (v) => setState(() => _annEnabled = v), palette, t),
            _field(_annIdCtrl, l10n.translate('admin.appconfig.ann_id')),
            _field(_annTypeCtrl, l10n.translate('admin.appconfig.ann_type')),
            _field(_annCtaCtrl, l10n.translate('admin.appconfig.ann_cta')),
            _switch(l10n.translate('admin.appconfig.ann_dismissible'), _annDismissible,
                (v) => setState(() => _annDismissible = v), palette, t),
            _field(_annMsgEnCtrl, l10n.translate('admin.appconfig.message_en')),
            _field(_annMsgTrCtrl, l10n.translate('admin.appconfig.message_tr')),
          ],
        ),
        // ── Features ──────────────────────────────────────────────
        _Section(
          title: l10n.translate('admin.appconfig.section_features'),
          icon: Icons.flag_rounded,
          palette: palette,
          t: t,
          children: [
            for (final key in _featureKeys)
              _switch(key, _features[key] ?? true,
                  (v) => setState(() => _features[key] = v), palette, t),
          ],
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label) => Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: AppTextField(controller: ctrl, labelText: label),
      );

  Widget _numField(TextEditingController ctrl, String label,
          {bool decimal = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: AppTextField(
          controller: ctrl,
          labelText: label,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
          ],
        ),
      );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged,
          AppPalette palette, AppText t) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: t.bodyM.copyWith(color: palette.textPrimary),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
      );
}

// ── Section wrapper ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final AppPalette palette;
  final AppText t;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primary, size: 20.r),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: t.titleM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ...children,
          ],
        ),
      ),
    );
  }
}
