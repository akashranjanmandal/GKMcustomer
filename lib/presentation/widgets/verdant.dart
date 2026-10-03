import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // One-time light sweep + pop when the tile first appears (never loops).
  final bool shine;
  final Duration shineDelay;
  const VOrb({super.key, required this.icon, this.size = 48, this.dark = true, this.accent = V.neon,
    this.shine = false, this.shineDelay = Duration.zero});
  @override
  Widget build(BuildContext ctx) {
    final tile = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: dark ? V.deep : V.mint,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.46, color: dark ? Colors.white : V.deep),
    );
    if (!shine) return tile;
    return tile
        .animate(delay: shineDelay)
        .scale(begin: const Offset(0.82, 0.82), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack)
        .then(delay: 80.ms)
        .shimmer(duration: 900.ms, color: Colors.white.withValues(alpha: 0.85), angle: 0.6);
  }
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

// ─── Page header (light) ─────────────────────────────────────────────────────
// Round glass back button, optional trailing action, then a large serif title
// and subtitle sitting directly on the page — the standard top of a screen.
class VPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  const VPageHeader({super.key, required this.title, this.subtitle, this.trailing, this.onBack});
  @override
  Widget build(BuildContext ctx) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              VRoundBtn(icon: Icons.arrow_back_rounded, onTap: onBack ?? () => Navigator.maybePop(ctx)),
              const Spacer(),
              if (trailing != null) trailing!,
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: vx(32, w: FontWeight.w600, color: V.ink, ls: -0.8)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: GoogleFonts.poppins(fontSize: 13, color: V.fog, height: 1.4)),
                ],
              ]),
            ),
          ]),
        ),
      );
}

class VRoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const VRoundBtn({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: onTap,
        child: VLiquid(
          oval: true,
          tint: const Color(0x59FFFFFF),
          thickness: 18,
          interactive: true,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 21, color: V.ink)),
        ),
      );
}

// Dark pill action for page headers ("+ Book a visit").
class VPillAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const VPillAction({super.key, required this.label, this.icon = Icons.add_rounded, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
          decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: V.lime),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      );
}

// Light filter chip (ink when selected).
class VFilterChip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const VFilterChip({super.key, required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? V.ink : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: sel ? V.ink : Colors.white),
          ),
          child: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : V.ink)),
        ),
      );
}

// Picks a garden photo for a service by its slug/name keywords.
String serviceImageFor(String key, int i) {
  final k = key.toLowerCase();
  // Most specific first — "Monthly Plant Care" must match monthly, not plant.
  if (k.contains('lawn') || k.contains('grass')) return 'assets/images/Lawn.jpeg';
  if (k.contains('balcon')) return 'assets/images/balcony.jpeg';
  if (k.contains('terrace') || k.contains('roof')) return 'assets/images/terrace.jpeg';
  if (k.contains('makeover') || k.contains('landscap') || k.contains('design')) return 'assets/images/img-3.jpeg';
  if (k.contains('month') || k.contains('mainten') || k.contains('subscri')) return 'assets/images/backyard.jpeg';
  if (k.contains('one-time') || k.contains('one time') || k.contains('demand') || k.contains('visit')) return 'assets/images/img-6.jpeg';
  if (k.contains('indoor') || k.contains('office')) return 'assets/images/office_mobile.jpeg';
  if (k.contains('pest') || k.contains('disease')) return 'assets/images/img-12.jpeg';
  if (k.contains('soil') || k.contains('compost') || k.contains('fertil')) return 'assets/images/img-9.jpeg';
  const pool = ['assets/images/indoor.jpeg', 'assets/images/img-10.jpeg', 'assets/images/img-15.jpeg', 'assets/images/img-6.jpeg', 'assets/images/office_mobile.jpeg'];
  return pool[i % pool.length];
}

// ─── Liquid glass ────────────────────────────────────────────────────────────
// Real refractive glass (blur + edge lensing + specular light) for the
// floating controls layer only — nav dock, top-bar chips, floating buttons,
// back buttons, product rail, login card. Content cards stay on the cheap
// translucent fill (GGlass) to keep GPU load and heat down.
//
// Falls back to plain blur ("fake" glass) automatically where the renderer
// can't run shader filters (older Android devices on the legacy renderer).
// Set [VLiquid.enabled] = false to switch every liquid surface to fake glass.
class VLiquid extends StatefulWidget {
  static bool enabled = true;

  // Raised while something large moves (e.g. the tab switch). Hero glass
  // renders as lite glass during motion and returns to real glass after.
  static final ValueNotifier<int> motion = ValueNotifier(0);

