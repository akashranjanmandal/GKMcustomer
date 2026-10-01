import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Verdant — the app's green glass design language.
// Calm and editorial: deep-green glass panels with faint contour lines, a
// botanical serif for headings, flat icon tiles, and lime used sparingly as
// the one highlight colour. No glows, pulses or decorative dots.
// ═════════════════════════════════════════════════════════════════════════════

class V {
  static const ink = Color(0xFF0B1F14); // near-black green
  static const deep = Color(0xFF123824);
  static const leaf = Color(0xFF2F6B47);
  static const neon = Color(0xFF8FD9AE); // soft accent on dark panels
  static const lime = Color(0xFFD9F27A); // single highlight colour
  static const mint = Color(0xFFE4F1E8); // icon tiles / light fills
  static const fog = Color(0xFF6B7F73); // muted text on light
}

// Display type — a botanical serif (Fraunces) for headings and figures;
// small sizes fall back to Poppins so labels stay crisp.
TextStyle vx(double size, {FontWeight w = FontWeight.w600, Color? color, double ls = 0, double h = 1.15}) =>
    size >= 17
        ? GoogleFonts.fraunces(fontSize: size, fontWeight: w, color: color ?? V.ink, letterSpacing: ls, height: h)
        : GoogleFonts.poppins(fontSize: size, fontWeight: w, color: color ?? V.ink, letterSpacing: ls, height: h);

// ─── Topographic contour lines ───────────────────────────────────────────────
// Concentric, organically wobbling rings (leaf veins / growth rings).
class ContourPainter extends CustomPainter {
  final Color color;
  final Offset center; // fractional (0..1) origin of the rings
  final int rings;
  final double seed;
  const ContourPainter({required this.color, this.center = const Offset(0.85, 0.15), this.rings = 8, this.seed = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final c = Offset(center.dx * size.width, center.dy * size.height);
    final maxR = size.longestSide * 1.05;
    for (var i = 1; i <= rings; i++) {
      final base = maxR * i / rings;
      final path = Path();
      for (var a = 0; a <= 72; a++) {
        final t = a / 72 * math.pi * 2;
        final wobble = 1 +
            0.07 * math.sin(t * 3 + i * 0.7 + seed) +
            0.04 * math.sin(t * 5 - i * 0.4 + seed * 2);
        final pt = c + Offset(math.cos(t), math.sin(t)) * base * wobble;
        a == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ContourPainter old) => old.color != color || old.center != center || old.rings != rings;
}

// ─── Deep-green glass panel ──────────────────────────────────────────────────
BoxDecoration vPodDecoration({double radius = 28, Color? glow}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF5102A1C), Color(0xF0153A26), Color(0xEB1D4A31)],
        stops: [0, 0.55, 1],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 12))],
    );

class VPod extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Offset contourCenter;
  final Color? glow; // kept for API compatibility; panels no longer glow
  const VPod({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.contourCenter = const Offset(0.9, 0.1),
    this.glow,
  });

  @override
  Widget build(BuildContext ctx) => Container(
        decoration: vPodDecoration(radius: radius),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: ContourPainter(color: Colors.white.withValues(alpha: 0.05), center: contourCenter)),
            ),
          ),
          Padding(padding: padding, child: child),
        ]),
      );
}

// ─── Small UI atoms ──────────────────────────────────────────────────────────

// Small uppercase eyebrow label.
class VLabel extends StatelessWidget {
  final String text;
  final Color color;
  const VLabel(this.text, {super.key, this.color = V.fog});
  @override
  Widget build(BuildContext ctx) =>
      Text(text.toUpperCase(), style: vx(10.5, w: FontWeight.w600, color: color, ls: 1.4));
}

// Section heading: serif title + optional "See all" link.
class VSection extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const VSection({super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(title, style: vx(22, w: FontWeight.w600, color: V.ink, ls: -0.4))),
          if (action != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(action!, style: vx(13, w: FontWeight.w600, color: V.leaf)),
              ),
            ),
        ]),
      );
}

// Flat icon tile — rounded square, no glow or gradient.
class VOrb extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool dark;
  final Color accent; // kept for API compatibility
  const VOrb({super.key, required this.icon, this.size = 48, this.dark = true, this.accent = V.neon});
  @override
  Widget build(BuildContext ctx) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: dark ? V.deep : V.mint,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.46, color: dark ? Colors.white : V.deep),
      );
}

// Small "Action →" chip used on dark panels.
class VChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool onDark;
  const VChip(this.label, {super.key, this.icon = Icons.arrow_forward_rounded, this.onDark = true});
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: onDark ? V.lime : V.ink,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: vx(12.5, w: FontWeight.w600, color: onDark ? V.ink : Colors.white)),
          const SizedBox(width: 6),
          Icon(icon, size: 15, color: onDark ? V.ink : Colors.white),
        ]),
      );
}

// Frosted glass panel with a soft mint sheen — the light counterpart to VPod.
class VGlassTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  const VGlassTile({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24, this.tint});
  @override
  Widget build(BuildContext ctx) => GGlass(
        radius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.8), (tint ?? V.mint).withValues(alpha: 0.45)],
        ),
        padding: padding,
        child: child,
      );
}

// Frosted strip (used for the home top bar).
class VFrost extends StatelessWidget {
  final Widget child;
  final double opacity;
  const VFrost({super.key, required this.child, this.opacity = 0.6});
  @override
  Widget build(BuildContext ctx) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(color: Colors.white.withValues(alpha: opacity), child: child),
        ),
      );
}
