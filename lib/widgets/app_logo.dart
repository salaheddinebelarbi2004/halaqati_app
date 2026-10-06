import 'package:flutter/material.dart';

/// Brand logo for the welcome and sign-in screens.
///
/// The PNG already has a transparent background, so it needs no container or
/// themed plate behind it — it reads on both light and dark surfaces.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 88,
    this.alignment = Alignment.center,
    this.semanticLabel = 'حلقتي',
  });

  final double size;
  final AlignmentGeometry alignment;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Image.asset(
      'assets/icons/pico.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
    ),
  );
}