  // Compile the glass shaders once at startup so the first glass surface
  // doesn't hitch while its shader is built.
  static Future<void> precache() async {
    await GlassPerf.init();
    if (!_shaderOk) return;
    const root = 'packages/liquid_glass_renderer/lib/assets/shaders/';
    for (final f in ['liquid_glass_geometry_blended.frag', 'liquid_glass_filter.frag', 'liquid_glass_final_render.frag']) {
      try { await FragmentProgram.fromAsset('$root$f'); } catch (_) {}
    }
  }

  final Widget child;
  final double radius;
  final bool oval;
  final Color tint;
  final double thickness;
  final double blur;
  // Background colour boost seen through the glass. Keep 1.0 for tinted
  // (green) glass — boosting pushes greens to neon.
  final double saturation;
  // Pressable glass: subtle press feedback (squash/glow on real glass, a
  // gentle scale on lite glass).
  final bool interactive;
  // Only "hero" surfaces (dock, floating CTA buttons, login card) ever get
  // real refractive glass — and only when GlassPerf says the device keeps up.
  // Everything else is lite glass: translucent fill + rim + sheen, no blur,
  // no shader — essentially free to render, so no heat and no jank.
  final bool hero;
  // Exact fill to use for lite glass (overrides the automatic tint lift) —
  // e.g. the login card over a dark photo must stay see-through.
  final Color? liteTint;
  const VLiquid({
    super.key,
    required this.child,
    this.radius = 24,
    this.oval = false,
    this.tint = const Color(0x33FFFFFF),
    this.thickness = 28,
    this.blur = 2,
    this.saturation = 1.25,
    this.interactive = false,
    this.hero = false,
    this.liteTint,
  });

  static bool get _shaderOk {
    try {
      return ImageFilter.isShaderFilterSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  State<VLiquid> createState() => _VLiquidState();
}

// ─── Adaptive glass quality ──────────────────────────────────────────────────
// Real glass is on by default where the renderer supports it. In release
// builds the app samples frame timings; if a device misses frames regularly
// it drops to lite glass for good (remembered across launches).
class GlassPerf {
  static final ValueNotifier<bool> full = ValueNotifier(false);
  static const _prefKey = 'glass_lite_v1';
  static bool _inited = false;
  static final List<int> _frames = [];

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    var lite = false;
    try { lite = (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false; } catch (_) {}
    full.value = VLiquid.enabled && VLiquid._shaderOk && !lite;
    // Debug builds are always slow — only judge real (release/profile) builds.
    if (full.value && !kDebugMode) SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (!full.value) return;
    for (final t in timings) {
      _frames.add(t.totalSpan.inMicroseconds);
    }
    if (_frames.length < 180) return; // ~3s of rendering
    final slow = _frames.where((us) => us > 20000).length;
    _frames.clear();
    if (slow / 180 > 0.2) downgrade();
  }

  static Future<void> downgrade() async {
    full.value = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    try { (await SharedPreferences.getInstance()).setBool(_prefKey, true); } catch (_) {}
  }
}

class _VLiquidState extends State<VLiquid> {
  bool _pressed = false;
  // Keeps the child's state if GlassPerf downgrades this surface at runtime.
  final _childKey = GlobalKey();

  Widget get _content => KeyedSubtree(key: _childKey, child: widget.child);

  // Lite glass: pure paint (no blur, no shader, no offscreen layer).
  Widget _lite() {
    final w = widget;
    final dark = (w.liteTint ?? w.tint).computeLuminance() < 0.3 || w.liteTint != null;
    // Without blur the fill must carry legibility — lift light tints.
    final fill = w.liteTint ?? (dark
        ? w.tint.withValues(alpha: math.max(w.tint.a, 0.9))
        : Color.lerp(w.tint, Colors.white, 0.2)!.withValues(alpha: math.max(w.tint.a, 0.72)));
    final r = w.oval ? null : BorderRadius.circular(w.radius.clamp(0, 999).toDouble());
    final box = DecoratedBox(
      decoration: BoxDecoration(
        shape: w.oval ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: r,
        color: fill,
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.95), width: 1),
        boxShadow: [BoxShadow(color: V.ink.withValues(alpha: dark ? 0.22 : 0.08), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: DecoratedBox(
        // top sheen — reads as a glass highlight
        decoration: BoxDecoration(
          shape: w.oval ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: r,
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: dark ? 0.10 : 0.45), Colors.white.withValues(alpha: 0)],
            stops: const [0, 0.55],
          ),
        ),
        child: _content,
      ),
    );
    if (!w.interactive) return box;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(scale: _pressed ? 0.96 : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: box),
    );
  }

  Widget _real() {
    final w = widget;
    final g = LiquidGlass.withOwnLayer(
      shape: w.oval ? const LiquidOval() : LiquidRoundedSuperellipse(borderRadius: w.radius),
      settings: LiquidGlassSettings(
        glassColor: w.tint,
        thickness: w.thickness,
        blur: w.blur,
        refractiveIndex: 1.5,
        lightIntensity: 1.25,
        lightAngle: 0.65 * math.pi,
        ambientStrength: 0.45,
        saturation: w.saturation,
        chromaticAberration: 0.008,
      ),
      child: _content,
    );
    if (!w.interactive) return g;
    return LiquidStretch(interactionScale: 1.04, stretch: 0.3, resistance: 0.1, child: g);
  }

  // No switching during page/sheet transitions — flipping between lite and
  // real glass mid-transition is what made pages blink. Hero glass (dock,
  // login card) doesn't move with page transitions, so it stays real.
  @override
  Widget build(BuildContext ctx) {
    if (!widget.hero) return _lite();
    return ValueListenableBuilder<bool>(
      valueListenable: GlassPerf.full,
      builder: (_, full, __) => full ? _real() : _lite(),
    );
  }
}

