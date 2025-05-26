import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/onboarding_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home.dart';
import 'screens/auth/verify_email.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Hive with proper error handling
    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);

      // Register adapters if needed
      // Hive.registerAdapter(YourAdapter());

      // Open boxes with error handling and ensure they're not already open
      await Future.wait([
        Hive.isBoxOpen('appBox')
            ? Future.value(Hive.box('appBox'))
            : Hive.openBox('appBox'),
        Hive.isBoxOpen('userBox')
            ? Future.value(Hive.box('userBox'))
            : Hive.openBox('userBox'),
        Hive.isBoxOpen('settingsBox')
            ? Future.value(Hive.box('settingsBox'))
            : Hive.openBox('settingsBox'),
        Hive.isBoxOpen('analytics_cache')
            ? Future.value(Hive.box<Map<dynamic, Object>>('analytics_cache'))
            : Hive.openBox<Map<dynamic, Object>>('analytics_cache'),
      ]);
    } catch (e) {
      print('Error initializing Hive: $e');
      // Continue app execution even if Hive fails
    }

    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    // Configure system UI
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    runApp(const MyApp());
  } catch (e, stack) {
    print('Fatal error in main: $e');
    print('Stack trace: $stack');
    // Show error UI or handle fatal error appropriately
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        Provider<FirebaseAnalytics>.value(value: FirebaseAnalytics.instance),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                title: 'Cookrange',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.system,
                home: const SplashScreen(),
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/verify_email': (context) => const VerifyEmailScreen(),
                  '/onboarding': (context) => const OnboardingScreen(),
                  // Diğer authentication ekranları buraya eklenecek
                },
                navigatorObservers: [
                  FirebaseAnalyticsObserver(
                      analytics: FirebaseAnalytics.instance),
                ],
                locale: languageProvider.currentLocale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.0)),
                    child: child!,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

const defaultInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  borderSide: BorderSide(color: Color(0xFFDEE3F2), width: 1),
);
