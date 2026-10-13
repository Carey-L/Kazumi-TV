import 'package:flutter/material.dart';

import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/platform_variant.dart';

/// Global visual scale for typography. 1.5× keeps text legible at ten feet
/// without touching `MediaQuery.textScaler`, so layout breakpoints that read
/// the system text scale stay unchanged.
const double kGlobalTextScale = 1.5;

/// Green focus accent used for the TV focus ring. Falls back to the theme's
/// primary so a custom palette still tints the ring.
const Color kTvFocusBorderColor = Colors.green;

ThemeData buildKazumiTheme({
  required Brightness brightness,
  String? fontFamily,
  Color? color,
  ColorScheme? colorScheme,
}) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: brightness,
    colorSchemeSeed: color,
    colorScheme: colorScheme,
    progressIndicatorTheme: progressIndicatorTheme2024,
    sliderTheme: sliderTheme2024,
    pageTransitionsTheme: pageTransitionsTheme2024,
  );

  final scaled = base.copyWith(
    textTheme: base.textTheme.apply(fontSizeFactor: kGlobalTextScale),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontSizeFactor: kGlobalTextScale,
    ),
  );

  if (!isTvBuild) return scaled;

  final primary = scaled.colorScheme.primary;
  // A green ring on every focused button makes the remote's position obvious
  // in both light and dark palettes.
  final focusRing = WidgetStateProperty.resolveWith<BorderSide?>((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: kTvFocusBorderColor, width: 3);
    }
    return null;
  });
  final buttonShape = WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
  final buttonStyle = ButtonStyle(side: focusRing, shape: buttonShape);

  return scaled.copyWith(
    focusColor: primary.withValues(alpha: 0.32),
    hoverColor: primary.withValues(alpha: 0.16),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: const VisualDensity(horizontal: 1, vertical: 1),
    iconButtonTheme: IconButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    navigationBarTheme: NavigationBarThemeData(
      height: 160,
      iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 48)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      minWidth: 104,
      selectedIconTheme: IconThemeData(size: 48),
      unselectedIconTheme: IconThemeData(size: 48),
    ),
  );
}

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
