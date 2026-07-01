import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Schemes we will ever hand to the OS launcher. Anything else
/// (`javascript:`, `file:`, `intent:`, `data:`, custom app schemes) is rejected
/// to prevent open-redirect / scheme-confusion when the URL is attacker- or
/// user-controlled (e.g. applicant documents, profile links, AI output).
const Set<String> _kAllowedSchemes = {'https', 'mailto', 'tel'};

/// Launches [rawUrl] only if it parses and uses an allowlisted scheme.
///
/// Pass [allowedHosts] (lower-case) to additionally require the URL point at a
/// trusted origin — use this for any link whose value comes from another user
/// or from storage (e.g. `{'firebasestorage.googleapis.com'}`).
///
/// Returns true if the URL was launched.
Future<bool> safeLaunchUrl(
  String? rawUrl, {
  Set<String>? allowedHosts,
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  if (rawUrl == null || rawUrl.trim().isEmpty) return false;
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !uri.hasScheme) return false;

  if (!_kAllowedSchemes.contains(uri.scheme.toLowerCase())) {
    debugPrint('safeLaunchUrl: blocked disallowed scheme "${uri.scheme}"');
    return false;
  }
  if (allowedHosts != null &&
      !allowedHosts.contains(uri.host.toLowerCase())) {
    debugPrint('safeLaunchUrl: blocked disallowed host "${uri.host}"');
    return false;
  }

  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri, mode: mode);
  } catch (e) {
    debugPrint('safeLaunchUrl: launch failed: $e');
    return false;
  }
}
