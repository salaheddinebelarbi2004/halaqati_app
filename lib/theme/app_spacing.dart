import 'package:flutter/material.dart';

/// Spacing, radius, elevation and icon sizing tokens.
///
/// Everything is a multiple of 4 to stay on a predictable rhythm.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Vertical rhythm between sections.
  static const double sectionGap = xxl;
  static const double cardGap = md;
  static const double gutter = lg;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));
}

/// Very light, consistent elevation levels.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> none = [];

  static List<BoxShadow> get subtle => const [
    BoxShadow(color: Color(0x0A0E2A24), blurRadius: 12, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> get raised => const [
    BoxShadow(color: Color(0x120E2A24), blurRadius: 20, offset: Offset(0, 6)),
  ];

  static List<BoxShadow> get floating => const [
    BoxShadow(color: Color(0x1A0E2A24), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

class AppIconSize {
  const AppIconSize._();

  static const double xs = 14;
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 26;
  static const double xl = 32;
  static const double xxl = 44;
}

/// Standard control heights.
class AppSizes {
  const AppSizes._();

  static const double buttonHeight = 48;
  static const double buttonHeightSm = 40;
  static const double fieldHeight = 50;
  static const double appBarHeight = 60;
  static const double minTapTarget = 44;
  static const double avatarSm = 36;
  static const double avatarMd = 44;
  static const double avatarLg = 56;
}

/// Motion: short and subtle only.
class AppDurations {
  const AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
}
