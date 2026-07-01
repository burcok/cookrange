import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App environment flag from `.env` (`APP_ENV=development|production`).
///
/// IMPORTANT — this is informational/convenience only. The security-critical
/// CLIENT gates (App Check provider selection, blocking the bundled AI key in
/// release) deliberately use [kReleaseMode] — the compiled build mode — which
/// cannot be flipped by editing a bundled `.env` in a repackaged build. The
/// authoritative enforcement of production-only requirements (App Check
/// enforcement, store-purchase validation) lives SERVER-SIDE in `functions/`
/// (its own `APP_ENV`). Do not gate a security decision on this flag alone.
class AppEnv {
  AppEnv._();

  /// The configured environment name; defaults to `development` when unset.
  static String get name {
    final v = (dotenv.maybeGet('APP_ENV') ?? 'development').trim().toLowerCase();
    return v.isEmpty ? 'development' : v;
  }

  /// True only when `APP_ENV=production` AND this is a release build — so a
  /// tampered debug build can never masquerade as production.
  static bool get isProduction => name == 'production' && kReleaseMode;

  /// True for any non-production environment.
  static bool get isDevelopment => !isProduction;
}
