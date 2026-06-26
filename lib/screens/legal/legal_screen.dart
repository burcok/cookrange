import 'package:flutter/material.dart';

enum LegalDocumentType { privacyPolicy, termsOfUse }

class LegalScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = type == LegalDocumentType.privacyPolicy
        ? 'Privacy Policy'
        : 'Terms of Use';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFFDFDFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: DefaultTextStyle(
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 14,
            height: 1.6,
            fontFamily: 'Poppins',
          ),
          child: type == LegalDocumentType.privacyPolicy
              ? _buildPrivacyPolicy()
              : _buildTermsOfUse(),
        ),
      ),
    );
  }

  Widget _buildSection(String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    const lastUpdated = 'Last updated: June 2026';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(lastUpdated,
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        _buildSection(
          '1. Information We Collect',
          'We collect information you provide when creating an account, such as your name, email address, and profile photo. We also collect data about your use of the app, including meal plans, food logs, and nutritional preferences.',
        ),
        _buildSection(
          '2. How We Use Your Information',
          'We use your information to provide personalised meal plans and nutrition tracking, improve our AI recommendations, send push notifications you have opted into, and maintain account security.',
        ),
        _buildSection(
          '3. Data Storage',
          'Your data is stored securely using Firebase (Google Cloud). Profile photos and post images are stored in Firebase Storage. Authentication is managed by Firebase Authentication.',
        ),
        _buildSection(
          '4. Third-Party Services',
          'We use the following third-party services: Firebase (Google) for authentication and data storage, OpenRouter for AI-powered meal recommendations. These services have their own privacy policies.',
        ),
        _buildSection(
          '5. Data Sharing',
          'We do not sell your personal data. Community posts you create are visible to other authenticated users. Your personal nutrition data is private and visible only to you.',
        ),
        _buildSection(
          '6. Data Retention and Deletion',
          'You can delete your account and all associated data at any time from Settings > Account > Delete Account. Upon deletion, all personal data is permanently removed from our systems within 30 days.',
        ),
        _buildSection(
          '7. Children\'s Privacy',
          'Cookrange is not intended for children under 13. We do not knowingly collect personal information from children under 13.',
        ),
        _buildSection(
          '8. Changes to This Policy',
          'We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or via email.',
        ),
        _buildSection(
          '9. Contact',
          'If you have questions about this Privacy Policy, please contact us at privacy@cookrange.app.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTermsOfUse() {
    const lastUpdated = 'Last updated: June 2026';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(lastUpdated,
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        _buildSection(
          '1. Acceptance of Terms',
          'By using Cookrange, you agree to these Terms of Use. If you do not agree, please do not use the app.',
        ),
        _buildSection(
          '2. Account Responsibilities',
          'You are responsible for maintaining the confidentiality of your account credentials and for all activity that occurs under your account. You must notify us immediately of any unauthorised use.',
        ),
        _buildSection(
          '3. Acceptable Use',
          'You agree not to: post content that is harmful, offensive, or misleading; impersonate other users; attempt to access other users\' data; use the app for any illegal purpose; or interfere with the app\'s functionality.',
        ),
        _buildSection(
          '4. User Content',
          'You retain ownership of content you post (photos, recipes, posts). By posting content, you grant Cookrange a licence to display it within the app. You are responsible for ensuring your content does not infringe third-party rights.',
        ),
        _buildSection(
          '5. AI-Generated Meal Plans',
          'Meal plans and nutritional information generated by our AI are for informational purposes only and do not constitute medical or dietary advice. Consult a qualified professional before making significant dietary changes.',
        ),
        _buildSection(
          '6. Nutritional Information',
          'Nutritional data provided in the app is estimated and may vary. We make no warranty as to the accuracy of nutritional information. Always verify with original product labels.',
        ),
        _buildSection(
          '7. Intellectual Property',
          'The Cookrange name, logo, and app design are our intellectual property. You may not reproduce or distribute them without our written permission.',
        ),
        _buildSection(
          '8. Termination',
          'We reserve the right to suspend or terminate accounts that violate these terms, at our discretion and without notice.',
        ),
        _buildSection(
          '9. Limitation of Liability',
          'Cookrange is provided "as is" without warranties of any kind. We are not liable for any indirect, incidental, or consequential damages arising from your use of the app.',
        ),
        _buildSection(
          '10. Changes to Terms',
          'We may update these Terms at any time. Continued use of the app after changes constitutes acceptance of the new Terms.',
        ),
        _buildSection(
          '11. Contact',
          'Questions about these Terms? Contact us at legal@cookrange.app.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
