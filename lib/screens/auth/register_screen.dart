// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/onboarding_common_widgets.dart';
import 'package:flutter/gestures.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

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
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _passwordAgainController.addListener(_validatePasswordAgain);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icons/google.png'), context);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_validatePassword);
    _passwordAgainController.removeListener(_validatePasswordAgain);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordAgainController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = null);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Geçerli bir email adresi giriniz');
    } else {
      setState(() => _emailError = null);
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordError = null);
      return;
    }

    if (password.length < 8) {
      setState(() => _passwordError = 'Şifre en az 8 karakter olmalıdır');
    } else if (!password.contains(RegExp(r'[0-9]'))) {
      setState(() => _passwordError = 'Şifre en az bir rakam içermelidir');
    } else {
      setState(() => _passwordError = null);
    }

    // Şifre tekrarı kontrolünü de güncelle
    _validatePasswordAgain();
  }

  void _validatePasswordAgain() {
    final password = _passwordController.text;
    final passwordAgain = _passwordAgainController.text;

    if (passwordAgain.isEmpty) {
      setState(() => _passwordAgainError = null);
      return;
    }

    if (password != passwordAgain) {
      setState(() => _passwordAgainError = 'Şifreler eşleşmiyor');
    } else {
      setState(() => _passwordAgainError = null);
    }
  }

  bool _isFormValid() {
    return _emailError == null &&
        _passwordError == null &&
        _passwordAgainError == null &&
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
        if (!mounted) return;
        Navigator.pushNamed(context, "/home");
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
          duration: const Duration(seconds: 10),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          closeIconColor: Colors.white,
          showCloseIcon: true,
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
          duration: const Duration(seconds: 10),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          closeIconColor: Colors.white,
          showCloseIcon: true,
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
    if (!_isFormValid()) return;

    setState(() {
      _isLoading = true;
    });
    try {
      await AuthService().signInWithGoogle();
      Navigator.pushNamed(context, "/home");
    } on Exception catch (e) {
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
          duration: const Duration(seconds: 10),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          closeIconColor: Colors.white,
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            child: const Text('Kapat'),
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
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OnboardingBackButton(
                    onTap: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'cookrange',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.secondary,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('auth.create_account'),
                  style: TextStyle(
                    fontSize: 20,
                    color: colorScheme.onboardingSubtitleColor,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(localizations.translate('auth.email'),
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  cursorColor: colorScheme.secondary,
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    alignLabelWithHint: true,
                    hintFadeDuration: const Duration(milliseconds: 100),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide(
                        color: colorScheme.secondary.withOpacity(0.2),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide(
                        color: colorScheme.secondary,
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    errorText: _emailError,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                Text(localizations.translate('auth.password'),
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  cursorColor: colorScheme.secondary,
                  decoration: InputDecoration(
                    hintText: '********',
                    alignLabelWithHint: true,
                    hintFadeDuration: const Duration(milliseconds: 100),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide(
                        color: colorScheme.secondary.withOpacity(0.2),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide(
                        color: colorScheme.secondary,
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    errorText: _passwordError,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(localizations.translate('auth.password_again'),
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordAgainController,
                  obscureText: _obscurePasswordAgain,
                  cursorColor: colorScheme.secondary,
                  decoration: InputDecoration(
                    hintText: '********',
                    alignLabelWithHint: true,
                    hintFadeDuration: const Duration(milliseconds: 100),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide(
                        color: colorScheme.secondary.withOpacity(0.2),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide(
                        color: colorScheme.secondary,
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    errorText: _passwordAgainError,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePasswordAgain
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordAgain = !_obscurePasswordAgain;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreementsAccepted,
                      onChanged: (value) {
                        setState(() {
                          _agreementsAccepted = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onboardingTitleColor,
                            fontFamily: 'Poppins',
                            fontSize: 15,
                          ),
                          children: [
                            const TextSpan(
                                text: 'Hesap oluşturarak, Cookrange '),
                            TextSpan(
                              text: 'Gizlilik Sözleşmesi',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _showAgreement(
                                      context,
                                      'Gizlilik Sözleşmesi',
                                      'Buraya gizlilik sözleşmesi metni gelecek...',
                                    ),
                            ),
                            const TextSpan(text: ' ve '),
                            TextSpan(
                              text: 'Kullanım Şartları',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _showAgreement(
                                      context,
                                      'Kullanım Şartları',
                                      'Buraya kullanım şartları metni gelecek...',
                                    ),
                            ),
                            const TextSpan(text: "'nı kabul etmiş sayılırsın."),
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
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(localizations.translate('auth.signup'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading || !_isFormValid()
                      ? null
                      : () => _registerWithGoogle(context),
                  icon: Image.asset('assets/icons/google.png', height: 24),
                  label: Text(
                      localizations.translate('auth.register_with_google'),
                      style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(localizations.translate('auth.already_have_account')),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/login");
                      },
                      child: Text(localizations.translate('auth.login_now'),
                          style: TextStyle(
                            color: colorScheme.schemaPreferredColor,
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
