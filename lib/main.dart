import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/provider_initialization_service.dart';
import 'core/services/route_configuration_service.dart';
import 'core/services/screen_util_service.dart';
import 'core/services/auth_service.dart';

/// PERFORMANCE OPTIMIZATION: main() initializes Firebase (required for providers)
/// but backgrounds the rest of the heavy setup (dotenv, AI, Hive, Analytics Detailed)
/// to the SplashScreen for a smooth animated transition.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() is a hard requirement for many providers and services.
  // We initialize it here to prevent "[core/no-app]" errors, but we keep it minimal.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AppLifecycleService _appLifecycleService = AppLifecycleService();
  final ProviderInitializationService _providerService =
      ProviderInitializationService();
  final RouteConfigurationService _routeService = RouteConfigurationService();
  final ScreenUtilService _screenUtilService = ScreenUtilService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLifecycleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ..._providerService.createChangeNotifierProviders(),
        ..._providerService.createFirebaseProviders(),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          return _screenUtilService.configureScreenUtil(
            child: MaterialApp(
              navigatorKey: AuthService().navigatorKey,
              title: 'Cookrange',
              debugShowCheckedModeBanner: false,
              theme:
                  AppTheme.lightTheme(primaryColor: themeProvider.primaryColor),
              darkTheme:
                  AppTheme.darkTheme(primaryColor: themeProvider.primaryColor),
              themeMode: themeProvider.themeMode,
              initialRoute: _routeService.initialRoute,
              routes: _routeService.getRoutes(),
              onUnknownRoute: _routeService.onUnknownRoute,
              navigatorObservers: _routeService.getNavigatorObservers(),
              locale: languageProvider.currentLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                return MediaQuery(
                  data: _screenUtilService.createResponsiveMediaQuery(context),
                  child: child!,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