// ─── Segmented filter ────────────────────────────────────────────────────────
// iOS-style segmented control: every option visible at once (no scrolling),
// a thumb that springs to the selection, optional counts, haptic tick.
class VSegmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int?>? counts;
  final bool onDark;
  const VSegmented({super.key, required this.labels, required this.index, required this.onChanged, this.counts, this.onDark = false});

  @override
  Widget build(BuildContext ctx) => LayoutBuilder(builder: (_, box) {
        final n = labels.length;
        final segW = (box.maxWidth - 8) / n;
        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: onDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.14) : Colors.white),
          ),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              left: segW * index, top: 0, bottom: 0, width: segW,
              child: Container(
                decoration: BoxDecoration(
                  color: onDark ? Colors.white : V.ink,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < n; i++)
                Expanded(child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { if (i != index) { HapticFeedback.selectionClick(); onChanged(i); } },
                  child: Center(child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: i == index ? (onDark ? V.ink : Colors.white) : (onDark ? Colors.white : V.ink)),
                          child: Text(labels[i]),
                        ),
                        if (counts != null && counts![i] != null && counts![i]! > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: i == index ? V.lime : V.ink.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(99)),
                            child: Text('${counts![i]}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: V.ink)),
                          ),
                        ],
                      ]),
                    ),
                  )),
                )),
            ]),
          ]),
        );
      });
}

// ─── Glass modals ────────────────────────────────────────────────────────────
// Every bottom sheet and dialog in the app is a floating liquid-glass panel.
// The body is a light frost (readable text) with refraction + rim light at
// the edges. Sheet content must have no background of its own.

Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: const Color(0x4D06140C),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, MediaQuery.of(ctx).viewInsets.bottom > 0 ? 8 : MediaQuery.of(ctx).padding.bottom + 8),
        child: VGlassPanel(child: builder(ctx)),
      ),
    );

// The glass surface used by sheets/dialogs (also usable standalone).
class VGlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  const VGlassPanel({super.key, required this.child, this.radius = 34});
  // Lite glass (no blur/shader) — modals open instantly on every device.
  @override
  Widget build(BuildContext ctx) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: VLiquid(
          radius: radius,
          tint: const Color(0xF5F5F9F4),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
}

// Drag handle for glass sheets.
class VSheetHandle extends StatelessWidget {
  const VSheetHandle({super.key});
  @override
  Widget build(BuildContext ctx) => Center(child: Container(
        width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(color: V.ink.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
      ));
}

// Glass confirm dialog. Returns true when the user confirms.
Future<bool> showGlassConfirm(BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  HapticFeedback.mediumImpact();
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x5206140C),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: VGlassPanel(radius: 30, child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: vx(22, w: FontWeight.w600, color: V.ink)),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.poppins(fontSize: 13.5, color: V.ink.withValues(alpha: 0.7), height: 1.5)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _DialogBtn(label: cancelLabel, onTap: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: _DialogBtn(label: confirmLabel, primary: true, destructive: destructive, onTap: () => Navigator.pop(ctx, true))),
          ]),
        ]),
      )),
    )),
    transitionBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(c), child: child));
    },
  );
  return ok == true;
}

class _DialogBtn extends StatelessWidget {
  final String label; final VoidCallback onTap; final bool primary, destructive;
  const _DialogBtn({required this.label, required this.onTap, this.primary = false, this.destructive = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? (destructive ? const Color(0xFFDC2626) : V.ink) : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(99),
            border: primary ? null : Border.all(color: Colors.white),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: primary ? Colors.white : V.ink)),
          )),
        ),
      );
}

