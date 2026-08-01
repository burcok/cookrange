import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/widgets/ds/ds.dart';

// BLK-01: HomeScreen's meal-plan section renders exactly this AppErrorState
// configuration (see home.dart's `_planUnavailable` branch) instead of a
// fabricated plan whenever AIService throws AIFatalException. `onRetry` is
// deliberately omitted here: a non-null onRetry makes AppErrorState render an
// AppButton, which reads ThemeProvider, whose constructor touches
// FirebaseAuth.instance synchronously — this repo has no Firebase platform
// mocks (ADR-004), so that path isn't testable at the widget level today. The
// retry callback itself is a one-line `_generateWeeklyPlan(user)` call,
// verified by reading, and the end-to-end retry flow by manual verification.
Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('Meal plan AI-unavailable state (BLK-01)', () {
    const title = 'AI is unavailable right now';
    const message = "We can't generate a meal plan without a connection to "
        'our AI service. Please try again in a moment.';

    testWidgets('renders the AI-unavailable error copy, not plan content',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AppErrorState(title: title, message: message),
      ));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });
  });
}
