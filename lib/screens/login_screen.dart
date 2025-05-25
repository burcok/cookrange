import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../core/localization/app_localizations.dart';
import '../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

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

  Future<void> _login(BuildContext context) async {
    if (_isLoading) return; // Prevent multiple login attempts

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate inputs before making the API call
      if (_emailController.text.trim().isEmpty ||
          _passwordController.text.trim().isEmpty) {
        throw Exception('empty-fields');
      }

      await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushNamed(context, "/home");
      }
    } on Exception catch (e) {
      if (!mounted) return;

      String msg;
      print(e.toString().trim() == 'invalid-email');
      print(e.toString());
      switch (e.toString()) {
        case 'empty-fields':
          msg = AppLocalizations.of(context).translate('auth.empty_fields');
          break;
        case 'user-not-found' || 'wrong-password' || 'invalid-email':
          msg = AppLocalizations.of(context)
              .translate('auth.invalid_credentials');
          break;
        case 'network-error':
          msg = AppLocalizations.of(context).translate('auth.network_error');
          break;
        default:
          msg = AppLocalizations.of(context).translate('auth.login_error');
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
      await AuthService().signInWithGoogle();
      Navigator.pushNamed(context, "/home");
    } on Exception catch (e) {
      final msg =
          AppLocalizations.of(context).translate('auth.google_login_error');
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
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).maybePop();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              colorScheme.onboardingTitleColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onboardingTitleColor,
                        size: 24,
                      ),
                    ),
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
                  localizations.translate('auth.welcome_back'),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, "/forgot_password");
                    },
                    child: Text(localizations.translate('auth.forgot_password'),
                        style: TextStyle(
                            color: colorScheme.schemaPreferredColor,
                            decoration: TextDecoration.underline)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _login(context),
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
                      : Text(localizations.translate('auth.login'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _loginWithGoogle(context),
                  icon: Image.asset('assets/icons/google.png', height: 24),
                  label: Text(localizations.translate('auth.login_with_google'),
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
                    Text(localizations.translate('auth.no_account')),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/register");
                      },
                      child: Text(localizations.translate('auth.register_now'),
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
