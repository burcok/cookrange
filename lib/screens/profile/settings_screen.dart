import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/services/referral_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';
import '../legal/legal_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              SnackBar(content: Text(appLoc.translate('settings.account.change_email_success'))),
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
              SnackBar(content: Text(appLoc.translate('settings.account.change_password_success'))),
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
      AppSnackBar.error(context, appLoc.translate('settings.account.export_error'));
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final testModeProvider = Provider.of<TestModeProvider>(context);
    final appLoc = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Design specific colors
    final primaryColor = themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withValues(alpha: palette.isDark ? 0.2 : 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.info.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // Content
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

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
                          trailing: Switch(
                            value: themeProvider.themeMode == ThemeMode.dark,
                            onChanged: (val) {
                              themeProvider.setThemeMode(
                                  val ? ThemeMode.dark : ThemeMode.light);
                            },
                            activeThumbColor: primaryColor,
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
                          onTap: () {
                            // Simple language toggle for now, or could show dialog
                            if (languageProvider.currentLocale.languageCode ==
                                'en') {
                              languageProvider.setLanguage('tr');
                            } else {
                              languageProvider.setLanguage('en');
                            }
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                languageProvider.currentLocale.languageCode ==
                                        'tr'
                                    ? 'Türkçe'
                                    : 'English',
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
                          trailing: Switch(
                            value: true, // Mock value
                            onChanged: (val) {},
                            activeThumbColor: primaryColor,
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
                          trailing: Icon(Icons.chevron_right,
                              color: palette.textSecondary),
                        ),
                        _buildSettingsRow(
                          context,
                          title: appLoc.translate('settings.app_info.help'),
                          palette: palette,
                          paddingLeft: 0,
                          trailing: Icon(Icons.open_in_new,
                              size: 20,
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
                          title: appLoc.translate('settings.developer.test_mode'),
                          subtitle: appLoc.translate('settings.developer.test_mode_subtitle'),
                          palette: palette,
                          trailing: Switch(
                            value: testModeProvider.isActive,
                            onChanged: (_) => testModeProvider.toggle(),
                            activeThumbColor: palette.fat,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Refer a Friend
                    _ReferralCard(palette: palette, appLoc: appLoc),

                    const SizedBox(height: 24),

                    // Account / Danger Zone
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.account.title'),
                      palette: palette,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.email_outlined,
                          iconColor: palette.info,
                          iconBgColor: palette.isDark
                              ? palette.info.withValues(alpha: 0.2)
                              : palette.info.withValues(alpha: 0.15),
                          title: appLoc.translate('settings.account.change_email'),
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
                          title: appLoc.translate('settings.account.change_password'),
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
                          title: appLoc
                              .translate('settings.account.export_data'),
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

  Widget _buildPremiumCard(
      BuildContext context, Color primaryColor, AppLocalizations appLoc, AppPalette palette) {
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
                    Icon(Icons.workspace_premium,
                        color: palette.warning),
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
                    onPressed: () =>
                        FeatureGateService().showPaywall(context),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.isDark ? 0.9 : 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: palette.surfaceVariant.withValues(alpha: 0.5),
                border: Border(
                  bottom: BorderSide(
                    color: palette.divider,
                  ),
                ),
              ),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: palette.textPrimary,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
            ] else if (paddingLeft == 0)
              const SizedBox(
                  width: 0) // No indent if no icon and explicitly set
            else
              const SizedBox(width: 12), // Some indent if no icon but implicit

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
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
    );
  }

  Widget _buildColorOption(ThemeProvider provider, Color color, AppPalette palette) {
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
      contentPadding:
          EdgeInsets.symmetric(horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
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
          label: widget.appLoc.translate('settings.account.change_email_password'),
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
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
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
  final Future<void> Function(String currentPassword, String newPassword) onSave;

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
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
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
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
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

    ReferralService().shareCode(buttonContext, _code!, sharePositionOrigin: rect);
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
          hintText: 'AB3X9K',
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
