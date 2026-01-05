import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
// If needed for random ID generation

class AccountSuspendedScreen extends StatefulWidget {
  const AccountSuspendedScreen({super.key});

  @override
  State<AccountSuspendedScreen> createState() => _AccountSuspendedScreenState();
}

class _AccountSuspendedScreenState extends State<AccountSuspendedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  // Dynamic ID
  late String _caseId;

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

    // Generate dynamic ID based on date or user ID if available
    final userId =
        AuthService().currentUser?.uid.substring(0, 6).toUpperCase() ?? 'UNK';
    final year = DateTime.now().year;
    final month = DateTime.now().month;
    final day = DateTime.now().day;
    _caseId = '$userId-$year$month$day';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors from design
    final primaryColor = Theme.of(context).primaryColor;
    final bgLight = const Color(0xFFF8FAFC);
    final bgDark = const Color(0xFF0F172A);
    // Use app theme background if possible, but design specified these.
    // We will overlay on current scaffold background to be safe or use these.

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
                      // Back Button
                      _GlassButton(
                        onTap: _handleLogout,
                        width: 40,
                        height: 40,
                        padding: EdgeInsets.zero,
                        child: Icon(
                          Icons.arrow_back, // using standard back icon
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                      // Title
                      Text(
                        localizations
                            .translate('account_suspended.title_header'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 40), // Spacer
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
                        // Main Card
                        _GlassPanel(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              // Icon
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.red[900]!.withOpacity(0.2)
                                          : Colors.red[50],
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.gpp_bad_rounded,
                                      size: 48,
                                      color: isDark
                                          ? Colors.red[400]
                                          : Colors.red[500],
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
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.priority_high_rounded,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Title
                              Text(
                                localizations
                                    .translate('account_suspended.title_main'),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white : Colors.grey[900],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),

                              // Description (Rich Text for bolding)
                              _buildDescription(context, localizations, isDark),
                              const SizedBox(height: 32),

                              // Contact Support Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleContactSupport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    shadowColor: primaryColor.withOpacity(0.2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.support_agent_rounded,
                                          size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.translate(
                                            'account_suspended.button_contact'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Terms Button
                              SizedBox(
                                width: double.infinity,
                                child: _GlassButton(
                                  onTap: _showTermsModal,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 24),
                                  child: Center(
                                    child: Text(
                                      localizations.translate(
                                          'account_suspended.button_terms'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.grey[200]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Helpful Resources Header
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Row(
                              children: [
                                // Icon(Icons.help_outline, size: 20, color: isDark ? Colors.white : Colors.grey[900]),
                                // const SizedBox(width: 8),
                                Text(
                                  localizations.translate(
                                      'account_suspended.resources_title'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resources List
                        _ResourceCard(
                          title: localizations.translate(
                              'account_suspended.resource_community_rules'),
                          subtitle: localizations.translate(
                              'account_suspended.resource_community_rules_desc'),
                          icon: Icons.menu_book_rounded,
                          iconColor: const Color(0xFF3B82F6), // Blue
                          iconBgColor: const Color(0xFFEFF6FF), // Blue 50
                          iconBgColorDark:
                              const Color(0xFF1E3A8A).withOpacity(0.3),
                          onTap: _showGuidelinesModal,
                        ),
                        const SizedBox(height: 12),
                        _ResourceCard(
                          title: localizations
                              .translate('account_suspended.resource_appeal'),
                          subtitle: localizations.translate(
                              'account_suspended.resource_appeal_desc'),
                          icon: Icons.restore_rounded,
                          iconColor: const Color(0xFF10B981), // Emerald
                          iconBgColor: const Color(0xFFECFDF5), // Emerald 50
                          iconBgColorDark:
                              const Color(0xFF064E3B).withOpacity(0.3),
                          onTap: _showAppealModal,
                        ),
                      ],
                    ),
                  ),
                )),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 16),
                  child: Text(
                    localizations.translate('account_suspended.footer_id',
                        variables: {'id': _caseId}),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
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

  Future<void> _handleContactSupport() async {
    final localizations = AppLocalizations.of(context);
    final isTr = localizations.locale.languageCode == 'tr';
    final email = isTr ? 'destek@cookrange.com' : 'help@cookrange.com';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters(<String, String>{
        'subject': isTr
            ? 'Hesabım Askıya Alındı ($_caseId)'
            : 'Account Suspended ($_caseId)',
        'body': ''
      }),
    );

    if (!await launchUrl(emailLaunchUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not launch email client. Please contact $email')),
        );
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showTermsModal() {
    final localizations = AppLocalizations.of(context);
    _showGlassModal(
      title: localizations.translate('account_suspended.terms_modal.title'),
      content: Text(
        localizations.translate('account_suspended.terms_modal.content'),
        style: const TextStyle(height: 1.6),
      ),
      icon: Icons.gavel_rounded,
      color: Colors.blueGrey,
    );
  }

  void _showGuidelinesModal() {
    final localizations = AppLocalizations.of(context);
    _showGlassModal(
      title:
          localizations.translate('account_suspended.guidelines_modal.title'),
      content: Text(
        localizations.translate('account_suspended.guidelines_modal.content'),
        style: const TextStyle(height: 1.6),
      ),
      icon: Icons.menu_book_rounded,
      color: Colors.blue,
    );
  }

  void _showAppealModal() {
    final localizations = AppLocalizations.of(context);

    _showGlassModal(
        title: localizations.translate('account_suspended.appeal_modal.title'),
        icon: Icons.restore_rounded,
        color: const Color(0xFF10B981),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations
                  .translate('account_suspended.appeal_modal.subtitle'),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildAppealStep(
              context,
              '1',
              localizations
                  .translate('account_suspended.appeal_modal.step1_title'),
              localizations
                  .translate('account_suspended.appeal_modal.step1_desc'),
              isLast: false,
            ),
            _buildAppealStep(
              context,
              '2',
              localizations
                  .translate('account_suspended.appeal_modal.step2_title'),
              localizations
                  .translate('account_suspended.appeal_modal.step2_desc'),
              extraInfo: localizations
                  .translate('account_suspended.appeal_modal.step2_wait'),
              isLast: false,
            ),
            _buildAppealStep(
              context,
              '3',
              localizations
                  .translate('account_suspended.appeal_modal.step3_title'),
              localizations
                  .translate('account_suspended.appeal_modal.step3_desc'),
              isLast: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localizations
                          .translate('account_suspended.appeal_modal.note'),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          ],
        ));
  }

  Widget _buildAppealStep(
      BuildContext context, String number, String title, String desc,
      {bool isLast = false, String? extraInfo}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFFF0507F), // Primary
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFF0507F).withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ]),
                alignment: Alignment.center,
                child: Text(number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[900])),
                      if (extraInfo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blue[900]!.withOpacity(0.3)
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(extraInfo,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : Colors.blue[700],
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
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
            height: MediaQuery.of(context).size.height * 0.7,
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  // Helper to parse 'description' which contains HTML-like tags e.g. <bold>...</bold>
  // or {bold_start}...{bold_end} keys we added in JSON
  Widget _buildDescription(
      BuildContext context, AppLocalizations localizations, bool isDark) {
    final rawText = localizations.translate('account_suspended.description');

    // Simple parser for {bold_start} text {bold_end}
    final parts = rawText.split(RegExp(r'\{bold_start\}|\{bold_end\}'));
    // If format matches "Prefix {bold_start} Bold Part {bold_end} Suffix"
    // parts will be [Prefix, Bold Part, Suffix] (length 3)

    List<TextSpan> spans = [];

    if (parts.length >= 3) {
      spans.add(TextSpan(text: parts[0]));
      spans.add(TextSpan(
        text: parts[1],
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[200] : Colors.grey[800],
        ),
      ));
      spans.add(TextSpan(text: parts[2]));
    } else {
      spans.add(TextSpan(text: rawText));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: isDark ? Colors.grey[300] : Colors.grey[600],
          fontFamily:
              Theme.of(context).textTheme.bodyMedium?.fontFamily ?? 'Poppins',
        ),
        children: spans,
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
                  : Colors.white.withOpacity(0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : const Color.fromRGBO(31, 38, 135, 0.07),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
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
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: child, // Center handled by parent if needed, or child itself
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

  const _ResourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBgColorDark,
    required this.onTap,
  });

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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isDark ? iconColor.withOpacity(0.8) : iconColor,
                  size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
