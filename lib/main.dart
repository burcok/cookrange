import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/language_provider.dart';
import 'providers/onboarding_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize Hive
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    await Hive.openBox('appBox');
    await Hive.openBox('userBox');
    await Hive.openBox('settingsBox');
    await Hive.openBox<Map<dynamic, Object>>('analytics_cache');

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
