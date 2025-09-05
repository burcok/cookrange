import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Service to manage ScreenUtil configuration and text scaling
class ScreenUtilService {
  static final ScreenUtilService _instance = ScreenUtilService._internal();
  factory ScreenUtilService() => _instance;
  ScreenUtilService._internal();

  /// Design size for the app
  static const Size designSize = Size(375, 812);

  /// Minimum text scale factor
  static const double minTextScale = 0.8;

  /// Maximum text scale factor
  static const double maxTextScale = 1.3;

  /// Configure ScreenUtil with optimal settings
  Widget configureScreenUtil({
    required Widget child,
    Size? customDesignSize,
    bool minTextAdapt = true,
    bool splitScreenMode = true,
  }) {
    return ScreenUtilInit(
      designSize: customDesignSize ?? designSize,
      minTextAdapt: minTextAdapt,
      splitScreenMode: splitScreenMode,
      builder: (context, child) => child!,
      child: child,
    );
  }

  /// Get responsive text scale factor
  double getTextScaleFactor(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final systemScale = mediaQuery.textScaler.scale(1.0);
    
    // Clamp the scale factor between min and max values
    return systemScale.clamp(minTextScale, maxTextScale);
  }

  /// Create responsive MediaQuery with proper text scaling
  MediaQueryData createResponsiveMediaQuery(BuildContext context) {
    final originalMediaQuery = MediaQuery.of(context);
    final textScaleFactor = getTextScaleFactor(context);
    
    return originalMediaQuery.copyWith(
      textScaler: TextScaler.linear(textScaleFactor),
    );
  }

  /// Get responsive font size
  double getResponsiveFontSize(double fontSize) {
    return fontSize.sp;
  }

  /// Get responsive width
  double getResponsiveWidth(double width) {
    return width.w;
  }

  /// Get responsive height
  double getResponsiveHeight(double height) {
    return height.h;
  }

  /// Get responsive radius
  double getResponsiveRadius(double radius) {
    return radius.r;
  }

  /// Check if device is tablet
  bool isTablet(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final shortestSide = mediaQuery.size.shortestSide;
    return shortestSide >= 600;
  }

  /// Check if device is phone
  bool isPhone(BuildContext context) {
    return !isTablet(context);
  }

  /// Get device type
  DeviceType getDeviceType(BuildContext context) {
    return isTablet(context) ? DeviceType.tablet : DeviceType.phone;
  }

  /// Get responsive padding based on device type
  EdgeInsets getResponsivePadding(BuildContext context, {
    double? phonePadding,
    double? tabletPadding,
  }) {
    final deviceType = getDeviceType(context);
    final padding = deviceType == DeviceType.tablet 
        ? (tabletPadding ?? 24.0)
        : (phonePadding ?? 16.0);
    
    return EdgeInsets.all(padding.w);
  }

  /// Get responsive margin based on device type
  EdgeInsets getResponsiveMargin(BuildContext context, {
    double? phoneMargin,
    double? tabletMargin,
  }) {
    final deviceType = getDeviceType(context);
    final margin = deviceType == DeviceType.tablet 
        ? (tabletMargin ?? 24.0)
        : (phoneMargin ?? 16.0);
    
    return EdgeInsets.all(margin.w);
  }
}

/// Device type enum
enum DeviceType {
  phone,
  tablet,
}
