import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../localization/app_localizations.dart';
import '../services/crashlytics_service.dart';
import '../../screens/common/generic_error_screen.dart';

class ErrorFallbackWidget extends StatefulWidget {
  final String? error;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final String? customTitle;
  final String? customMessage;
  final Widget? customIcon;

  const ErrorFallbackWidget({
    super.key,
    this.error,
    this.onRetry,
    this.showRetryButton = true,
    this.customTitle,
    this.customMessage,
    this.customIcon,
  });

  @override
  State<ErrorFallbackWidget> createState() => _ErrorFallbackWidgetState();
}

class _ErrorFallbackWidgetState extends State<ErrorFallbackWidget> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.maybeOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: widget.customIcon ??
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: theme.colorScheme.error,
                    ),
              ),
              const SizedBox(height: 32),
              Text(
                widget.customTitle ??
                    (localizations
                            ?.translate('error.initialization_failed_title') ??
                        'Initialization Failed'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.customMessage ??
                    (localizations?.translate(
                            'error.initialization_failed_message') ??
                        'An error occurred during app startup.'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.error != null && kDebugMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (widget.showRetryButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _handleRetry,
                    icon: _isRetrying
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isRetrying
                          ? (localizations?.translate('common.retrying') ??
                              'Retrying...')
                          : (localizations?.translate('common.retry') ??
                              'Retry'),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      try {
        await CrashlyticsService()
            .log('User initiated retry from error screen');
      } catch (_) {}
      if (widget.onRetry != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onRetry!();
      }
    } catch (e) {
      try {
        await CrashlyticsService().recordError(
          e,
          StackTrace.current,
          reason: 'Retry failed from error screen',
        );
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }
}

class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GenericErrorScreen(errorCode: '404');
  }
}
