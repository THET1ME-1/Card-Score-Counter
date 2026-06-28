import 'package:flutter/material.dart';

/// Тема приложения в духе Material 3 Expressive.
///
/// Сине-бирюзовая палитра, выразительная типографика (Unbounded для заголовков,
/// Onest для текста), скруглённые «таблеточные» кнопки и крупные формы.
class AppTheme {
  AppTheme._();

  /// Шрифт заголовков и крупных цифр.
  static const String displayFont = 'Unbounded';

  /// Шрифт основного текста.
  static const String bodyFont = 'Onest';

  /// Бирюзовый seed-цвет, из которого строится вся схема.
  static const Color seedColor = Color(0xFF00B5C7);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
    );

    final textTheme = _expressiveTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      // «Таблеточные» крупные кнопки — фирменная черта expressive-стиля.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: bodyFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          elevation: 0,
          textStyle: TextStyle(
            fontFamily: bodyFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        height: 72,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(thickness: 1),
    );
  }

  static TextTheme _expressiveTextTheme(TextTheme base) {
    TextStyle display(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        );
    TextStyle headline(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        );
    TextStyle title(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w600,
        );
    TextStyle body(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: bodyFont,
        );

    return base.copyWith(
      displayLarge: display(base.displayLarge),
      displayMedium: display(base.displayMedium),
      displaySmall: display(base.displaySmall),
      headlineLarge: headline(base.headlineLarge),
      headlineMedium: headline(base.headlineMedium),
      headlineSmall: headline(base.headlineSmall),
      titleLarge: title(base.titleLarge),
      titleMedium: title(base.titleMedium),
      titleSmall: title(base.titleSmall),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    );
  }
}
