import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';

class GenericErrorScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  final String? errorCode;

  const GenericErrorScreen({
    super.key,
    this.onRetry,
    this.errorCode,
  });

  @override
  State<GenericErrorScreen> createState() => _GenericErrorScreenState();
}

class _GenericErrorScreenState extends State<GenericErrorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleContactSupport() async {
    final localizations = AppLocalizations.of(context);
    final isTr = localizations.locale.languageCode == 'tr';
    final email = isTr ? 'destek@cookrange.com' : 'help@cookrange.com';
    final code = widget.errorCode ?? '500-UNK';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters(<String, String>{
        'subject': isTr ? 'Hata Bildirimi ($code)' : 'Error Report ($code)',
        'body': ''
      }),
    );

    try {
      if (!await launchUrl(emailLaunchUri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Could not launch email client. Please contact $email')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showSystemStatusModal() {
    final localizations = AppLocalizations.of(context);
    _showGlassModal(
        title:
            localizations.translate('generic_error.system_status_modal.title'),
        icon: Icons.dns_rounded,
        color: Colors.purple,
        content: Column(
          children: [
            _buildStatusItem(
                localizations
                    .translate('generic_error.system_status_modal.api_server'),
                true),
            _buildStatusItem(
                localizations
                    .translate('generic_error.system_status_modal.auth_server'),
                true),
            _buildStatusItem(
                localizations
                    .translate('generic_error.system_status_modal.database'),
                true),
          ],
        ));
  }

  void _showTroubleshootModal() {
    final localizations = AppLocalizations.of(context);
    _showGlassModal(
        title:
            localizations.translate('generic_error.troubleshoot_modal.title'),
        icon: Icons.build_rounded,
        color: Colors.cyan,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                localizations
                    .translate('generic_error.troubleshoot_modal.subtitle'),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _buildStep(
                1,
                localizations
                    .translate('generic_error.troubleshoot_modal.step1')),
            _buildStep(
                2,
                localizations
                    .translate('generic_error.troubleshoot_modal.step2')),
            _buildStep(
                3,
                localizations
                    .translate('generic_error.troubleshoot_modal.step3')),
            _buildStep(
                4,
                localizations
                    .translate('generic_error.troubleshoot_modal.step4')),
            _buildStep(
                5,
                localizations
                    .translate('generic_error.troubleshoot_modal.step5')),
          ],
        ));
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.cyan, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String name, bool operational) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: operational
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: operational ? Colors.green : Colors.red,
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                    operational
                        ? localizations.translate(
                            'generic_error.system_status_modal.operational')
                        : localizations.translate(
                            'generic_error.system_status_modal.outage'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: operational ? Colors.green : Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGlassModal(
      {required String title,
      required Widget content,
      required IconData icon,
      required Color color}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withOpacity(0.9)
                  : const Color(0xFFF8FAFC).withOpacity(0.9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 16),
                      Text(title,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[900])),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bgLight = const Color(0xFFF8FAFC);
    final bgDark = const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height / 2,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: (isDark ? Colors.blue[900]! : Colors.blue[300]!)
                    .withOpacity(isDark ? 0.1 : 0.2),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassButton(
                        onTap: () => Navigator.of(context).pop(),
                        width: 40,
                        height: 40,
                        padding: EdgeInsets.zero,
                        child: Icon(Icons.arrow_back,
                            color:
                                isDark ? Colors.grey[300] : Colors.grey[600]),
                      ),
                      Text(
                        localizations.translate('generic_error.title_header'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: FadeTransition(
                      opacity: _opacity,
                      slideTransition: _slide,
                      child: Column(
                        children: [
                          _GlassPanel(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.orange[900]!
                                                .withOpacity(0.2)
                                            : Colors.orange[50],
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.sentiment_dissatisfied_rounded,
                                        size: 48,
                                        color: isDark
                                            ? Colors.orange[400]
                                            : Colors.orange[500],
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 4)
                                          ],
                                        ),
                                        child: Icon(Icons.priority_high_rounded,
                                            size: 18, color: primaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  localizations
                                      .translate('generic_error.title_main'),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  localizations
                                      .translate('generic_error.description'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: widget.onRetry ?? () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 24),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      elevation: 4,
                                      shadowColor:
                                          primaryColor.withOpacity(0.2),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.refresh_rounded,
                                            size: 24),
                                        const SizedBox(width: 8),
                                        Text(
                                            localizations.translate(
                                                'generic_error.button_retry'),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: _GlassButton(
                                      onTap: _handleContactSupport,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 24),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.support_agent_rounded,
                                                size: 24,
                                                color: isDark
                                                    ? Colors.grey[200]
                                                    : Colors.grey[700]),
                                            const SizedBox(width: 8),
                                            Text(
                                                localizations.translate(
                                                    'generic_error.button_contact'),
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark
                                                        ? Colors.grey[200]
                                                        : Colors.grey[700])),
                                          ])),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                localizations
                                    .translate('generic_error.resources_title'),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ResourceCard(
                            title: localizations.translate(
                                'generic_error.resource_system_status'),
                            subtitle: localizations.translate(
                                'generic_error.resource_system_status_desc'),
                            icon: Icons.dns_rounded,
                            iconColor: Colors.purple,
                            iconBgColor: const Color(0xFFFAF5FF), // Purple 50
                            iconBgColorDark:
                                Colors.purple[900]!.withOpacity(0.3),
                            onTap: _showSystemStatusModal,
                          ),
                          const SizedBox(height: 12),
                          _ResourceCard(
                            title: localizations.translate(
                                'generic_error.resource_troubleshoot'),
                            subtitle: localizations.translate(
                                'generic_error.resource_troubleshoot_desc'),
                            icon: Icons.help_outline_rounded,
                            iconColor: Colors.cyan,
                            iconBgColor: const Color(0xFFECFEFF), // Cyan 50
                            iconBgColorDark: Colors.cyan[900]!.withOpacity(0.3),
                            onTap: _showTroubleshootModal,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 16),
                  child: Text(
                    localizations.translate('generic_error.footer_code',
                        variables: {'code': widget.errorCode ?? '500-UNK'}),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                        fontFamily: 'Courier'), // Monospace hint
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget FadeTransition(
      {required Animation<double> opacity,
      required Animation<Offset> slideTransition,
      required Widget child}) {
    return AnimatedBuilder(
      animation: opacity,
      builder: (context, _) {
        return Opacity(
          opacity: opacity.value,
          child: Transform.translate(
            offset: slideTransition.value * 100, // amplify offset
            child: child,
          ),
        );
      },
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassPanel(
      {required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.6)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : const Color.fromRGBO(31, 38, 135, 0.07),
                  blurRadius: 32,
                  offset: const Offset(0, 8))
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  const _GlassButton(
      {required this.child,
      required this.onTap,
      this.width,
      this.height,
      this.padding = const EdgeInsets.all(12)});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBgColorDark;
  final VoidCallback onTap;
  const _ResourceCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.iconColor,
      required this.iconBgColor,
      required this.iconBgColorDark,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: isDark ? iconBgColorDark : iconBgColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon,
                  color: isDark ? iconColor.withOpacity(0.8) : iconColor,
                  size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey[900])),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