// ─── Shared filter (button + glass sheet + active chips) ─────────────────────
// One filter pattern across the app (Shop, Bookings, Plans): a Filter pill
// opens a glass sheet with option sections laid out as tiles (everything
// visible — no sideways scrolling); applied filters show as removable chips.
class VFilterOption {
  final String value, label;
  final IconData? icon;
  const VFilterOption(this.value, this.label, {this.icon});
}

class VFilterSection {
  final String title;
  final List<VFilterOption> options;
  final String defaultValue;
  final bool tiles; // icon tiles grid (true) or a radio list (false)
  const VFilterSection({required this.title, required this.options, required this.defaultValue, this.tiles = true});
}

class VFilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final bool compact;
  // false when the button already sits on a glass surface (no glass-in-glass).
  final bool glass;
  const VFilterButton({super.key, required this.active, required this.onTap, this.compact = false, this.glass = true});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: _wrap(Container(
            height: compact ? 42 : 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: glass ? null : BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.tune_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text('Filter', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              if (active) ...[
                const SizedBox(width: 6),
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: V.lime, shape: BoxShape.circle)),
              ],
            ]),
          )),
      );

  Widget _wrap(Widget child) => !glass ? child : VLiquid(
        radius: 99,
        tint: const Color(0xCC123824),
        thickness: 20,
        saturation: 1.0,
        interactive: true,
        child: child,
      );
}

// Opens the glass filter sheet. Returns the chosen values (one per section)
// when "Show results" is tapped, or null if dismissed.
Future<List<String>?> showFilterSheet(BuildContext context, {
  required String title,
  required List<VFilterSection> sections,
  required List<String> current,
}) {
  HapticFeedback.selectionClick();
  final picked = [...current];
  return showGlassSheet<List<String>>(context, builder: (sheetCtx) => StatefulBuilder(builder: (_, setLocal) {
    void pick(int si, String v) { HapticFeedback.selectionClick(); setLocal(() => picked[si] = v); }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const VSheetHandle(),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(title, style: vx(24, w: FontWeight.w600, color: V.ink))),
          GestureDetector(
            onTap: () => setLocal(() { for (var i = 0; i < sections.length; i++) { picked[i] = sections[i].defaultValue; } }),
            child: Padding(padding: const EdgeInsets.all(6),
              child: Text('Reset', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: V.leaf))),
          ),
        ]),
        for (var si = 0; si < sections.length; si++) ...[
          const SizedBox(height: 18),
          Text(sections[si].title, style: vx(17, w: FontWeight.w600, color: V.ink)),
          const SizedBox(height: 10),
          if (sections[si].tiles)
            GridView.count(
              crossAxisCount: 3, shrinkWrap: true, padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.2,
              children: [
                for (final o in sections[si].options)
                  GestureDetector(
                    onTap: () => pick(si, o.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: picked[si] == o.value ? V.ink : Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: picked[si] == o.value ? V.ink : Colors.white),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (o.icon != null) Icon(o.icon, size: 22, color: picked[si] == o.value ? V.lime : V.deep),
                        if (o.icon != null) const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(o.label, maxLines: 1,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600,
                              color: picked[si] == o.value ? Colors.white : V.ink))),
                        ),
                      ]),
                    ),
                  ),
              ],
            )
          else
            for (final o in sections[si].options)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pick(si, o.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    if (o.icon != null) ...[Icon(o.icon, size: 19, color: V.deep), const SizedBox(width: 12)],
                    Expanded(child: Text(o.label, style: GoogleFonts.poppins(fontSize: 14,
                      fontWeight: picked[si] == o.value ? FontWeight.w600 : FontWeight.w400, color: V.ink))),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: picked[si] == o.value ? V.ink : Colors.transparent,
                        border: Border.all(color: picked[si] == o.value ? V.ink : V.fog, width: 1.5)),
                      child: picked[si] == o.value ? const Icon(Icons.check_rounded, size: 14, color: V.lime) : null,
                    ),
                  ]),
                ),
              ),
        ],
        const SizedBox(height: 20),
        GBtnLite(label: 'Show results', onTap: () => Navigator.pop(sheetCtx, picked)),
      ]),
    );
  }));
}

// Plain ink pill button (used inside glass sheets, where nested glass would
// look muddy).
class GBtnLite extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const GBtnLite({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          height: 52, width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      );
}

// Removable chip showing an applied filter.
class VActiveFilter extends StatelessWidget {
  final String label; final VoidCallback onClear;
  const VActiveFilter({super.key, required this.label, required this.onClear});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onClear(); },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: V.deep)),
            const SizedBox(width: 6),
            const Icon(Icons.close_rounded, size: 15, color: V.deep),
          ]),
        ),
      ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9));
}
