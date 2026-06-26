import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/utils/app_routes.dart';
import '../legal/legal_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showChangeEmailDialog(BuildContext context) async {
    final appLoc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangeEmailDialog(
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangePasswordDialog(
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

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final appLoc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeleteAccountDialog(
        appLoc: appLoc,
        onDelete: (password) async {
          await AuthService().deleteAccount(password: password);
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Design specific colors
    final primaryColor = themeProvider.primaryColor;
    final backgroundColor =
        isDark ? const Color(0xFF111827) : const Color(0xFFFDFDFD);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background Glows
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
                    isDark
                        ? primaryColor.withValues(alpha: 0.2)
                        : const Color(0xFFFFEDD5).withValues(alpha: 0.6),
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
                    isDark
                        ? Colors.blue[900]!.withValues(alpha: 0.2)
                        : const Color(0xFFEFF6FF).withValues(alpha: 0.6),
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
                          icon: Icon(Icons.arrow_back,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Premium Section
                    _buildPremiumCard(context, primaryColor, appLoc),

                    const SizedBox(height: 24),

                    // Appearance Section
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.appearance.title'),
                      isDark: isDark,
                      children: [
                        // Dark Mode
                        _buildSettingsRow(
                          context,
                          icon: Icons.dark_mode,
                          iconColor: Colors.indigo,
                          iconBgColor: isDark
                              ? Colors.indigo.withValues(alpha: 0.3)
                              : const Color(0xFFEEF2FF), // indigo-50
                          title: appLoc.translate('settings.appearance.dark'),
                          isDark: isDark,
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
                          iconBgColor: isDark
                              ? primaryColor.withValues(alpha: 0.3)
                              : const Color(0xFFFCE7F3), // pink-50
                          title: appLoc
                              .translate('settings.appearance.theme_color'),
                          isDark: isDark,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildColorOption(themeProvider,
                                  const Color(0xFFF97300), isDark),
                              const SizedBox(width: 8),
                              _buildColorOption(
                                  themeProvider, Colors.blue, isDark),
                              const SizedBox(width: 8),
                              _buildColorOption(
                                  themeProvider, Colors.green, isDark),
                              const SizedBox(width: 8),
                              _buildColorOption(
                                  themeProvider,
                                  const Color.fromARGB(255, 255, 77, 193),
                                  isDark),
                            ],
                          ),
                        ),
                        // Language
                        _buildSettingsRow(
                          context,
                          icon: Icons.language,
                          iconColor: Colors.black54,
                          iconBgColor: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : const Color(0xFFFFF7ED), // orange-50
                          title: appLoc.translate('settings.language'),
                          isDark: isDark,
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
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[500]),
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
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.lock,
                          iconColor: Colors.blue,
                          iconBgColor: isDark
                              ? Colors.blue.withValues(alpha: 0.3)
                              : const Color(0xFFEFF6FF), // blue-50
                          title: appLoc
                              .translate('settings.privacy.account_privacy'),
                          subtitle: appLoc.translate(
                              'settings.privacy.account_privacy_subtitle'),
                          isDark: isDark,
                          trailing: Switch(
                            value: true, // Mock value
                            onChanged: (val) {},
                            activeThumbColor: primaryColor,
                          ),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.group_add,
                          iconColor: Colors.green,
                          iconBgColor: isDark
                              ? Colors.green.withValues(alpha: 0.3)
                              : const Color(0xFFF0FDF4), // green-50
                          title: appLoc
                              .translate('settings.privacy.friend_requests'),
                          isDark: isDark,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appLoc.translate(
                                    'settings.privacy.friend_requests_subtitle'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[500]),
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
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.notifications,
                          iconColor: Colors.red,
                          iconBgColor: isDark
                              ? Colors.red.withValues(alpha: 0.3)
                              : const Color(0xFFFEF2F2), // red-50
                          title: appLoc.translate('settings.notifications'),
                          isDark: isDark,
                          trailing: Icon(Icons.chevron_right,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[400]),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.smartphone,
                          iconColor: Colors.teal,
                          iconBgColor: isDark
                              ? Colors.teal.withValues(alpha: 0.3)
                              : const Color(0xFFF0FDFA), // teal-50
                          title: appLoc.translate(
                              'settings.permissions.device_permissions'),
                          isDark: isDark,
                          trailing: Icon(Icons.chevron_right,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[400]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // App Info
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.app_info.title'),
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          context,
                          title: appLoc.translate('settings.app_info.about'),
                          isDark: isDark,
                          paddingLeft: 0,
                          trailing: Icon(Icons.chevron_right,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[400]),
                        ),
                        _buildSettingsRow(
                          context,
                          title: appLoc.translate('settings.app_info.help'),
                          isDark: isDark,
                          paddingLeft: 0,
                          trailing: Icon(Icons.open_in_new,
                              size: 20,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[400]),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          iconColor: Colors.teal,
                          iconBgColor: isDark
                              ? Colors.teal.withValues(alpha: 0.2)
                              : const Color(0xFFF0FDFA),
                          title: appLoc.translate('settings.privacy_policy'),
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalDocumentType.privacyPolicy),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[400]),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.description_outlined,
                          iconColor: Colors.blue,
                          iconBgColor: isDark
                              ? Colors.blue.withValues(alpha: 0.2)
                              : const Color(0xFFEFF6FF),
                          title: appLoc.translate('settings.terms_of_service'),
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalDocumentType.termsOfUse),
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[400]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Developer Section
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.developer.title'),
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.bug_report_outlined,
                          iconColor: Colors.purple,
                          iconBgColor: isDark
                              ? Colors.purple.withValues(alpha: 0.3)
                              : const Color(0xFFF5F3FF),
                          title: appLoc.translate('settings.developer.test_mode'),
                          subtitle: appLoc.translate('settings.developer.test_mode_subtitle'),
                          isDark: isDark,
                          trailing: Switch(
                            value: testModeProvider.isActive,
                            onChanged: (_) => testModeProvider.toggle(),
                            activeThumbColor: Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Account / Danger Zone
                    _buildGlassSection(
                      context: context,
                      title: appLoc.translate('settings.account.title'),
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          context,
                          icon: Icons.email_outlined,
                          iconColor: Colors.blue,
                          iconBgColor: isDark
                              ? Colors.blue.withValues(alpha: 0.2)
                              : const Color(0xFFEFF6FF),
                          title: appLoc.translate('settings.account.change_email'),
                          isDark: isDark,
                          onTap: () => _showChangeEmailDialog(context),
                          trailing: Icon(Icons.chevron_right,
                              color: isDark ? Colors.grey[400] : Colors.grey[400]),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.lock_outline,
                          iconColor: Colors.orange,
                          iconBgColor: isDark
                              ? Colors.orange.withValues(alpha: 0.2)
                              : const Color(0xFFFFF7ED),
                          title: appLoc.translate('settings.account.change_password'),
                          isDark: isDark,
                          onTap: () => _showChangePasswordDialog(context),
                          trailing: Icon(Icons.chevron_right,
                              color: isDark ? Colors.grey[400] : Colors.grey[400]),
                        ),
                        _buildSettingsRow(
                          context,
                          icon: Icons.delete_forever,
                          iconColor: Colors.red,
                          iconBgColor: isDark
                              ? Colors.red.withValues(alpha: 0.2)
                              : const Color(0xFFFEF2F2),
                          title: appLoc
                              .translate('settings.account.delete_account'),
                          isDark: isDark,
                          onTap: () => _showDeleteAccountDialog(context),
                          trailing: Icon(Icons.chevron_right,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[400]),
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
                              color:
                                  isDark ? Colors.grey[600] : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${appLoc.translate('settings.app_info.user_id')}: $uid",
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  isDark ? Colors.grey[600] : Colors.grey[500],
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
      BuildContext context, Color primaryColor, AppLocalizations appLoc) {
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
                    const Icon(Icons.workspace_premium,
                        color: Color(0xFFFDE047)), // yellow-300
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
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F2937)
                .withValues(alpha: 0.9) // Higher opacity since no blur
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                color: isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.5)
                    : Colors.grey[50]!.withValues(alpha: 0.5),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  ),
                ),
              ),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
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
    required bool isDark,
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
                      color: isDark ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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

  Widget _buildColorOption(ThemeProvider provider, Color color, bool isDark) {
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
                  color: isDark ? Colors.grey[800]! : Colors.white,
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

class _ChangeEmailDialog extends StatefulWidget {
  final AppLocalizations appLoc;
  final Future<void> Function(String email, String password) onSave;

  const _ChangeEmailDialog({
    required this.appLoc,
    required this.onSave,
  });

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appLoc.translate('settings.account.change_email_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: widget.appLoc.translate('settings.account.change_email_new'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.appLoc.translate('settings.account.change_email_password'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(widget.appLoc.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await widget.onSave(
                      email,
                      _passwordController.text,
                    );
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.appLoc.translate('common.save')),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final AppLocalizations appLoc;
  final Future<void> Function(String currentPassword, String newPassword) onSave;

  const _ChangePasswordDialog({
    required this.appLoc,
    required this.onSave,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appLoc.translate('settings.account.change_password_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.appLoc.translate('settings.account.current_password'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.appLoc.translate('settings.account.new_password'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(widget.appLoc.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final cur = _currentPasswordController.text;
                  final n = _newPasswordController.text;
                  if (cur.isEmpty || n.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await widget.onSave(
                      cur,
                      n,
                    );
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.appLoc.translate('common.save')),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final AppLocalizations appLoc;
  final Future<void> Function(String password) onDelete;

  const _DeleteAccountDialog({
    required this.appLoc,
    required this.onDelete,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _passwordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appLoc.translate('settings.account.delete_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.appLoc.translate('settings.account.delete_warning')),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.appLoc.translate('auth.password'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(widget.appLoc.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final pass = _passwordController.text;
                  if (pass.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await widget.onDelete(pass);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.appLoc.translate('settings.account.delete_confirm')),
        ),
      ],
    );
  }
}
