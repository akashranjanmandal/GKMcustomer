import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  // Status badge always uses white background so it's readable on any surface
  static Color statusBg(String s) => const Color(0xFFFFFFFF);

  static Color statusFg(String s) {
    switch (s) {
      case 'pending':     return const Color(0xFFB45309); // amber-700
      case 'assigned':    return const Color(0xFF1D4ED8); // blue-700
      case 'en_route':    return const Color(0xFF1D4ED8);
      case 'arrived':     return const Color(0xFFD97706); // amber-600
      case 'in_progress': return const Color(0xFFD97706);
      case 'completed':   return const Color(0xFF16A34A); // green-600
      case 'cancelled':   return const Color(0xFF6B7280); // gray-500
      case 'failed':      return const Color(0xFFDC2626); // red-600
      case 'active':      return const Color(0xFF16A34A);
      case 'paused':      return const Color(0xFFD97706);
      case 'expired':     return const Color(0xFFDC2626);
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
      // Pages sit on the app-wide frosted backdrop (GGlassBg), so scaffolds
      // are transparent by default.
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: C.forest, foregroundColor: Colors.white,
        elevation: 0, centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: _p(17, w: FontWeight.w700, color: Colors.white, ls: -0.3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(t.textTheme),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: C.forest,
        selectionColor: Color(0x3303411A),       // forest @ 20% — subtle, no dark outline
        selectionHandleColor: C.forest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: C.subtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: _p(14, color: C.t4),
        border:             OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
        enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
        focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
        errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red)),
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
        TargetPlatform.android: GlassPageTransitionsBuilder(),
        TargetPlatform.iOS: GlassPageTransitionsBuilder(),
      }),
    );
  }

  static TextStyle _p(double size, {FontWeight w = FontWeight.w400, Color color = C.t2, double ls = 0}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: color, letterSpacing: ls);
}

// helper used in multiple files
TextStyle p(double size, {FontWeight w = FontWeight.w400, Color? color, double ls = 0, double h = 1, TextDecoration? decoration, bool italic = false}) =>
  GoogleFonts.poppins(fontSize: size, fontWeight: w, color: color ?? C.t2, letterSpacing: ls, height: h, decoration: decoration, fontStyle: italic ? FontStyle.italic : FontStyle.normal);

// ─── Glassmorphism ───────────────────────────────────────────────────────────
// App-wide backdrop: soft white "frosted" surface with blurred colour washes
// behind it so translucent glass cards have something to refract.
class GGlassBg extends StatelessWidget {
  final Widget child;
  const GGlassBg({super.key, required this.child});

  static Widget _wash(Color c, double size) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: ColoredBox(
            color: const Color(0xFFF5F9F4),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(top: -w * 0.35, left: -w * 0.35, child: _wash(const Color(0xFFA8E6BF).withValues(alpha: 0.55), w * 1.1)),
              Positioned(top: w * 0.55, right: -w * 0.45, child: _wash(const Color(0xFF5DBB84).withValues(alpha: 0.28), w * 1.2)),
              Positioned(bottom: -w * 0.4, left: -w * 0.3, child: _wash(C.gold.withValues(alpha: 0.30), w * 1.1)),
              Positioned(bottom: w * 0.2, right: -w * 0.2, child: _wash(const Color(0xFFBFE9D2).withValues(alpha: 0.40), w * 0.8)),
              // White frost over the washes
              Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.38))),
            ]),
          ),
        ),
      ),
      Positioned.fill(child: child),
    ]);
  }
}

// Frosted glass panel. [tint] overrides the default white glass.
// [blur] defaults to 0: a live BackdropFilter re-blurs everything behind it on
// every frame, and dozens of them in scrolling lists overheat phones. Over the
// static GGlassBg backdrop a translucent fill looks the same, so only opt in
// to real blur for a single element over moving content.
class GGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius radius;
  final Color? tint;
  final Gradient? gradient;
  final double blur;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  const GGlass({
    super.key,
    required this.child,
    this.padding,
    this.radius = const BorderRadius.all(Radius.circular(22)),
    this.tint,
    this.gradient,
    this.blur = 0,
    this.borderColor,
    this.shadows,
  });

  Widget _maybeBlur(Widget w) =>
      blur <= 0 ? w : BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: w);

  @override
  Widget build(BuildContext ctx) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows ?? [BoxShadow(color: C.forest.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: _maybeBlur(Container(
            padding: padding,
            decoration: BoxDecoration(
              color: gradient == null ? (tint ?? Colors.white.withValues(alpha: 0.62)) : null,
              gradient: gradient,
              borderRadius: radius,
              border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.75), width: 1.2),
            ),
            child: child,
          )),
        ),
      );
}

// Every pushed page gets the frosted backdrop under the usual iOS-style slide.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      const CupertinoPageTransitionsBuilder()
          .buildTransitions(route, context, animation, secondaryAnimation, GGlassBg(child: child));
}
