import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppColors {
  AppColors._();
  static const primary = Color(0xFF0A6E4E); // Nigerian green
  static const primaryDark = Color(0xFF064A34);
  static const accent = Color(0xFFE8B923); // warm gold accent
  static const background = Color(0xFFF7F7F5);
  static const surface = Colors.white;
  static const error = Color(0xFFD64545);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
}

class AppTheme {
  AppTheme._();

  /// One radius for every button type, so buttons grouped in a row always
  /// agree. Matches the input fields, which use the same 12.
  static const _buttonRadius = BorderRadius.all(Radius.circular(12));

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary, brightness: Brightness.light);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      // Applies only where a call site leaves size unset - Material's own
      // default is 24; most icons here already pin their own explicit size
      // (16-20 for inline glyphs, larger for empty-state art), so this only
      // catches bare `Icon(...)`/`IconButton(...)` calls, trimming those to
      // match the bolder-but-smaller look the rest of the icon set was
      // switched to (see bold_icons.dart).
      iconTheme: const IconThemeData(size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        // Material 3 tints the app bar once content scrolls under it, which
        // reads as the header changing colour mid-scroll. Keep it flat.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      // All four button types share one corner radius. Previously only
      // ElevatedButton was themed, so an OutlinedButton or TextButton sitting
      // next to one inherited Material's stadium default and the pair looked
      // mismatched - neither wrong on its own, just styled from different places.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          // Full-width by default, for the form buttons that dominate this app.
          // Inline buttons must override this; a Row measures non-flex children
          // with unbounded width, and Size.fromHeight is Size(infinity, h),
          // which would ask the button to lay out infinitely wide.
          minimumSize: const Size.fromHeight(50),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: Colors.grey.shade300),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: _buttonRadius, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(borderRadius: _buttonRadius, borderSide: BorderSide.none),
        // These fields have no outline, so a floating label had no notch to sit
        // in and rode up into the fill edge looking broken. Keeping the label in
        // place means it behaves as a placeholder and simply clears on input.
        floatingLabelBehavior: FloatingLabelBehavior.never,
        // Without this there was no focus indication at all, since every border
        // was BorderSide.none.
        focusedBorder: OutlineInputBorder(
          borderRadius: _buttonRadius,
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.55), width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _buttonRadius,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: _buttonRadius,
          borderSide: BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        errorStyle: const TextStyle(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Styled centrally so every spinner in both apps is the same: a thin,
      // round-capped arc in brand green rather than Material's default thick
      // grey-blue ring. Set here instead of at ~30 call sites.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: Color(0x14000000),
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
        constraints: BoxConstraints.tightFor(width: 26, height: 26),
        linearTrackColor: Color(0x14000000),
        linearMinHeight: 3,
        // Only reached if a bare Material RefreshIndicator is ever used; every
        // screen goes through AppRefresh, which draws its own puck.
        refreshBackgroundColor: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(3)),
        // The 2024 Material spec adds a wide track gap and stop indicator that
        // reads as chunky at this size; keep the cleaner earlier geometry.
        year2023: true,
      ),
    );
  }
}

final _nairaFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

String formatNaira(num amount) => _nairaFormat.format(amount);

/// Wordmark style for the "iStay" brand name - use for logo-type text
/// (splash/login titles, app bar brand), not for body copy.
TextStyle brandTextStyle({double fontSize = 32, Color color = AppColors.primary}) =>
    GoogleFonts.baloo2(fontSize: fontSize, fontWeight: FontWeight.w700, color: color, height: 1.2);
