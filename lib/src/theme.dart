import 'package:flutter/material.dart';

ThemeData buildAutivraTheme(
  Brightness brightness, {
  Color seed = const Color(0xFF4CAF7A),
  Color? backgroundColor,
  Color? cardColor,
  Color? textColor,
  String fontFamily = 'Roboto',
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final defaultBackground = brightness == Brightness.light
      ? Color.alphaBlend(seed.withValues(alpha: 0.025), const Color(0xFFF7FAF8))
      : Color.alphaBlend(seed.withValues(alpha: 0.04), const Color(0xFF101412));
  final defaultCard = brightness == Brightness.light
      ? scheme.surface
      : scheme.surfaceContainerLow;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: fontFamily,
  );
  final resolvedText = textColor ?? scheme.onSurface;
  return base.copyWith(
    scaffoldBackgroundColor: backgroundColor ?? defaultBackground,
    canvasColor: backgroundColor ?? defaultBackground,
    textTheme: base.textTheme.apply(
      bodyColor: resolvedText,
      displayColor: resolvedText,
      fontFamily: fontFamily,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: fontFamily),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor ?? defaultBackground,
      foregroundColor: resolvedText,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardColor ?? defaultCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: (cardColor ?? scheme.surfaceContainerLowest)
          .withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
    ),
  );
}

Widget applyAutivraTextScale(
  BuildContext context,
  Widget? child,
  double fontScale,
) {
  if (child == null) return const SizedBox.shrink();
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) return child;
  final appScale = fontScale.clamp(0.8, 1.6).toDouble();
  final systemScale = mediaQuery.textScaler.scale(1.0);
  final effectiveScale =
      (systemScale * appScale).clamp(0.75, 2.4).toDouble();
  return MediaQuery(
    data: mediaQuery.copyWith(textScaler: TextScaler.linear(effectiveScale)),
    child: child,
  );
}
