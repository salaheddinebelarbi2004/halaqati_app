import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_spacing.dart';

/// Screen size buckets and layout helpers shared by every screen.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1240;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compact && w < expanded;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

/// Reading-friendly maximum content width so lines never stretch on
/// phones, tablets, laptops and desktop windows alike.
class AppLayout {
  const AppLayout._();

  static const double maxContentWidth = 880;
  static const double wideContentWidth = 1120;
  static const double formMaxWidth = 560;
  static const double readerMaxWidth = 760;

  static double gutterFor(double width) {
    if (width >= AppBreakpoints.expanded) return AppSpacing.xxl;
    if (width >= AppBreakpoints.medium) return AppSpacing.xl;
    return AppSpacing.lg;
  }

  static double maxWidthFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded
      ? wideContentWidth
      : maxContentWidth;

  /// Number of grid columns appropriate for the current window.
  static int columnsFor(BuildContext context, {int max = 4}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1400) return max;
    if (w >= AppBreakpoints.expanded) return max > 3 ? 3 : max;
    if (w >= AppBreakpoints.medium) return 3;
    if (w >= AppBreakpoints.compact) return 2;
    return 2;
  }
}

/// Constrains content to a readable width and centres it.
class ContentShell extends StatelessWidget {
  const ContentShell({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.maxContentWidth,
    this.horizontalPadding,
    this.verticalPadding = 0,
  });

  final Widget child;
  final double maxWidth;
  final double? horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = horizontalPadding ?? AppLayout.gutterFor(width);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + padding * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: verticalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Standard horizontal page padding that follows the design system.
class PageGutter extends StatelessWidget {
  const PageGutter({super.key, required this.child, this.vertical = 0});

  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.gutterFor(width),
        vertical: vertical,
      ),
      child: child,
    );
  }
}

/// Initializes `flutter_screenutil` once, at app start.
///
/// Text scaling is clamped so a very large desktop window never produces
/// oversized type, and a very small window never produces unreadable type.
class ScreenUtilBootstrap extends StatelessWidget {
  const ScreenUtilBootstrap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(400, 860),
      minTextAdapt: true,
      useInheritedMediaQuery: true,
      enableScaleText: () => true,
      child: child,
    );
  }
}
