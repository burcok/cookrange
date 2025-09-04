// ignore_for_file: use_build_context_synchronously

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordAgain = true;
  bool _isLoading = false;
  bool _agreementsAccepted = false;
  String? _emailError;
  String? _passwordError;
  String? _passwordAgainError;

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
    _passwordAgainController.dispose();
    super.dispose();
  }

  void _validateEmail(String email) {
    if (email.isEmpty) {
      setState(() => _emailError = null);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError =
          AppLocalizations.of(context).translate('auth.error.invalid_email'));
    } else {
      setState(() => _emailError = null);
    }
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
    _validatePasswordAgain(_passwordAgainController.text);
  }

  void _validatePasswordAgain(String passwordAgain) {
    if (passwordAgain.isEmpty) {
      setState(() => _passwordAgainError = null);
      return;
    }

    if (_passwordController.text != passwordAgain) {
      setState(() => _passwordAgainError = AppLocalizations.of(context)
          .translate('auth.error.passwords_do_not_match'));
    } else {
      setState(() => _passwordAgainError = null);
    }
  }

  bool _isFormValid() {
    return _emailError == null &&
        _passwordError == null &&
        _passwordAgainError == null &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _passwordAgainController.text.isNotEmpty &&
        _agreementsAccepted;
  }

  Future<void> _register(BuildContext context) async {
    if (_isLoading || !_isFormValid()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // After registration, user needs to verify their email
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/verify_email',
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      String msg;
      print("Auth error code: ${e.code}");

      switch (e.code) {
        case 'email-already-in-use':
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.email_already_in_use');
          break;
        case 'invalid-email':
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.invalid_email');
          break;
        case 'weak-password':
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.weak_password');
          break;
        case 'network-error':
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.network_error');
          break;
        case 'user-not-found':
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.user_not_found');
          break;
        case 'type-error':
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.type_error');
          break;
        default:
          msg = AppLocalizations.of(context)
              .translate('auth.register_errors.register_error');
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
      print("Unexpected error during registration: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('auth.register_errors.register_error'),
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

  Future<void> _registerWithGoogle(BuildContext context) async {
    if (!_agreementsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('auth.error.accept_agreements'),
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
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        final currentUser = AuthService().currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          // After registration, user needs to verify their email
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/verify_email',
            (route) => false,
          );
          return;
        }

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
    } on Exception catch (e) {
      if (!mounted) return;

      print("Error during registration with Google: $e");
      final msg =
          AppLocalizations.of(context).translate('auth.google_register_error');
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
      print("Unexpected error during registration with Google: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAgreement(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('common.close')),
          ),
        ],
      ),
    );
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
                  localizations.translate('auth.create_account'),
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
                  onChanged: _validateEmail,
                  decoration: InputDecoration(
                    errorText: _emailError,
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
                const SizedBox(height: 24),
                Text(
                  localizations.translate('auth.password_again'),
                  style: TextStyle(
                      color: colorScheme.onboardingTitleColor,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordAgainController,
                  obscureText: _obscurePasswordAgain,
                  cursorColor: primaryColor,
                  onChanged: _validatePasswordAgain,
                  decoration: InputDecoration(
                    errorText: _passwordAgainError,
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
                          _obscurePasswordAgain
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: authSecondaryTextColor),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordAgain = !_obscurePasswordAgain;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreementsAccepted,
                      onChanged: (value) {
                        setState(() {
                          _agreementsAccepted = value ?? false;
                        });
                      },
                      activeColor: primaryColor,
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onboardingTitleColor,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                                text: localizations
                                    .translate('auth.agreements.prefix')),
                            TextSpan(
                              text: localizations
                                  .translate('auth.agreements.privacy_policy'),
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _showAgreement(
                                      context,
                                      localizations.translate(
                                          'auth.agreements.privacy_policy'),
                                      'Buraya gizlilik sözleşmesi metni gelecek...',
                                    ),
                            ),
                            TextSpan(
                                text: localizations
                                    .translate('auth.agreements.and')),
                            TextSpan(
                              text: localizations
                                  .translate('auth.agreements.terms_of_use'),
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _showAgreement(
                                      context,
                                      localizations.translate(
                                          'auth.agreements.terms_of_use'),
                                      'Buraya kullanım şartları metni gelecek...',
                                    ),
                            ),
                            TextSpan(
                                text: localizations
                                    .translate('auth.agreements.suffix')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading || !_isFormValid()
                      ? null
                      : () => _register(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(localizations.translate('auth.register'),
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
                      _isLoading ? null : () => _registerWithGoogle(context),
                  icon: Image.asset('assets/icons/google.png', height: 24),
                  label: Text(
                      localizations.translate('auth.register_with_google'),
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
                    Text(localizations.translate('auth.already_have_account'),
                        style: TextStyle(
                            color: colorScheme.onboardingSubtitleColor,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400)),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/login");
                      },
                      child: Text(localizations.translate('auth.login_now'),
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
