import 'package:cloud_firestore/cloud_firestore.dart';
import 'log_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Enum for Admin Status Check Result
enum AdminStatus {
  ok,
  maintenance,
  updateRequired,
  banned,
  error,
}

/// Service to handle global admin status checks (Maintenance, Bans, Versions)
class AdminStatusService {
  static final AdminStatusService _instance = AdminStatusService._internal();
  factory AdminStatusService() => _instance;
  AdminStatusService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'AdminStatusService';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache settings to avoid excessive reads
  Map<String, dynamic>? _remoteConfigCache;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Main method to check all status conditions
  Future<AdminStatus> checkStatus(String? userId) async {
    try {
      // 1. Fetch Remote Config (mocked or from Firestore 'settings/global')
      final config = await _getGlobalConfig();

      // 2. Check Maintenance Mode
      if (config['maintenance_mode'] == true) {
        _log.warning('App is in maintenance mode', service: _serviceName);
        return AdminStatus.maintenance;
      }

      // 3. Check Minimum Version
      final minVersion = config['min_version'] as String?;
      if (minVersion != null && await _isUpdateRequired(minVersion)) {
        _log.warning('App update required. Min: $minVersion',
            service: _serviceName);
        return AdminStatus.updateRequired;
      }

      // 4. Check User Ban Status (if logged in)
      if (userId != null) {
        final isBanned = await _checkIfUserBanned(userId);
        if (isBanned) {
          _log.warning('User $userId is banned', service: _serviceName);
          return AdminStatus.banned;
        }
      }

      return AdminStatus.ok;
    } catch (e) {
      _log.error('Error checking admin status',
          service: _serviceName, error: e);
      // Fail open (allow access) on error, or fail closed depending on security requirement
      // For now, let's treat error as OK to prevent blocking users due to network glitches
      return AdminStatus.ok;
    }
  }

  Future<Map<String, dynamic>> _getGlobalConfig() async {
    // Cache check
    if (_remoteConfigCache != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _remoteConfigCache!;
    }

    try {
      final doc = await _firestore.collection('settings').doc('global').get();
      if (doc.exists) {
        _remoteConfigCache = doc.data()!;
      } else {
        // Defaults if no config found
        _remoteConfigCache = {
          'maintenance_mode': false,
          'min_version': '1.0.0',
        };
      }
      _lastFetchTime = DateTime.now();
      return _remoteConfigCache!;
    } catch (e) {
      _log.error('Failed to fetch global config',
          service: _serviceName, error: e);
      return {
        'maintenance_mode': false,
        'min_version': '1.0.0',
      };
    }
  }

  Future<bool> _isUpdateRequired(String minVersion) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    return _compareVersions(currentVersion, minVersion) < 0;
  }

  int _compareVersions(String v1, String v2) {
    try {
      List<int> v1Parts = v1.split('.').map(int.parse).toList();
      List<int> v2Parts = v2.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        int part1 = i < v1Parts.length ? v1Parts[i] : 0;
        int part2 = i < v2Parts.length ? v2Parts[i] : 0;
        if (part1 < part2) return -1;
        if (part1 > part2) return 1;
      }
      return 0;
    } catch (e) {
      return 0; // Assume equal if parse fails
    }
  }

  Future<bool> _checkIfUserBanned(String userId) async {
    try {
      // Check specific 'banned_users' collection OR a field on the user doc
      // Strategy: Field on user doc is faster usually since we likely already have it,
      // but a separate collection is cleaner for admin logic.
      // Let's check a 'banned' field in standard user doc for simplicity/performance combo
      // assuming we might have it cached or we fetch it.
      // Or we can check a separate 'suspensions' collection.

      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['is_banned'] == true;
    } catch (e) {
      _log.error('Error checking user ban status',
          service: _serviceName, error: e);
      return false;
    }
  }
}
