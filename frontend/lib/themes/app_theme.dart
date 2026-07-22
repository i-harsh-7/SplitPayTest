import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// SplitPay design system
///
/// A single source of truth for colors, spacing, radii, elevation and
/// typography so every screen stays visually consistent. Prefer these tokens
/// over hardcoded values (e.g. use [AppSpacing.md] instead of `16`, and
/// [AppColors.success] instead of `Colors.green`).
/// ---------------------------------------------------------------------------

/// Brand + semantic color tokens shared across light and dark themes.
class AppColors {
  AppColors._();

  // Brand blues
  static const Color primaryLight = Color(0xFF2F6BFF); // refined brand blue
  static const Color primaryDark = Color(0xFF5B8DEF); // brighter for dark bg
  static const Color primaryDeep = Color(0xFF1B4DDB); // gradients / pressed

  // Surfaces
  static const Color scaffoldLight = Color(0xFFF5F7FB);
  static const Color scaffoldDark = Color(0xFF0F141C);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A2230);
  static const Color surfaceVariantDark = Color(0xFF232E40);

  // Text
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFF3F5F9);
  static const Color textSecondaryDark = Color(0xFFAEB6C4);

  // Borders / dividers
  static const Color borderLight = Color(0xFFE3E8F0);
  static const Color borderDark = Color(0xFF2C3950);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color info = Color(0xFF2F6BFF);

  /// Brand gradient used for hero surfaces and the active nav pill.
  static const List<Color> brandGradient = [primaryLight, primaryDeep];
}

/// Spacing scale (4pt grid).
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner-radius scale.
class AppRadii {
  AppRadii._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Soft, layered shadows for cards and floating surfaces.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(bool isDark) => [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> floating(bool isDark) => [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ];
}

class AppThemes {
  // Backwards-compatible aliases (kept so existing screens keep compiling).
  static const Color kPrimaryBlueLight = AppColors.primaryLight;
  static const Color kPrimaryBlueDark = AppColors.primaryDark;

  static const _systemLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static const _systemDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  // ------------------------------------------------------------------ LIGHT
  static final ThemeData lightTheme = _build(
    brightness: Brightness.light,
    primary: AppColors.primaryLight,
    scaffold: AppColors.scaffoldLight,
    surface: AppColors.surfaceLight,
    surfaceVariant: const Color(0xFFEEF2F9),
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    border: AppColors.borderLight,
    error: AppColors.danger,
    overlay: _systemLight,
  );

  // ------------------------------------------------------------------- DARK
  static final ThemeData darkTheme = _build(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    scaffold: AppColors.scaffoldDark,
    surface: AppColors.surfaceDark,
    surfaceVariant: AppColors.surfaceVariantDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    border: AppColors.borderDark,
    error: AppColors.dangerDark,
    overlay: _systemDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color scaffold,
    required Color surface,
    required Color surfaceVariant,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color error,
    required SystemUiOverlayStyle overlay,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary,
      onSecondary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      outline: border,
    );

    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      dividerColor: border,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        systemOverlayStyle: overlay,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      iconTheme: IconThemeData(color: textSecondary),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: border, width: isDark ? 1 : 0.8),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: primary.withOpacity(0.5), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceVariant : const Color(0xFFF1F4FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.8)),
        labelStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
        prefixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: error, width: 1.8),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceVariant : const Color(0xFF1F2937),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? surfaceVariant : const Color(0xFFEEF2F9),
        labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: primary),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontSize: 16, color: primary, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: primary, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, color: secondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
    );
  }
}
