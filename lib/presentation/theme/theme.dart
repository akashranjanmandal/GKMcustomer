import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand Palette ───────────────────────────────────────────────────────────
class C {
  // Primary
  static const forest  = Color(0xFF03411A);
  static const forest2 = Color(0xFF054D20);
  static const forest3 = Color(0xFF0A5C28);
  // Accent
  static const gold    = Color(0xFFEDCF87);
  static const goldDk  = Color(0xFFD4B96A);
  static const earth   = Color(0xFF96794F);
  static const sage    = Color(0xFF808285);
  // Surface
  static const bg      = Color(0xFFF3F7F1);
  static const white   = Color(0xFFFFFFFF);
  static const subtle  = Color(0xFFECF2E9);
  static const border  = Color(0xFFDDE8D9);
  static const divider = Color(0xFFEEF4EA);
  // Text
  static const t1      = Color(0xFF0D160B);
  static const t2      = Color(0xFF2E3D2A);
  static const t3      = Color(0xFF617A5A);
  static const t4      = Color(0xFF9AAA94);
  // Status
  static const green   = Color(0xFF16A34A);
  static const red     = Color(0xFFDC2626);
  static const amber   = Color(0xFFD97706);
  static const blue    = Color(0xFF2563EB);

  // Status pair
  static Color statusBg(String s) {
    switch (s) {
      case 'pending':     return const Color(0xFFEDCF87).withOpacity(0.22);
      case 'assigned':    return const Color(0xFF2563EB).withOpacity(0.10);
      case 'en_route':    return const Color(0xFF2563EB).withOpacity(0.10);
      case 'arrived':     return const Color(0xFFD97706).withOpacity(0.12);
      case 'in_progress': return const Color(0xFFD97706).withOpacity(0.12);
      case 'completed':   return const Color(0xFF16A34A).withOpacity(0.10);
      case 'cancelled':   return const Color(0xFF808285).withOpacity(0.14);
      case 'failed':      return const Color(0xFFDC2626).withOpacity(0.10);
      case 'active':      return const Color(0xFF16A34A).withOpacity(0.10);
      case 'paused':      return const Color(0xFFD97706).withOpacity(0.12);
      case 'expired':     return const Color(0xFFDC2626).withOpacity(0.10);
      default:            return const Color(0xFF808285).withOpacity(0.14);
    }
  }

  static Color statusFg(String s) {
    switch (s) {
      case 'pending':     return const Color(0xFF7A4D00);
      case 'assigned':    return const Color(0xFF1D4ED8);
      case 'en_route':    return const Color(0xFF1D4ED8);
      case 'arrived':     return const Color(0xFF92400E);
      case 'in_progress': return const Color(0xFF92400E);
      case 'completed':   return const Color(0xFF14532D);
      case 'cancelled':   return const Color(0xFF6B7280);
      case 'failed':      return const Color(0xFF7F1D1D);
      case 'active':      return const Color(0xFF14532D);
      case 'paused':      return const Color(0xFF92400E);
      case 'expired':     return const Color(0xFF7F1D1D);
      default:            return const Color(0xFF6B7280);
    }
  }
}

// ─── Shadows ─────────────────────────────────────────────────────────────────
List<BoxShadow> s1() => [BoxShadow(color: C.forest.withOpacity(0.06), blurRadius: 8,  offset: const Offset(0, 2))];
List<BoxShadow> s2() => [BoxShadow(color: C.forest.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 5))];
List<BoxShadow> s3() => [BoxShadow(color: C.forest.withOpacity(0.16), blurRadius: 40, offset: const Offset(0, 10))];
List<BoxShadow> sGold() => [BoxShadow(color: C.gold.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 4))];

// ─── Theme ───────────────────────────────────────────────────────────────────
class AT {
  static ThemeData get light {
    final t = ThemeData.light(useMaterial3: true);
    return t.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: C.forest, primary: C.forest, secondary: C.gold,
        surface: C.white, background: C.bg, error: C.red,
      ),
      scaffoldBackgroundColor: C.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: C.forest, foregroundColor: Colors.white,
        elevation: 0, centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: _p(17, w: FontWeight.w700, color: Colors.white, ls: -0.3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(t.textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: C.subtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: _p(14, color: C.t4),
        border:         OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
        enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
        focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.forest, width: 1.5)),
        errorBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red, width: 1.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.forest, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: _p(15, w: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: C.white, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: C.border)),
      ),
      dividerTheme: const DividerThemeData(color: C.divider, thickness: 1, space: 0),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static TextStyle _p(double size, {FontWeight w = FontWeight.w400, Color color = C.t2, double ls = 0}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: color, letterSpacing: ls);
}

// helper used in multiple files
TextStyle p(double size, {FontWeight w = FontWeight.w400, Color? color, double ls = 0, double h = 1, TextDecoration? decoration, bool italic = false}) =>
  GoogleFonts.poppins(fontSize: size, fontWeight: w, color: color ?? C.t2, letterSpacing: ls, height: h, decoration: decoration, fontStyle: italic ? FontStyle.italic : FontStyle.normal);
