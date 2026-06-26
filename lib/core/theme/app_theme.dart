import 'package:flutter/material.dart';

/// Accent themes ported from CB8 `globals.css` (`[data-theme="..."]`).
///
/// Each maps to the `--primary` HSL the web app used. We expose them as plain
/// [Color]s so the Flutter app can swap the seed/primary at runtime exactly like
/// CB8 swapped the `data-theme` attribute.
enum AccentTheme {
  red(Color(0xFFEF4D4D)),
  blue(Color(0xFF4A9EFF)),
  green(Color(0xFF34C759)),
  purple(Color(0xFFA374FF)),
  orange(Color(0xFFF59342)),
  teal(Color(0xFF2DD4BF));

  const AccentTheme(this.color);
  final Color color;
}

/// Fixed surface palette from CB8's dark-first `:root` block in `globals.css`.
///
/// CB8 was dark-only in practice; we mirror those exact greys so the Flutter
/// app reads as the same product.
abstract final class CbColors {
  static const background = Color(0xFF0A0A0A); // --background  0 0% 3.9%
  static const surface = Color(0xFF141414); // --card        0 0% 7.8%
  static const surfaceAlt = Color(0xFF1C1C1C); // --secondary   0 0% 11%
  static const foreground = Color(0xFFE8E8E8); // --foreground  0 0% 91%
  static const mutedForeground = Color(0xFF888888); // --muted-foreground 0 0% 53.3%
  static const border = Color(0xFF2A2A2A); // --border      0 0% 16.5%
  static const destructive = Color(0xFFE05252); // --destructive 0 70.8% 60%
}

/// CB8 used `--radius: 0.375rem` (6px) globally.
const double kCbRadius = 6.0;

/// Builds the dark [ThemeData] for a given [AccentTheme], mirroring CB8.
ThemeData buildCbTheme(AccentTheme accent) {
  final scheme = ColorScheme.dark(
    primary: accent.color,
    onPrimary: Colors.white,
    secondary: accent.color,
    surface: CbColors.surface,
    onSurface: CbColors.foreground,
    surfaceContainerHighest: CbColors.surfaceAlt,
    outline: CbColors.border,
    error: CbColors.destructive,
  );

  final radius = BorderRadius.circular(kCbRadius);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: CbColors.background,
    canvasColor: CbColors.background,
    dividerColor: CbColors.border,
    splashFactory: InkRipple.splashFactory,
    cardTheme: CardThemeData(
      color: CbColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: CbColors.border),
        borderRadius: radius,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CbColors.background,
      foregroundColor: CbColors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CbColors.surface,
      indicatorColor: accent.color.withValues(alpha: 0.18),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CbColors.surfaceAlt,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: CbColors.foreground,
      displayColor: CbColors.foreground,
    ),
  );
}
