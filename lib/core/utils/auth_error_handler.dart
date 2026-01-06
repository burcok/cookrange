import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';

class AuthErrorHandler {
  static String getErrorMessage(BuildContext context, AuthException e) {
    final localizations = AppLocalizations.of(context);

    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-email':
      case 'invalid-credential':
        return localizations.translate('auth.login_errors.invalid_credentials');
      case 'email-already-in-use':
        return localizations
            .translate('auth.register_errors.email_already_in_use');
      case 'weak-password':
        return localizations.translate('auth.register_errors.weak_password');
      case 'network-error':
      case 'network-request-failed':
        return localizations.translate('auth.login_errors.network_error');
      case 'too-many-requests':
        return localizations.translate('auth.login_errors.too_many_requests');
      case 'user-disabled':
        return localizations.translate('auth.login_errors.user_disabled');
      case 'empty-fields':
        return localizations.translate('auth.login_errors.empty_fields');
      case 'type-error':
        return localizations.translate('auth.login_errors.type_error');
      default:
        return localizations.translate('auth.login_errors.unexpected_error');
    }
  }

  static void showSnackBar(BuildContext context, AuthException e) {
    final message = getErrorMessage(context, e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
