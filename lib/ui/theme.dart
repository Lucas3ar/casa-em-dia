import 'package:flutter/material.dart';

const forest = Color(0xff193f34);
const mint = Color(0xffd9ecd9);
const ivory = Color(0xfff6f3eb);
const ink = Color(0xff162b23);
const clay = Color(0xff963f22);

ThemeData buildTheme() {
  final colors = ColorScheme.fromSeed(seedColor: forest).copyWith(
    primary: forest,
    secondaryContainer: mint,
    surface: ivory,
    onSurface: ink,
    onSecondaryContainer: forest,
    outlineVariant: const Color(0xffdedfd4),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: ivory,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: ivory,
      foregroundColor: ink,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xfffffdf7),
      indicatorColor: mint,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xfffffdf7),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xfffffdf7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge!.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
      ),
      headlineSmall: base.textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
