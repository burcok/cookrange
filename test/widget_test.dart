import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/widgets/error_fallback_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('ErrorFallbackWidget', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorFallbackWidget(onRetry: null, showRetryButton: false),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorFallbackWidget), findsOneWidget);
    });

    testWidgets('shows error_outline icon by default', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorFallbackWidget(showRetryButton: false),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows custom icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorFallbackWidget(
          showRetryButton: false,
          customIcon: Icon(Icons.cloud_off, key: Key('custom_icon')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom_icon')), findsOneWidget);
    });

    testWidgets('shows retry button when showRetryButton is true', (tester) async {
      await tester.pumpWidget(_wrap(
        ErrorFallbackWidget(showRetryButton: true, onRetry: () {}),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('hides retry button when showRetryButton is false', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorFallbackWidget(showRetryButton: false),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows custom title when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorFallbackWidget(
          showRetryButton: false,
          customTitle: 'Custom Error Title',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Custom Error Title'), findsOneWidget);
    });

    testWidgets('shows custom message when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorFallbackWidget(
          showRetryButton: false,
          customMessage: 'Something went wrong',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('retry button is tappable without crashing', (tester) async {
      await tester.pumpWidget(_wrap(
        ErrorFallbackWidget(showRetryButton: true, onRetry: () {}),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('UnknownRouteScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrap(const UnknownRouteScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(UnknownRouteScreen), findsOneWidget);
    });
  });
}
