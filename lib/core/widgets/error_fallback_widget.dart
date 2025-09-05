import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../localization/app_localizations.dart';
import '../services/crashlytics_service.dart';

/// A comprehensive error fallback widget that provides user-friendly error handling
/// with retry options and offline mode support.
class ErrorFallbackWidget extends StatefulWidget {
  final String? error;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final String? customTitle;
  final String? customMessage;
  final Widget? customIcon;
  final bool isOfflineMode;

  const ErrorFallbackWidget({
    super.key,
    this.error,
    this.onRetry,
    this.showRetryButton = true,
    this.customTitle,
    this.customMessage,
    this.customIcon,
    this.isOfflineMode = false,
  });

  @override
  State<ErrorFallbackWidget> createState() => _ErrorFallbackWidgetState();
}

class _ErrorFallbackWidgetState extends State<ErrorFallbackWidget> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: widget.customIcon ?? Icon(
                  widget.isOfflineMode ? Icons.wifi_off : Icons.error_outline,
                  size: 60,
                  color: theme.colorScheme.error,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Error Title
              Text(
                widget.customTitle ?? _getErrorTitle(localizations),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Error Message
              Text(
                widget.customMessage ?? _getErrorMessage(localizations),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              if (widget.error != null && kDebugMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.3),
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
              
              // Action Buttons
              if (widget.showRetryButton) ...[
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
                          ? localizations.translate('common.retrying')
                          : localizations.translate('common.retry'),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
              
              // Offline Mode Button
              if (widget.isOfflineMode)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleOfflineMode,
                    icon: const Icon(Icons.offline_bolt),
                    label: Text(localizations.translate('common.continue_offline')),
                    style: OutlinedButton.styleFrom(
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

  String _getErrorTitle(AppLocalizations localizations) {
    if (widget.isOfflineMode) {
      return localizations.translate('error.offline_title');
    }
    return localizations.translate('error.initialization_failed_title');
  }

  String _getErrorMessage(AppLocalizations localizations) {
    if (widget.isOfflineMode) {
      return localizations.translate('error.offline_message');
    }
    return localizations.translate('error.initialization_failed_message');
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      // Log retry attempt
      await CrashlyticsService().log('User initiated retry from error screen');
      
      // Call the retry callback
      if (widget.onRetry != null) {
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UX
        widget.onRetry!();
      }
    } catch (e) {
      // Log retry failure
      await CrashlyticsService().recordError(
        e,
        StackTrace.current,
        reason: 'Retry failed from error screen',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  void _handleOfflineMode() {
    // Navigate to offline mode or show offline functionality
    // This would typically involve setting a flag or navigating to a specific screen
    Navigator.of(context).pushReplacementNamed('/offline');
  }
}

/// A simple error screen for unknown routes
class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 404 Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 60,
                  color: theme.colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 404 Title
              Text(
                '404',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Page Not Found Message
              Text(
                localizations.translate('error.page_not_found'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                localizations.translate('error.page_not_found_message'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Go Home Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: Text(localizations.translate('common.go_home')),
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
}
