// lib/utils/theme.dart
// Production-grade design system for DentaLogic
// Aesthetic: Clinical precision meets modern digital health

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────
  static const Color primary          = Color(0xFF1A56DB);
  static const Color primaryDark      = Color(0xFF1343B0);
  static const Color primaryContainer = Color(0xFFDBEAFF);
  static const Color onPrimaryContainer = Color(0xFF00234E);

  static const Color secondary        = Color(0xFF059669);
  static const Color secondaryLight   = Color(0xFFD1FAE5);
  static const Color onSecondaryContainer = Color(0xFF002B1A);

  static const Color surface          = Color(0xFFF8FAFF);
  static const Color surfaceContainer = Color(0xFFEFF3FB);
  static const Color surfaceElevated  = Color(0xFFFFFFFF);
  static const Color shellTop         = Color(0xFFF4F8FF);
  static const Color shellBottom      = Color(0xFFE7EEF9);
  static const Color glassBorder      = Color(0xB7FFFFFF);
  static const Color inkDark          = Color(0xFF09111F);

  static const Color onSurface        = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF475569);
  static const Color outline          = Color(0xFFCBD5E1);
  static const Color outlineVariant   = Color(0xFFE2E8F0);

  static const Color error            = Color(0xFFDC2626);
  static const Color errorContainer   = Color(0xFFFEE2E2);
  static const Color warning          = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color success          = Color(0xFF059669);
  static const Color successContainer = Color(0xFFD1FAE5);

  // ── Typography ───────────────────────────────
  static TextTheme get _textTheme => TextTheme(
    displayLarge:   GoogleFonts.dmSans(fontSize: 57, fontWeight: FontWeight.w300, letterSpacing: -0.25),
    displayMedium:  GoogleFonts.dmSans(fontSize: 45, fontWeight: FontWeight.w300),
    displaySmall:   GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w400),
    headlineLarge:  GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineMedium: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    headlineSmall:  GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleLarge:     GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleMedium:    GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall:     GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge:      GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
    bodyMedium:     GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55),
    bodySmall:      GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
    labelLarge:     GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium:    GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelSmall:     GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2),
  );

  // ── Light Theme ──────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme(
      brightness:           Brightness.light,
      primary:              primary,
      onPrimary:            Colors.white,
      primaryContainer:     primaryContainer,
      onPrimaryContainer:   onPrimaryContainer,
      secondary:            secondary,
      onSecondary:          Colors.white,
      secondaryContainer:   secondaryLight,
      onSecondaryContainer: onSecondaryContainer,
      tertiary:             const Color(0xFF7C3AED),
      onTertiary:           Colors.white,
      tertiaryContainer:    const Color(0xFFEDE9FE),
      onTertiaryContainer:  const Color(0xFF2E1065),
      error:                error,
      onError:              Colors.white,
      errorContainer:       errorContainer,
      onErrorContainer:     const Color(0xFF7F1D1D),
      surface:              surface,
      onSurface:            onSurface,
      surfaceContainerHighest: surfaceContainer,
      onSurfaceVariant:     onSurfaceVariant,
      outline:              outline,
      outlineVariant:       outlineVariant,
      shadow:               const Color(0xFF000000),
      scrim:                const Color(0xFF000000),
      inverseSurface:       const Color(0xFF1E293B),
      onInverseSurface:     const Color(0xFFF1F5F9),
      inversePrimary:       const Color(0xFF93C5FD),
    );

    return ThemeData(
      useMaterial3:    true,
      colorScheme:     cs,
      textTheme:       _textTheme,
      scaffoldBackgroundColor: surface,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor:    primary,
        foregroundColor:    Colors.white,
        elevation:          0,
        scrolledUnderElevation: 0,
        centerTitle:        false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.3,
        ),
        toolbarHeight: 60,
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:    surfaceElevated,
        indicatorColor:     primaryContainer,
        surfaceTintColor:   Colors.transparent,
        elevation:          0,
        height:             62,
        labelBehavior:      NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? primary : onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? onPrimaryContainer : onSurfaceVariant,
            size: 22,
          );
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color:         surfaceElevated,
        elevation:     0,
        shadowColor:   Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       surfaceContainer,
        border:          _inputBorder(outline),
        enabledBorder:   _inputBorder(outlineVariant),
        focusedBorder:   _inputBorder(primary, width: 2),
        errorBorder:     _inputBorder(error),
        focusedErrorBorder: _inputBorder(error, width: 2),
        labelStyle:      GoogleFonts.dmSans(color: onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: GoogleFonts.dmSans(color: primary, fontWeight: FontWeight.w600, fontSize: 13),
        hintStyle:       GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 14),
        contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: onSurfaceVariant,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  primary,
          foregroundColor:  Colors.white,
          elevation:        0,
          shadowColor:      Colors.transparent,
          shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:          const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          textStyle:        GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
          minimumSize:      const Size(0, 46),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side:            const BorderSide(color: outline, width: 1.2),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          textStyle:       GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          minimumSize:     const Size(0, 46),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding:         const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle:       GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor:     surfaceContainer,
        selectedColor:       primaryContainer,
        secondarySelectedColor: primaryContainer,
        labelStyle:          GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
        shape:               RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side:                const BorderSide(color: outlineVariant),
        padding:             const EdgeInsets.symmetric(horizontal: 4),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:    surfaceElevated,
        surfaceTintColor:   Colors.transparent,
        elevation:          0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: false,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor:  surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle:   GoogleFonts.dmSans(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: onSurface),
        contentTextStyle: GoogleFonts.dmSans(
            fontSize: 14, color: onSurfaceVariant, height: 1.5),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor:  primaryContainer,
        foregroundColor:  onPrimaryContainer,
        elevation:        2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: outlineVariant, thickness: 1, space: 1,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
        subtitleTextStyle: GoogleFonts.dmSans(
            fontSize: 12, color: onSurfaceVariant),
        iconColor: onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.dmSans(
            fontSize: 14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : Colors.white60),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : const Color(0xFFCBD5E1)),
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────
  static ThemeData get dark {
    const darkSurface = Color(0xFF0B1220);
    const darkSurface2 = Color(0xFF0F1B2D);
    const darkOnSurface = Color(0xFFE6EEF9);
    const darkOnVariant = Color(0xFFA8B3C7);

    final cs = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF66A3FF),
      onPrimary: const Color(0xFF07111D),
      primaryContainer: const Color(0xFF173A77),
      onPrimaryContainer: const Color(0xFFE9F3FF),
      secondary: const Color(0xFF34D399),
      onSecondary: const Color(0xFF052016),
      secondaryContainer: const Color(0xFF0C3A2A),
      onSecondaryContainer: const Color(0xFFCFFAE5),
      tertiary: const Color(0xFFC4B5FD),
      onTertiary: const Color(0xFF1F123B),
      tertiaryContainer: const Color(0xFF2C1F55),
      onTertiaryContainer: const Color(0xFFEDE9FE),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF2A0B0B),
      errorContainer: const Color(0xFF3B1212),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: darkSurface,
      onSurface: darkOnSurface,
      surfaceContainerHighest: darkSurface2,
      onSurfaceVariant: darkOnVariant,
      outline: const Color(0xFF24344D),
      outlineVariant: const Color(0xFF1B2840),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: const Color(0xFFE6EEF9),
      onInverseSurface: const Color(0xFF0B1220),
      inversePrimary: const Color(0xFF1A56DB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: _textTheme.apply(
        bodyColor: darkOnSurface,
        displayColor: darkOnSurface,
      ),
      scaffoldBackgroundColor: darkSurface,

      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkOnSurface,
          letterSpacing: -0.3,
        ),
        toolbarHeight: 60,
        iconTheme: const IconThemeData(color: darkOnSurface, size: 22),
      ),

      cardTheme: CardThemeData(
        color: darkSurface2,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  // ── Semantic color helpers ───────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ok':      return success;
      case 'warning': return warning;
      case 'expired': return error;
      default:        return onSurfaceVariant;
    }
  }

  static Color statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'ok':      return successContainer;
      case 'warning': return warningContainer;
      case 'expired': return errorContainer;
      default:        return surfaceContainer;
    }
  }

  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [shellTop, shellBottom, Color(0xFFF8FAFF)],
    stops: [0.0, 0.55, 1.0],
  );

  static BoxDecoration glassCard({
    BorderRadius? radius,
    Color? tint,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (tint ?? Colors.white).withOpacity(0.92),
          Colors.white.withOpacity(0.78),
        ],
      ),
      borderRadius: radius ?? BorderRadius.circular(20),
      border: Border.all(color: glassBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0E1726).withOpacity(0.06),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static Widget glass({
    required Widget child,
    BorderRadius? radius,
    double blur = 16,
    Color? tint,
    EdgeInsetsGeometry? padding,
  }) {
    final r = radius ?? BorderRadius.circular(22);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: glassCard(radius: r, tint: tint),
          child: child,
        ),
      ),
    );
  }
}
