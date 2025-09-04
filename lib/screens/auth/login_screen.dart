// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-load assets
    precacheImage(const AssetImage('assets/icons/google.png'), context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => _passwordError = null);
      return;
    }
    final localizations = AppLocalizations.of(context);

    if (password.length < 8) {
      setState(() => _passwordError =
          localizations.translate('auth.error.password_length'));
    } else if (!password.contains(RegExp(r'[0-9]'))) {
      setState(() => _passwordError =
          localizations.translate('auth.error.password_digit'));
    } else {
      setState(() => _passwordError = null);
    }
  }

  Future<void> _login(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw AuthException('empty-fields');
      }

      final user = await AuthService().signInWithEmail(email, password);

      if (!mounted) return;

      if (user != null) {
        try {
          if (!user.emailVerified) {
            await AuthService().sendEmailVerification();

            Navigator.pushNamedAndRemoveUntil(
              context,
              "/verify_email",
              (route) => false,
            );
            return;
          }
        } catch (e) {
          print("Error sending email verification: $e");
        }

        // Check user's onboarding status from Firestore
        final userModel = await AuthService().getUserData(user.uid);
        final bool onboardingCompleted =
            userModel?.onboardingCompleted ?? false;

        if (mounted) {
          if (onboardingCompleted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
          } else {
            Navigator.pushNamedAndRemoveUntil(
                context, '/onboarding', (route) => false);
          }
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-email':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.invalid_credentials');
          break;
        case 'network-error':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.network_error');
          break;
        case 'empty-fields':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.empty_fields');
          break;
        case 'type-error':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.type_error');
          break;
        case 'user-disabled':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.user_disabled');
          break;
        case 'too-many-requests':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.too_many_requests');
          break;
        default:
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.login_error');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      print("Unexpected error during login: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('auth.login_errors.unexpected_error'),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        final currentUser = AuthService().currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          // If email is not verified, navigate to verification screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            "/verify_email",
            (route) => false,
          );
          return;
        }

        // Check user's onboarding status from Firestore
        final userModel = await AuthService().getUserData(user.uid);
        final bool onboardingCompleted =
            userModel?.onboardingCompleted ?? false;

        if (mounted) {
          if (onboardingCompleted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
          } else {
            Navigator.pushNamedAndRemoveUntil(
                context, '/onboarding', (route) => false);
          }
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      print("Error during login with Google: $e");
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-email':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.invalid_credentials');
          break;
        case 'network-error':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.network_error');
          break;
        case 'empty-fields':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.empty_fields');
          break;
        case 'type-error':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.type_error');
          break;
        case 'too-many-requests':
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.too_many_requests');
          break;
        default:
          msg = AppLocalizations.of(context)
              .translate('auth.login_errors.login_error');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      print("Unexpected error during login: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('auth.login_errors.unexpected_error'),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.backgroundColor2,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Text(
                  'cookrange',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('auth.welcome_back'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onboardingSubtitleColor,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  localizations.translate('auth.email'),
                  style: TextStyle(
                      color: colorScheme.onboardingTitleColor,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  cursorColor: primaryColor,
                  decoration: InputDecoration(
                    hintText: localizations.translate('auth.email_hint'),
                    hintStyle: const TextStyle(color: authSecondaryTextColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.5), width: 2.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 2.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  localizations.translate('auth.password'),
                  style: TextStyle(
                      color: colorScheme.onboardingTitleColor,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  cursorColor: primaryColor,
                  onChanged: _validatePassword,
                  decoration: InputDecoration(
                    errorText: _passwordError,
                    hintText: '********',
                    hintStyle:
                        TextStyle(color: colorScheme.onboardingSubtitleColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.5), width: 2.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 2.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: authSecondaryTextColor),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, "/forgot_password");
                    },
                    child: Text(localizations.translate('auth.forgot_password'),
                        style: TextStyle(
                          color: colorScheme.onboardingTitleColor,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        )),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _login(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(localizations.translate('auth.login'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: authSecondaryTextColor.withOpacity(0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        localizations.translate('auth.or_divider'),
                        style: TextStyle(color: authSecondaryTextColor),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: authSecondaryTextColor.withOpacity(0.5))),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _loginWithGoogle(context),
                  icon: Image.asset('assets/icons/google.png', height: 24),
                  label: Text(localizations.translate('auth.login_with_google'),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(localizations.translate('auth.no_account'),
                        style: TextStyle(
                            color: colorScheme.onboardingSubtitleColor,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400)),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/register");
                      },
                      child: Text(localizations.translate('auth.register_now'),
                          style: TextStyle(
                            color: colorScheme.onboardingTitleColor,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            decoration: TextDecoration.underline,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
