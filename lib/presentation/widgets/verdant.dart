import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Verdant — the app's futuristic green design language.
// Dark "bio-glass" pods with topographic contour lines (think leaf veins /
// growth rings), neon-leaf glow accents and lime highlights, floating over the
// frosted white backdrop (GGlassBg).
// ═════════════════════════════════════════════════════════════════════════════

class V {
  static const ink = Color(0xFF04140B); // near-black green
  static const deep = Color(0xFF0A2E1A);
  static const leaf = Color(0xFF1F7A4A);
  static const neon = Color(0xFF2EF29A); // bio-luminescent accent
  static const lime = Color(0xFFD4FF4F); // highlight / active
  static const mint = Color(0xFFBFF5DA);
  static const fog = Color(0xFF6E8C7B); // muted text on light
}

// Display type — Space Grotesk reads technical/futuristic next to Poppins body.
TextStyle vx(double size, {FontWeight w = FontWeight.w600, Color? color, double ls = 0, double h = 1.1}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: color ?? V.ink, letterSpacing: ls, height: h);

// ─── Topographic contour lines ───────────────────────────────────────────────
// Concentric, organically wobbling rings — drawn once and cached.
class ContourPainter extends CustomPainter {
  final Color color;
  final Offset center; // fractional (0..1) origin of the rings
  final int rings;
  final double seed;
  const ContourPainter({required this.color, this.center = const Offset(0.85, 0.15), this.rings = 9, this.seed = 1});

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

// ─── Dark bio-glass pod ──────────────────────────────────────────────────────
BoxDecoration vPodDecoration({double radius = 30, Color? glow}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF2062014), Color(0xEB0B3320), Color(0xE6124A2D)],
        stops: [0, 0.55, 1],
      ),
      border: Border.all(color: V.neon.withValues(alpha: 0.22), width: 1),
      boxShadow: [
        BoxShadow(color: (glow ?? V.neon).withValues(alpha: 0.14), blurRadius: 30, offset: const Offset(0, 12)),
        BoxShadow(color: V.ink.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8)),
      ],
    );

class VPod extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Offset contourCenter;
  final Color? glow;
  const VPod({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 30,
    this.contourCenter = const Offset(0.9, 0.1),
    this.glow,
  });

  @override
  Widget build(BuildContext ctx) => Container(
        decoration: vPodDecoration(radius: radius, glow: glow),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: ContourPainter(color: V.neon.withValues(alpha: 0.10), center: contourCenter)),
            ),
          ),
          // Neon bloom in the corner the contours radiate from
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(contourCenter.dx * 2 - 1, contourCenter.dy * 2 - 1),
                    radius: 0.9,
                    colors: [(glow ?? V.neon).withValues(alpha: 0.20), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ]),
      );
}

// ─── Small UI atoms ──────────────────────────────────────────────────────────

// "● 02 — EXPLORE" style eyebrow label.
class VLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool dot;
  const VLabel(this.text, {super.key, this.color = V.leaf, this.dot = true});
  @override
  Widget build(BuildContext ctx) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(text.toUpperCase(), style: vx(10.5, w: FontWeight.w700, color: color, ls: 1.6)),
      ]);
}

// Numbered section heading with a fading hairline and optional action.
class VSection extends StatelessWidget {
  final String index, title;
  final String? action;
  final VoidCallback? onAction;
  const VSection({super.key, required this.index, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            VLabel('$index — $title'),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [V.leaf.withValues(alpha: 0.35), V.leaf.withValues(alpha: 0)]),
                ),
              ),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAction,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(action!, style: vx(12.5, w: FontWeight.w700, color: V.deep)),
                  const SizedBox(width: 4),
                  const Icon(Icons.north_east_rounded, size: 14, color: V.deep),
                ]),
              ),
            ],
          ]),
        ]),
      );
}

// Icon inside a glowing glass orb.
class VOrb extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool dark;
  final Color accent;
  const VOrb({super.key, required this.icon, this.size = 52, this.dark = true, this.accent = V.neon});
  @override
  Widget build(BuildContext ctx) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: dark
              ? const RadialGradient(center: Alignment(-0.4, -0.5), colors: [Color(0xFF1C5A38), V.ink])
              : RadialGradient(center: const Alignment(-0.4, -0.5), colors: [Colors.white, V.mint.withValues(alpha: 0.7)]),
          border: Border.all(color: accent.withValues(alpha: dark ? 0.55 : 0.8), width: 1.2),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: dark ? 0.35 : 0.25), blurRadius: 16, spreadRadius: -2)],
        ),
        child: Icon(icon, size: size * 0.44, color: dark ? accent : V.deep),
      );
}

// Lime "→ Action" chip used on dark pods.
class VChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool onDark;
  const VChip(this.label, {super.key, this.icon = Icons.arrow_forward_rounded, this.onDark = true});
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: onDark ? V.lime : V.ink,
          borderRadius: BorderRadius.circular(99),
          boxShadow: onDark ? [BoxShadow(color: V.lime.withValues(alpha: 0.35), blurRadius: 12)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: vx(12, w: FontWeight.w700, color: onDark ? V.ink : V.lime)),
          const SizedBox(width: 6),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: onDark ? V.ink : V.lime, shape: BoxShape.circle),
            child: Icon(icon, size: 11, color: onDark ? V.lime : V.ink),
          ),
        ]),
      );
}

// Concentric "sonar" rings behind a live element. Plays once on appear —
// never loops (looping animations keep the GPU busy and heat the phone).
class VPulse extends StatelessWidget {
  final double size;
  final Color color;
  const VPulse({super.key, this.size = 60, this.color = V.neon});
  @override
  Widget build(BuildContext ctx) => SizedBox(
        width: size, height: size,
        child: Stack(alignment: Alignment.center, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: size * (0.55 + i * 0.22), height: size * (0.55 + i * 0.22),
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.55 - i * 0.16), width: 1.1)),
            )
                .animate(delay: (i * 140).ms)
                .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 900.ms, curve: Curves.easeOutCubic)
                .fadeIn(duration: 700.ms),
        ]),
      );
}

// Frosted glass panel with a soft mint sheen — the light counterpart to VPod.
class VGlassTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  const VGlassTile({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 26, this.tint});
  @override
  Widget build(BuildContext ctx) => GGlass(
        radius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.72), (tint ?? V.mint).withValues(alpha: 0.38)],
        ),
        padding: padding,
        child: child,
      );
}

// Floating frosted bar (used for the home top bar).
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
