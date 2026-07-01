import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/services/notification_preferences_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/referral_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';
import '../admin/admin_panel_screen.dart';
import '../onboarding/v2/intro_screen.dart';
import '../ai/widgets/ai_credits_sheet.dart';
import '../coach/coach_dashboard_screen.dart';
import '../gym/gym_dashboard_screen.dart';
import '../legal/legal_screen.dart';
import 'affiliate_earnings_screen.dart';
import 'consent_center_screen.dart';
import 'dietary_preferences_screen.dart';
import 'privacy_request_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Notification group toggle state ──
  static const _notifGroups = [
    'likes',
    'comments',
    'friends',
    'system',
    'referral',
    'reminders'
  ];
  Map<String, bool> _notifEnabled = {};
  bool _notifLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _notifLoading = false);
      return;
    }
    final svc = NotificationPreferencesService();
    final results = <String, bool>{};
    for (final group in _notifGroups) {
      final muted = await svc.isGroupMuted(uid, group);
      results[group] = !muted; // enabled = !muted
    }
    if (mounted) {
      setState(() {
        _notifEnabled = results;
        _notifLoading = false;
      });
    }
  }

  Future<void> _openNotificationSettings() async {
    await openAppSettings();
  }

  Future<void> _openHelp() async {
    final uri =
        Uri.parse('mailto:support@cookrangeapp.com?subject=Cookrange%20Help');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _togglePrivacy(BuildContext context, bool val) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Optimistic update so the switch flips immediately
    final userProvider = context.read<UserProvider>();
    final previousUser = userProvider.user;
    if (previousUser != null) {
      userProvider.setUser(previousUser.copyWith(isPrivate: val));
    }

    try {
      await FirestoreService().updateUserData(uid, {'is_private': val});
      // Optimistic update already applied; no server re-read to avoid race
    } catch (e) {
      debugPrint('SettingsScreen._togglePrivacy error: $e');
      if (context.mounted && previousUser != null) {
        context.read<UserProvider>().setUser(previousUser);
      }
    }
  }

  Future<void> _showNotificationPreferences(BuildContext context) async {
    final svc = NotificationPreferencesService();
    final prefs = await svc.getPreferences();
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final mutable = Map<String, bool>.from(prefs);

    await AppSheet.show(
      context: context,
      title: l10n.translate('notification_prefs.title'),
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final primary = context.read<ThemeProvider>().primaryColor;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('notification_prefs.subtitle'),
                    style: AppText.of(ctx).bodyM),
                const SizedBox(height: 16),
                ...NotificationPreferencesService.preferencePairs.keys.map(
                  (key) => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.translate('notification_prefs.$key'),
                      style: AppText.of(ctx).titleM,
                    ),
                    value: !(mutable[key] ?? false),
                    activeTrackColor: primary,
                    onChanged: (enabled) async {
                      setSheetState(() => mutable[key] = !enabled);
                      await svc.setMuted(key, !enabled);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
    if (context.mounted) {
      AppSnackBar.success(context, l10n.translate('notification_prefs.saved'));
    }
  }

  /// Lets the user enable/disable hydration reminders and adjust the wake/sleep
  /// window, then persists `onboarding_data.water_reminder` and reschedules (or
  /// cancels) the precise daily local notifications via [PushNotificationService].
  Future<void> _showWaterReminderSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final userProvider = context.read<UserProvider>();
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    final water = (userProvider.user?.onboardingData?['water_reminder'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    var enabled = water['enabled'] == true;
    final targetMl = (water['target_ml'] as num?)?.toInt();
    var wake = water['wake'] as String? ?? '08:00';
    var sleep = water['sleep'] as String? ?? '23:00';
    final liters = ((targetMl ?? 2000) / 1000).toStringAsFixed(1);
    var saving = false;

    final saved = await AppSheet.show<bool>(
      context: context,
      title: l10n.translate('water_reminder.settings_title'),
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final palette = AppPalette.of(ctx);
          final t = AppText.of(ctx);
          final primary = context.read<ThemeProvider>().primaryColor;

          Future<void> pickTime(bool isWake) async {
            final current = isWake ? wake : sleep;
            final parts = current.split(':');
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(
                hour: int.tryParse(parts.first) ?? 8,
                minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
              ),
            );
            if (picked != null) {
              final v =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              setSheetState(() {
                if (isWake) {
                  wake = v;
                } else {
                  sleep = v;
                }
              });
            }
          }

          Future<void> save() async {
            setSheetState(() => saving = true);
            // Turning the reminder on requires notification permission.
            if (enabled) {
              final granted =
                  await PermissionService().requestNotifications(ctx);
              if (!granted) {
                setSheetState(() {
                  enabled = false;
                  saving = false;
                });
                return;
              }
            }
            final map = <String, dynamic>{
              'enabled': enabled,
              'target_ml': targetMl,
              'wake': wake,
              'sleep': sleep,
            };
            // Nested-map merge (updateUserData uses set(merge:true), so dot
            // notation would create a literal field — we write the sub-map).
            await FirestoreService().updateUserData(uid, {
              'onboarding_data': {'water_reminder': map},
            });
            final user = userProvider.user;
            if (user != null) {
              final merged = <String, dynamic>{
                ...?user.onboardingData,
                'water_reminder': map,
              };
              userProvider.setUser(user.copyWith(onboardingData: merged));
            }
            if (enabled) {
              await PushNotificationService().scheduleDailyWaterReminder(
                title: l10n.translate('water_reminder.notif_title'),
                body: l10n.translate('water_reminder.notif_body',
                    variables: {'liters': liters}),
                wakeTime: wake,
                sleepTime: sleep,
              );
            } else {
              await PushNotificationService().cancelWaterReminder();
            }
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('water_reminder.settings_subtitle',
                      variables: {'liters': liters}),
                  style: t.bodyM.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.translate('water_reminder.settings_enable'),
                    style: t.titleM,
                  ),
                  value: enabled,
                  activeTrackColor: primary,
                  onChanged: (v) => setSheetState(() => enabled = v),
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _WaterTimeField(
                          label: l10n.translate('onboarding.v2.water.wake'),
                          time: wake,
                          onTap: () => pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WaterTimeField(
                          label: l10n.translate('onboarding.v2.water.sleep'),
                          time: sleep,
                          onTap: () => pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: l10n.translate('common.save'),
                  loading: saving,
                  onPressed: saving ? null : save,
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    if (saved == true && context.mounted) {
      AppSnackBar.success(
          context, l10n.translate('water_reminder.settings_saved'));
    }
  }

  /// Lets the user toggle meal-time reminders (breakfast/lunch/dinner) and adjust
  /// the time for each. Persists under `onboarding_data.meal_reminder` and
  /// reschedules (or cancels) the precise daily local notifications.
  Future<void> _showMealReminderSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final userProvider = context.read<UserProvider>();
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    final meal = (userProvider.user?.onboardingData?['meal_reminder'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    var enabled = meal['enabled'] == true;
    final rawTimes = meal['times'] as List?;
    var breakfast = rawTimes != null && rawTimes.isNotEmpty
        ? rawTimes[0].toString()
        : '08:00';
    var lunch = rawTimes != null && rawTimes.length > 1
        ? rawTimes[1].toString()
        : '12:30';
    var dinner = rawTimes != null && rawTimes.length > 2
        ? rawTimes[2].toString()
        : '19:00';
    var saving = false;

    final saved = await AppSheet.show<bool>(
      context: context,
      title: l10n.translate('settings.reminders.meal_title'),
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final palette = AppPalette.of(ctx);
          final t = AppText.of(ctx);
          final primary = context.read<ThemeProvider>().primaryColor;

          Future<void> pickTime(
              String current, void Function(String) onPicked) async {
            final parts = current.split(':');
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(
                hour: int.tryParse(parts.first) ?? 8,
                minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
              ),
            );
            if (picked != null) {
              onPicked(
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
            }
          }

          Future<void> save() async {
            setSheetState(() => saving = true);
            if (enabled) {
              final granted =
                  await PermissionService().requestNotifications(ctx);
              if (!granted) {
                setSheetState(() {
                  enabled = false;
                  saving = false;
                });
                return;
              }
            }
            final times = [breakfast, lunch, dinner];
            final map = <String, dynamic>{
              'enabled': enabled,
              'times': times,
            };
            await FirestoreService().updateUserData(uid, {
              'onboarding_data': {'meal_reminder': map},
            });
            final user = userProvider.user;
            if (user != null) {
              final merged = <String, dynamic>{
                ...?user.onboardingData,
                'meal_reminder': map,
              };
              userProvider.setUser(user.copyWith(onboardingData: merged));
            }
            if (enabled) {
              await PushNotificationService().scheduleDailyMealReminders(
                times: times,
                title: l10n.translate('settings.reminders.meal_notif_title'),
                body: l10n.translate('settings.reminders.meal_notif_body'),
              );
            } else {
              await PushNotificationService().cancelMealReminders();
            }
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('settings.reminders.meal_subtitle'),
                  style: t.bodyM.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.translate('settings.reminders.meal_enable'),
                    style: t.titleM,
                  ),
                  value: enabled,
                  activeTrackColor: primary,
                  onChanged: (v) => setSheetState(() => enabled = v),
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _WaterTimeField(
                          label: l10n.translate('settings.reminders.breakfast'),
                          time: breakfast,
                          onTap: () => pickTime(breakfast,
                              (v) => setSheetState(() => breakfast = v)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WaterTimeField(
                          label: l10n.translate('settings.reminders.lunch'),
                          time: lunch,
                          onTap: () => pickTime(
                              lunch, (v) => setSheetState(() => lunch = v)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WaterTimeField(
                          label: l10n.translate('settings.reminders.dinner'),
                          time: dinner,
                          onTap: () => pickTime(
                              dinner, (v) => setSheetState(() => dinner = v)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: l10n.translate('common.save'),
                  loading: saving,
                  onPressed: saving ? null : save,
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    if (saved == true && context.mounted) {
      AppSnackBar.success(
          context, l10n.translate('settings.reminders.meal_saved'));
    }
  }

  Future<void> _showAboutSheet(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    final palette = AppPalette.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '—';
    final l10n = AppLocalizations.of(context);

    await AppSheet.show(
      context: context,
      title: l10n.translate('settings.app_info.about'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF97300).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🍳', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.translate('app.name'),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 4),
            Text(l10n.translate('app.tagline'),
                style: TextStyle(
                    fontSize: 13,
                    color: palette.textSecondary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 24),
            _AboutRow(
              label: l10n.translate('settings.app_info.version'),
              value: '${info.version} (${info.buildNumber})',
              palette: palette,
            ),
            _AboutRow(
              label: l10n.translate('settings.app_info.user_id'),
              value: uid.length > 16 ? '${uid.substring(0, 16)}…' : uid,
              palette: palette,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeEmailDialog(BuildContext context) async {
    final appLoc = AppLocalizations.of(context);
    await AppSheet.show(
      context: context,
      title: appLoc.translate('settings.account.change_email_title'),
      child: _ChangeEmailSheet(
        appLoc: appLoc,
        onSave: (email, password) async {
          await AuthService().updateEmail(email, password);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(appLoc
                      .translate('settings.account.change_email_success'))),
            );
          }
        },
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final appLoc = AppLocalizations.of(context);
    await AppSheet.show(
      context: context,
      title: appLoc.translate('settings.account.change_password_title'),
      child: _ChangePasswordSheet(
        appLoc: appLoc,
        onSave: (currentPassword, newPassword) async {
          await AuthService().updatePassword(currentPassword, newPassword);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(appLoc
                      .translate('settings.account.change_password_success'))),
            );
          }
        },
      ),
    );
  }

  Future<void> _exportUserData(BuildContext context) async {
    final appLoc = AppLocalizations.of(context);
    // Show loading dialog — intentionally not awaited; dismissed after export
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    ));
    try {
      await DataExportService().exportAndShare();
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.error(
          context, appLoc.translate('settings.account.export_error'));
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final appLoc = AppLocalizations.of(context);
    await AppSheet.show(
      context: context,
      title: appLoc.translate('settings.account.delete_title'),
      child: _DeleteAccountSheet(
        appLoc: appLoc,
        onDelete: (password) async {
          await AuthService().deleteAccount(password: password);
          if (!context.mounted) return;
          unawaited(Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          ));
        },
      ),
    );
  }

  static String _languageDisplayName(String code) =>
      code == 'tr' ? 'Türkçe' : 'English';

  Future<void> _showLanguageSheet(
    BuildContext context,
    LanguageProvider languageProvider,
    AppLocalizations appLoc,
    AppPalette palette,
  ) async {
    const languages = [
      ('en', 'English', '🇬🇧'),
      ('tr', 'Türkçe', '🇹🇷'),
    ];
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    await AppSheet.show(
      context: context,
      title: appLoc.translate('settings.app_language'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((lang) {
          final (code, name, flag) = lang;
          final isSelected =
              languageProvider.currentLocale.languageCode == code;
          return GestureDetector(
            onTap: () {
              languageProvider.setLanguage(code);
              Navigator.of(context).pop();
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.10)
                    : palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.card.r),
                border: Border.all(
                  color: isSelected
                      ? primary.withValues(alpha: 0.4)
                      : palette.border.withValues(alpha: 0.3),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(flag, style: TextStyle(fontSize: 24.sp)),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Text(
                      name,
                      style: t.bodyM.copyWith(
                        color: isSelected ? primary : palette.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        color: primary, size: 20.sp),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final testModeProvider = Provider.of<TestModeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final appLoc = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final primaryColor = themeProvider.primaryColor;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // ── Mesh-glow ambient blobs ──
          ...AppGradients.meshGlow(palette, primaryColor),

          // ── Main content ──
          Column(
            children: [
              // ── Frosted AppBar ──
              _SettingsAppBar(
                primaryColor: primaryColor,
                palette: palette,
                topPad: topPad,
                onBack: () => Navigator.pop(context),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 40),
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // Premium Section
                    _buildPremiumCard(context, primaryColor, appLoc, palette),

                    const SizedBox(height: 24),

                    // Appearance Section
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.appearance.title'),
                      palette: palette,
                      children: [
                        // Dark Mode
                        _buildSettingsRow(
                          context,
                          icon: Icons.dark_mode,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.3)
                              : palette.info.withValues(alpha: 0.15),
                          title: appLoc.translate('settings.appearance.dark'),
                          palette: palette,
                          trailing: Switch.adaptive(
                            value: themeProvider.themeMode == ThemeMode.dark,
                            onChanged: (val) {
                              themeProvider.setThemeMode(
                                  val ? ThemeMode.dark : ThemeMode.light);
                            },
                            activeTrackColor: primaryColor,
                            activeThumbColor: Colors.white,
                          ),
                        ),
                        // Theme Color
                        _buildSettingsRow(
                          context,
                          icon: Icons.palette,
                          iconColor: primaryColor,
                          iconBgColor: palette.isDark
                              ? primaryColor.withValues(alpha: 0.3)
                              : palette.error.withValues(alpha: 0.12),
                          title: appLoc
                              .translate('settings.appearance.theme_color'),
                          palette: palette,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildColorOption(themeProvider,
                                  const Color(0xFFF97300), palette),
                              const SizedBox(width: 8),
                              _buildColorOption(
                                  themeProvider, Colors.blue, palette),
                              const SizedBox(width: 8),
                              _buildColorOption(
                                  themeProvider, Colors.green, palette),
                              const SizedBox(width: 8),
                              _buildColorOption(
                                  themeProvider,
                                  const Color.fromARGB(255, 255, 77, 193),
                                  palette),
                            ],
                          ),
                        ),
                        // Language
                        _buildSettingsRow(
                          context,
                          icon: Icons.language,
                          iconColor: palette.textSecondary,
                          iconBgColor: palette.isDark
                              ? palette.shadow.withValues(alpha: 0.3)
                              : palette.calories.withValues(alpha: 0.15),
                          title: appLoc.translate('settings.language'),
                          palette: palette,
                          onTap: () => _showLanguageSheet(
                              context, languageProvider, appLoc, palette),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _languageDisplayName(languageProvider
                                    .currentLocale.languageCode),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: palette.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right,
                                  color: palette.textSecondary),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Notifications section
                    _buildNotificationsSection(
                      context: context,
                      appLoc: appLoc,
                      palette: palette,
                      primaryColor: primaryColor,
                      uid: uid,
                    ),

                    const SizedBox(height: 24),

                    // Privacy Settings
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.privacy.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.lock,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.3)
                              : palette.info.withValues(alpha: 0.15),
                          title: appLoc
                              .translate('settings.privacy.account_privacy'),
                          subtitle: appLoc.translate(
                              'settings.privacy.account_privacy_subtitle'),
                          palette: palette,
                          trailing: Switch.adaptive(
                            value: userProvider.user?.isPrivate ?? false,
                            onChanged: (val) =>
                                unawaited(_togglePrivacy(context, val)),
                            activeTrackColor: primaryColor,
                            activeThumbColor: Colors.white,
                          ),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.group_add,
                          iconColor: palette.success,
                          iconBgColor: palette.isDark
                              ? palette.success.withValues(alpha: 0.3)
                              : palette.success.withValues(alpha: 0.15),
                          title: appLoc
                              .translate('settings.privacy.friend_requests'),
                          palette: palette,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appLoc.translate(
                                    'settings.privacy.friend_requests_subtitle'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: palette.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right,
                                  color: palette.textSecondary),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Nutrition
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('dietary_prefs.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.block_rounded,
                          iconColor: palette.warning,
                          iconBgColor: palette.isDark
                              ? palette.warning.withValues(alpha: 0.3)
                              : palette.warning.withValues(alpha: 0.12),
                          title: appLoc.translate('dietary_prefs.avoid_title'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const DietaryPreferencesScreen()),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Permissions & Notifications
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.permissions.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.notifications,
                          iconColor: palette.error,
                          iconBgColor: palette.isDark
                              ? palette.error.withValues(alpha: 0.3)
                              : palette.error.withValues(alpha: 0.12),
                          title: appLoc.translate('settings.notifications'),
                          palette: palette,
                          onTap: _openNotificationSettings,
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.tune_rounded,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.3)
                              : palette.info.withValues(alpha: 0.12),
                          title: appLoc.translate('notification_prefs.title'),
                          palette: palette,
                          onTap: () => _showNotificationPreferences(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.water_drop_rounded,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.3)
                              : palette.info.withValues(alpha: 0.12),
                          title:
                              appLoc.translate('water_reminder.settings_title'),
                          subtitle: ((userProvider.user
                                          ?.onboardingData?['water_reminder']
                                      as Map?)?['enabled'] ==
                                  true)
                              ? appLoc.translate('water_reminder.settings_on')
                              : appLoc.translate('water_reminder.settings_off'),
                          palette: palette,
                          onTap: () => _showWaterReminderSheet(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.restaurant_rounded,
                          iconColor: palette.success,
                          iconBgColor: palette.isDark
                              ? palette.success.withValues(alpha: 0.3)
                              : palette.success.withValues(alpha: 0.12),
                          title:
                              appLoc.translate('settings.reminders.meal_title'),
                          subtitle: ((userProvider.user
                                          ?.onboardingData?['meal_reminder']
                                      as Map?)?['enabled'] ==
                                  true)
                              ? appLoc.translate('settings.reminders.meal_on')
                              : appLoc.translate('settings.reminders.meal_off'),
                          palette: palette,
                          onTap: () => _showMealReminderSheet(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.smartphone,
                          iconColor: palette.energy,
                          iconBgColor: palette.isDark
                              ? palette.energy.withValues(alpha: 0.3)
                              : palette.energy.withValues(alpha: 0.15),
                          title: appLoc.translate(
                              'settings.permissions.device_permissions'),
                          palette: palette,
                          onTap: _openNotificationSettings,
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // App Info
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.app_info.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          title: appLoc.translate('settings.app_info.about'),
                          palette: palette,
                          paddingLeft: 0,
                          onTap: () => _showAboutSheet(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.play_circle_outline_rounded,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title: appLoc.translate('intro.replay_title'),
                          subtitle: appLoc.translate('intro.replay_subtitle'),
                          palette: palette,
                          onTap: () => Navigator.of(context).push(
                            AppTransitions.slideRight(
                                const IntroScreen(isReplay: true)),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          title: appLoc.translate('settings.app_info.help'),
                          palette: palette,
                          paddingLeft: 0,
                          onTap: _openHelp,
                          trailing: Icon(Icons.open_in_new,
                              size: 20, color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.tune_rounded,
                          iconColor: palette.success,
                          iconBgColor: palette.isDark
                              ? palette.success.withValues(alpha: 0.2)
                              : palette.success.withValues(alpha: 0.15),
                          title: appLoc.translate('consent.title'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConsentCenterScreen(),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.gpp_good_outlined,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title: appLoc.translate('privacy_request.title'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyRequestScreen(),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          iconColor: palette.energy,
                          iconBgColor: palette.isDark
                              ? palette.energy.withValues(alpha: 0.2)
                              : palette.energy.withValues(alpha: 0.15),
                          title: appLoc.translate('settings.privacy_policy'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalDocumentType.privacyPolicy),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.description_outlined,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title: appLoc.translate('settings.terms_of_service'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalDocumentType.termsOfUse),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.shield_outlined,
                          iconColor: palette.warning,
                          iconBgColor: palette.isDark
                              ? palette.warning.withValues(alpha: 0.2)
                              : palette.warning.withValues(alpha: 0.15),
                          title: appLoc.translate('legal.kvkk_title'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalDocumentType.kvkkClarification),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.verified_user_outlined,
                          iconColor: palette.success,
                          iconBgColor: palette.isDark
                              ? palette.success.withValues(alpha: 0.2)
                              : palette.success.withValues(alpha: 0.15),
                          title: appLoc.translate('legal.consent_title'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalDocumentType.explicitConsent),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Developer Section
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.developer.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.bug_report_outlined,
                          iconColor: palette.fat,
                          iconBgColor: palette.isDark
                              ? palette.fat.withValues(alpha: 0.3)
                              : palette.fat.withValues(alpha: 0.15),
                          title:
                              appLoc.translate('settings.developer.test_mode'),
                          subtitle: appLoc.translate(
                              'settings.developer.test_mode_subtitle'),
                          palette: palette,
                          trailing: Switch.adaptive(
                            value: testModeProvider.isActive,
                            onChanged: (_) => testModeProvider.toggle(),
                            activeTrackColor: palette.fat,
                            activeThumbColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Refer a Friend
                    _ReferralCard(palette: palette, appLoc: appLoc),

                    const SizedBox(height: 16),

                    // AI & Credits
                    if (userProvider.user != null) ...[
                      _buildGlassSection(
                        context: context,
                        title: appLoc.translate('settings.ai_credits_title'),
                        palette: palette,
                        children: [
                          _buildSettingsRow(
                            context,
                            icon: Icons.bolt_rounded,
                            iconColor: palette.warning,
                            iconBgColor: palette.isDark
                                ? palette.warning.withValues(alpha: 0.2)
                                : palette.warning.withValues(alpha: 0.15),
                            title:
                                appLoc.translate('settings.ai_credits_title'),
                            subtitle:
                                appLoc.translate('settings.ai_credits_sub'),
                            palette: palette,
                            onTap: () => unawaited(AiCreditsSheet.show(
                              context,
                              uid: userProvider.user!.uid,
                              isPremium: userProvider
                                  .user!.subscriptionTier.isPremiumOrAbove,
                            )),
                            trailing: Icon(Icons.chevron_right_rounded,
                                color: palette.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Go Pro / Business on-ramp
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.business.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: userProvider.user?.hasRole(UserRole.gymOwner) ==
                                  true
                              ? Icons.dashboard_rounded
                              : Icons.add_business_rounded,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title: userProvider.user
                                      ?.hasRole(UserRole.gymOwner) ==
                                  true
                              ? appLoc.translate('settings.business.my_gym')
                              : appLoc
                                  .translate('settings.business.register_gym'),
                          subtitle: userProvider.user
                                      ?.hasRole(UserRole.gymOwner) ==
                                  true
                              ? appLoc.translate('settings.business.my_gym_sub')
                              : appLoc.translate(
                                  'settings.business.register_gym_sub'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            AppTransitions.slideUp(const GymDashboardScreen()),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.sports_rounded,
                          iconColor: const Color(0xFF6366F1),
                          iconBgColor: palette.isDark
                              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                              : const Color(0xFF6366F1).withValues(alpha: 0.15),
                          title: userProvider.user?.hasRole(UserRole.coach) ==
                                  true
                              ? appLoc
                                  .translate('settings.business.my_coaching')
                              : appLoc
                                  .translate('settings.business.become_coach'),
                          subtitle:
                              userProvider.user?.hasRole(UserRole.coach) == true
                                  ? appLoc.translate(
                                      'settings.business.my_coaching_sub')
                                  : appLoc.translate(
                                      'settings.business.become_coach_sub'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            AppTransitions.slideUp(
                                const CoachDashboardScreen()),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: palette.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Admin panel (admin-only)
                    if (userProvider.user?.hasRole(UserRole.admin) == true) ...[
                      _buildGlassSection(
                        context: context,
                        title: appLoc.translate('admin.panel_title'),
                        palette: palette,
                        children: [
                          _buildSettingsRow(
                            context,
                            icon: Icons.admin_panel_settings_rounded,
                            iconColor: palette.error,
                            iconBgColor: palette.isDark
                                ? palette.error.withValues(alpha: 0.2)
                                : palette.error.withValues(alpha: 0.15),
                            title: appLoc.translate('admin.panel_title'),
                            subtitle:
                                '${appLoc.translate('admin.tab_coaches')} & ${appLoc.translate('admin.tab_gyms')}',
                            palette: palette,
                            onTap: () => Navigator.push(
                              context,
                              AppTransitions.slideRight(
                                  const AdminPanelScreen()),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded,
                                color: palette.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // My Earnings
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.earnings.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: palette.success,
                          iconBgColor: palette.isDark
                              ? palette.success.withValues(alpha: 0.2)
                              : palette.success.withValues(alpha: 0.15),
                          title: appLoc.translate('settings.earnings.title'),
                          subtitle: appLoc
                              .translate('settings.earnings.coming_soon_short'),
                          palette: palette,
                          onTap: () => Navigator.push(
                            context,
                            AppTransitions.slideUp(
                                const AffiliateEarningsScreen()),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: palette.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Account / Danger Zone
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.account.title'),
                      palette: palette,
                      isDangerZone: true,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.email_outlined,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title:
                              appLoc.translate('settings.account.change_email'),
                          palette: palette,
                          onTap: () => _showChangeEmailDialog(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.lock_outline,
                          iconColor: palette.warning,
                          iconBgColor: palette.isDark
                              ? palette.warning.withValues(alpha: 0.2)
                              : palette.calories.withValues(alpha: 0.15),
                          title: appLoc
                              .translate('settings.account.change_password'),
                          palette: palette,
                          onTap: () => _showChangePasswordDialog(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.download_outlined,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title:
                              appLoc.translate('settings.account.export_data'),
                          subtitle: appLoc.translate(
                              'settings.account.export_data_subtitle'),
                          palette: palette,
                          onTap: () => _exportUserData(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.delete_forever,
                          iconColor: palette.error,
                          iconBgColor: palette.isDark
                              ? palette.error.withValues(alpha: 0.2)
                              : palette.error.withValues(alpha: 0.12),
                          title: appLoc
                              .translate('settings.account.delete_account'),
                          palette: palette,
                          onTap: () => _showDeleteAccountDialog(context),
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "${appLoc.translate('settings.app_info.version')}: 1.0.0 Beta",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${appLoc.translate('settings.app_info.user_id')}: $uid",
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Notifications section ──────────────────────────────────────────────────

  static const _notifGroupMeta = <String, (IconData, String)>{
    'likes': (Icons.thumb_up_outlined, 'settings.notif_prefs.likes'),
    'comments': (Icons.comment_outlined, 'settings.notif_prefs.comments'),
    'friends': (Icons.people_outline_rounded, 'settings.notif_prefs.friends'),
    'system': (Icons.notifications_outlined, 'settings.notif_prefs.system'),
    'referral': (Icons.card_giftcard_outlined, 'settings.notif_prefs.referral'),
    'reminders': (Icons.alarm_on_rounded, 'settings.notif_prefs.reminders'),
  };

  Widget _buildNotificationsSection({
    required BuildContext context,
    required AppLocalizations appLoc,
    required AppPalette palette,
    required Color primaryColor,
    required String uid,
  }) {
    final iconColor = primaryColor;
    final iconBgColor = palette.isDark
        ? primaryColor.withValues(alpha: 0.25)
        : primaryColor.withValues(alpha: 0.12);

    final children = <Widget>[];
    for (final group in _notifGroups) {
      final meta = _notifGroupMeta[group]!;
      if (_notifLoading) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: AppShimmer(
              child: Row(
                children: [
                  AppSkeletonBox(width: 32, height: 32, radius: 32),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppSkeletonBox(
                        width: double.infinity, radius: AppRadius.card),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  AppSkeletonBox(width: 48, height: 28, radius: AppRadius.md),
                ],
              ),
            ),
          ),
        );
      } else {
        final enabled = _notifEnabled[group] ?? true;
        children.add(
          _buildSettingsRow(
            context,
            icon: meta.$1,
            iconColor: iconColor,
            iconBgColor: iconBgColor,
            title: appLoc.translate(meta.$2),
            palette: palette,
            trailing: Switch.adaptive(
              value: enabled,
              activeTrackColor: primaryColor,
              activeThumbColor: Colors.white,
              onChanged: (newValue) async {
                setState(() => _notifEnabled[group] = newValue);
                await NotificationPreferencesService()
                    .setGroupMuted(uid, group, !newValue);
                // No post-await mounted check needed — setGroupMuted is
                // fire-and-forget; optimistic update already applied above.
              },
            ),
          ),
        );
      }
    }

    return _buildGlassSection(
      context: context,
      title: appLoc.translate('settings.notifications'),
      palette: palette,
      children: children,
    );
  }

  Widget _buildPremiumCard(BuildContext context, Color primaryColor,
      AppLocalizations appLoc, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: primaryColor,
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -24,
            bottom: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -25,
            left: -25,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.black12.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: palette.warning),
                    const SizedBox(width: 8),
                    Text(
                      appLoc.translate('settings.premium.badge').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  appLoc.translate('settings.premium.title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: Text(
                    appLoc.translate('settings.premium.description'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => FeatureGateService().showPaywall(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                    ),
                    child: Text(
                      appLoc.translate('settings.premium.button'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection({
    required BuildContext context,
    required String title,
    required AppPalette palette,
    required List<Widget> children,
    bool isDangerZone = false,
  }) {
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Text(
            title.toUpperCase(),
            style: t.labelS.copyWith(
              color: palette.textTertiary,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppPalette.glassBlurDefault,
              sigmaY: AppPalette.glassBlurDefault,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: palette.glassFill,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isDangerZone
                      ? palette.error.withValues(alpha: 0.3)
                      : palette.glassStroke,
                  width: isDangerZone ? 1.0 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _intersperse(
                  children,
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                    color: palette.border.withValues(alpha: 0.5),
                  ),
                ).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Iterable<Widget> _intersperse(List<Widget> items, Widget separator) sync* {
    for (var i = 0; i < items.length; i++) {
      yield items[i];
      if (i < items.length - 1) yield separator;
    }
  }

  Widget _buildSettingsRow(
    BuildContext context, {
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    String? subtitle,
    required AppPalette palette,
    Widget? trailing,
    VoidCallback? onTap,
    double paddingLeft = 16,
  }) {
    final t = AppText.of(context);
    return Ink(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: palette.glassStroke.withValues(alpha: 0.12),
        highlightColor: palette.glassHighlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: AppSize.iconSm, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.sm),
              ] else if (paddingLeft == 0)
                const SizedBox(width: 0)
              else
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.titleM.copyWith(
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: t.bodyM.copyWith(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(
      ThemeProvider provider, Color color, AppPalette palette) {
    bool isSelected = provider.primaryColor == color;
    return GestureDetector(
      onTap: () => provider.setPrimaryColor(color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: palette.surface,
                  width: 2,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: isSelected
            ? Center(
                child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)))
            : null,
      ),
    );
  }
}

// ── Settings bottom sheet helpers ──────────────────────────────────────────

Widget _dsTextField({
  required TextEditingController controller,
  required String label,
  required AppPalette palette,
  required Color primary,
  bool obscureText = false,
  TextInputType? keyboardType,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    cursorColor: primary,
    style: TextStyle(color: palette.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      filled: true,
      fillColor: palette.surfaceVariant.withValues(alpha: 0.5),
      contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
    ),
  );
}

class _ChangeEmailSheet extends StatefulWidget {
  final AppLocalizations appLoc;
  final Future<void> Function(String email, String password) onSave;

  const _ChangeEmailSheet({required this.appLoc, required this.onSave});

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dsTextField(
          controller: _emailCtrl,
          label: widget.appLoc.translate('settings.account.change_email_new'),
          palette: palette,
          primary: primary,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: AppSpacing.md.h),
        _dsTextField(
          controller: _passCtrl,
          label:
              widget.appLoc.translate('settings.account.change_email_password'),
          palette: palette,
          primary: primary,
          obscureText: true,
        ),
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: widget.appLoc.translate('common.save'),
          loading: _isLoading,
          onPressed: _isLoading
              ? null
              : () async {
                  final email = _emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await widget.onSave(email, _passCtrl.text);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: palette.error));
                    }
                  }
                },
        ),
      ],
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final AppLocalizations appLoc;
  final Future<void> Function(String currentPassword, String newPassword)
      onSave;

  const _ChangePasswordSheet({required this.appLoc, required this.onSave});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dsTextField(
          controller: _currentCtrl,
          label: widget.appLoc.translate('settings.account.current_password'),
          palette: palette,
          primary: primary,
          obscureText: true,
        ),
        SizedBox(height: AppSpacing.md.h),
        _dsTextField(
          controller: _newCtrl,
          label: widget.appLoc.translate('settings.account.new_password'),
          palette: palette,
          primary: primary,
          obscureText: true,
        ),
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: widget.appLoc.translate('common.save'),
          loading: _isLoading,
          onPressed: _isLoading
              ? null
              : () async {
                  final cur = _currentCtrl.text;
                  final n = _newCtrl.text;
                  if (cur.isEmpty || n.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await widget.onSave(cur, n);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: palette.error));
                    }
                  }
                },
        ),
      ],
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  final AppLocalizations appLoc;
  final Future<void> Function(String password) onDelete;

  const _DeleteAccountSheet({required this.appLoc, required this.onDelete});

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.md.r),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(color: palette.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: palette.error, size: 20.r),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text(
                  widget.appLoc.translate('settings.account.delete_warning'),
                  style: t.labelM.copyWith(color: palette.error),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
        _dsTextField(
          controller: _passCtrl,
          label: widget.appLoc.translate('auth.password'),
          palette: palette,
          primary: primary,
          obscureText: true,
        ),
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: widget.appLoc.translate('settings.account.delete_confirm'),
          loading: _isLoading,
          onPressed: _isLoading
              ? null
              : () async {
                  final pass = _passCtrl.text;
                  if (pass.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await widget.onDelete(pass);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: palette.error));
                    }
                  }
                },
        ),
      ],
    );
  }
}

// ── Referral card ────────────────────────────────────────────────────────────

class _ReferralCard extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations appLoc;

  const _ReferralCard({required this.palette, required this.appLoc});

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  String? _code;
  int _referralCount = 0;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await ReferralService().getOrCreateCode();
      final count = await ReferralService().getReferralCount();
      if (mounted) {
        setState(() {
          _code = code;
          _referralCount = count;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _share(BuildContext buttonContext) {
    if (_code == null) return;

    final box = buttonContext.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    ReferralService()
        .shareCode(buttonContext, _code!, sharePositionOrigin: rect);
  }

  Future<void> _showApplySheet() async {
    await AppSheet.show(
      context: context,
      title: widget.appLoc.translate('settings.referral.enter_code_title'),
      child: _ApplyCodeSheet(
        appLoc: widget.appLoc,
        palette: widget.palette,
        onApply: (code) async {
          if (mounted) setState(() => _applying = true);
          final error = await ReferralService().applyCode(code);
          if (!mounted) return;
          setState(() => _applying = false);
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
          if (error != null) {
            // ignore: use_build_context_synchronously
            AppSnackBar.error(context, error);
          } else {
            // ignore: use_build_context_synchronously
            AppSnackBar.success(
              context,
              widget.appLoc.translate('settings.referral.applied_success'),
            );
          }
        },
        applying: _applying,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.appLoc;
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.r,
                height: 36.r,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.card_giftcard_rounded,
                    color: primary, size: 20.r),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text(
                  l10n.translate('settings.referral.title'),
                  style: t.titleL,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            l10n.translate('settings.referral.subtitle'),
            style: t.bodyM.copyWith(color: palette.textSecondary, fontSize: 13),
          ),
          SizedBox(height: AppSpacing.md.h),
          if (_loading)
            AppSkeletonBox(height: 48.h, width: double.infinity)
          else if (_code != null) ...[
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                border: Border.all(
                    color: primary.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _code!,
                    style: t.headlineS.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  if (_referralCount > 0)
                    Text(
                      '${_referralCount}x used',
                      style: t.labelM.copyWith(color: palette.textSecondary),
                    ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (buttonContext) => AppButton(
                      label: l10n.translate('settings.referral.share'),
                      onPressed: () => _share(buttonContext),
                      size: AppButtonSize.medium,
                      icon: Icons.share_outlined,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                AppButton(
                  label: l10n.translate('settings.referral.have_code'),
                  onPressed: _showApplySheet,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.medium,
                  expand: false,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplyCodeSheet extends StatefulWidget {
  final AppLocalizations appLoc;
  final AppPalette palette;
  final Future<void> Function(String) onApply;
  final bool applying;

  const _ApplyCodeSheet({
    required this.appLoc,
    required this.palette,
    required this.onApply,
    required this.applying,
  });

  @override
  State<_ApplyCodeSheet> createState() => _ApplyCodeSheetState();
}

class _ApplyCodeSheetState extends State<_ApplyCodeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _ctrl,
          labelText:
              widget.appLoc.translate('settings.referral.enter_code_label'),
          hintText:
              widget.appLoc.translate('profile.settings.referral_code_placeholder'),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          ],
        ),
        SizedBox(height: AppSpacing.lg.h),
        AppButton(
          label: widget.appLoc.translate('settings.referral.apply'),
          loading: widget.applying,
          onPressed: () {
            final code = _ctrl.text.trim();
            if (code.isNotEmpty) widget.onApply(code);
          },
        ),
        SizedBox(height: AppSpacing.xl.h),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;

  const _AboutRow({
    required this.label,
    required this.value,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: palette.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary)),
        ],
      ),
    );
  }
}

// ── Frosted AppBar ────────────────────────────────────────────────────────────

class _SettingsAppBar extends StatelessWidget {
  final Color primaryColor;
  final AppPalette palette;
  final double topPad;
  final VoidCallback onBack;

  const _SettingsAppBar({
    required this.primaryColor,
    required this.palette,
    required this.topPad,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppPalette.glassBlurSubtle,
          sigmaY: AppPalette.glassBlurSubtle,
        ),
        child: Container(
          color: palette.background.withValues(alpha: 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          Icon(Icons.arrow_back, color: palette.textSecondary),
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        'Settings',
                        style: AppText.of(context).labelL.copyWith(
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                              color: palette.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Brand gradient accent line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.sunsetA,
                      primaryColor,
                      AppPalette.sunsetC,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tappable time field for the water-reminder settings sheet.
class _WaterTimeField extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  const _WaterTimeField(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelS.copyWith(color: palette.textTertiary)),
            const SizedBox(height: 2),
            Text(
              time,
              style: t.titleM
                  .copyWith(color: primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
