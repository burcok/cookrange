import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/language_provider.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/app_initialization_service.dart';
import 'core/services/provider_initialization_service.dart';
import 'core/services/route_configuration_service.dart';
import 'core/services/screen_util_service.dart';
import 'core/widgets/error_fallback_widget.dart';

Future<void> main() async {
  // Initialize the app with comprehensive error handling
  final initService = AppInitializationService();
  final result = await initService.initialize();

  if (result.isSuccess) {
    runApp(MyApp());
  } else {
    // Run app with error fallback
    runApp(ErrorApp(error: result.error));
  }
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
    _appLifecycleService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLifecycleService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes if needed
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ..._providerService.createChangeNotifierProviders(),
        ..._providerService.createFirebaseProviders(),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return _screenUtilService.configureScreenUtil(
            child: MaterialApp(
              title: 'Cookrange',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.system,
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

/// Error app that shows when initialization fails
class ErrorApp extends StatelessWidget {
  final String? error;

  const ErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookrange - Error',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('en'), // Default to English for error screen
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ErrorFallbackWidget(
        error: error,
        onRetry: () async {
          // Properly re-initialize before restarting
          await AppInitializationService().initialize();
          runApp(const MyApp());
        },
      ),
    );
  }
}
