import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/services/api.dart';
import '../../data/services/cart_provider.dart';
import '../../data/services/ops_status_provider.dart';
import '../theme/theme.dart';
import 'verdant.dart';
export 'location_picker_sheet.dart';
export 'verdant.dart';
export 'service_details_sheet.dart';

// ─── Operations paused banner ────────────────────────────────────────────────
// Prominent, non-dismissible notice shown while the admin operations
// kill-switch is on (OpsStatusProvider.paused). Renders nothing when live.
class GOpsBanner extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  const GOpsBanner({super.key, this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 24)});

  @override
  Widget build(BuildContext ctx) => Consumer<OpsStatusProvider>(
    builder: (_, ops, __) {
      if (!ops.paused) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B12), // deep earthy dark — matches plan-card tiers
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.amber.withOpacity(0.55)),
          boxShadow: [BoxShadow(color: C.amber.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: C.amber.withOpacity(0.18), shape: BoxShape.circle),
            child: const Icon(Icons.pause_circle_filled_rounded, color: C.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ops.displayMessage, style: p(13.5, w: FontWeight.w800, color: Colors.white, h: 1.35)),
            const SizedBox(height: 4),
            Text('New bookings are temporarily unavailable.', style: p(11.5, w: FontWeight.w600, color: C.amber, h: 1.3)),
          ])),
        ]),
      );
    },
  );
}

// ─── Header ──────────────────────────────────────────────────────────────────
// Floating dark bio-glass pod (Verdant) — contour lines, neon bloom, hairline
// neon edge. Screens put white content inside it.
class GHeader extends StatelessWidget {
  final Widget child;
  final double pb;
  const GHeader({super.key, required this.child, this.pb = 36});
  @override
  Widget build(BuildContext ctx) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: VPod(
        radius: 30,
        padding: EdgeInsets.fromLTRB(18, 16, 18, (pb * 0.6).clamp(16, 40)),
        child: child,
      ),
    ),
  ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.06, end: 0, curve: Curves.easeOutCubic);
}

// ─── Info/Detail Row ──────────────────────────────────────────────────────────
class GDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const GDetailRow({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext ctx) => Padding(padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      VOrb(icon: icon, size: 38),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: vx(10, w: FontWeight.w700, color: V.fog, ls: 1.4)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, color: V.ink, height: 1.3)),
      ])),
    ]));
}

// ─── Card with press scale ────────────────────────────────────────────────────
class GCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? bg;
  final BorderRadius? radius;
  final bool bordered;
  final List<BoxShadow>? shadows;
  const GCard({
    super.key, required this.child,
    this.onTap, this.padding = const EdgeInsets.all(18),
    this.bg, this.radius, this.bordered = true, this.shadows,
  });
  @override State<GCard> createState() => _GCardState();
}
class _GCardState extends State<GCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext ctx) {
    final radius = widget.radius ?? BorderRadius.circular(26);
    final plain = widget.bg == null || widget.bg == C.white;
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp:   widget.onTap != null ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _pressed ? 0.975 : 1.0,
        // Frosted glass with a mint sheen + a neon hairline along the top-left.
        child: GGlass(
          radius: radius,
          gradient: plain
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.78), V.mint.withValues(alpha: 0.28)])
            : null,
          tint: plain ? null : widget.bg!.withValues(alpha: widget.bg!.a * 0.88),
          borderColor: widget.bordered ? Colors.white.withValues(alpha: 0.9) : Colors.transparent,
          shadows: _pressed ? const [] : (widget.shadows ?? [BoxShadow(color: V.deep.withValues(alpha: 0.08), blurRadius: 26, offset: const Offset(0, 12))]),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

// ─── Button ───────────────────────────────────────────────────────────────────
// Ink capsule with a neon glow and a lime arrow node on the right.
class GBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outline;
  final bool danger;
  final bool gold;
  final IconData? icon;
  final double h;
  final double? w;
  final double? fontSize;
  final Color? bg;
  final Color? labelColor;
  const GBtn({
    super.key, required this.label, this.onTap, this.loading = false,
    this.outline = false, this.danger = false, this.gold = false,
    this.icon, this.h = 54, this.w, this.fontSize, this.bg, this.labelColor,
  });
  @override State<GBtn> createState() => _GBtnState();
}
class _GBtnState extends State<GBtn> {
  bool _p = false;
  bool get _dis  => widget.onTap == null || widget.loading;
  // Brand buttons (default / forest) get the Verdant ink treatment.
  bool get _brand => !widget.danger && !widget.gold && (widget.bg == null || widget.bg == C.forest);
  Color get _base => widget.danger ? C.red : widget.gold ? C.gold : (widget.bg ?? V.ink);
  Color get _fg   => widget.labelColor ?? (widget.gold ? V.ink : Colors.white);

  static final _arrows = <IconData>{Icons.arrow_forward, Icons.arrow_forward_rounded, Icons.arrow_forward_ios_rounded, Icons.arrow_right_alt_rounded};

  @override
  Widget build(BuildContext ctx) {
    final fg = widget.outline ? (_brand ? V.deep : _base) : _fg;
    final node = _brand && !widget.outline && widget.h >= 44;
    // The lime node already is the arrow — don't show a second one.
    final icon = node && _arrows.contains(widget.icon) ? null : widget.icon;
    return GestureDetector(
      onTapDown:  !_dis ? (_) => setState(() => _p = true)  : null,
      onTapUp:    !_dis ? (_) { setState(() => _p = false); widget.onTap!(); } : null,
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _p ? 0.97 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _dis && !widget.loading ? 0.5 : 1,
          child: Container(
            width: widget.w ?? double.infinity, height: widget.h,
            decoration: BoxDecoration(
              color: widget.outline ? Colors.white.withValues(alpha: 0.5) : (_brand ? null : _base),
              gradient: widget.outline || !_brand ? null : const LinearGradient(
                begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [V.ink, V.deep, Color(0xFF145C36)]),
              borderRadius: BorderRadius.circular(99),
              border: widget.outline
                ? Border.all(color: (_brand ? V.leaf : _base).withValues(alpha: 0.6), width: 1.4)
                : Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: widget.outline || _dis ? [] : [
                BoxShadow(color: (_brand ? V.ink : _base).withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -4),
              ],
            ),
            child: widget.loading
              ? Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.outline ? V.deep : (_brand ? V.lime : _fg))))
              : Stack(alignment: Alignment.center, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: fg),
                      const SizedBox(width: 10),
                    ],
                    Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: vx(widget.fontSize ?? 15.5, w: FontWeight.w700, color: fg, ls: 0.2))),
                  ]),
                  if (node)
                    Positioned(right: 6, child: Container(
                      width: widget.h - 12, height: widget.h - 12,
                      decoration: const BoxDecoration(color: V.lime, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, size: 18, color: V.ink),
                    )),
                ]),
          ),
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────
// Glass pill with a glowing status dot.
class GBadge extends StatelessWidget {
  final String status;
  final bool small;
  const GBadge(this.status, {super.key, this.small = false});
  String get label => status.replaceAll('_', ' ').toUpperCase();
  @override
  Widget build(BuildContext ctx) {
    final c = C.statusFg(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(label, style: vx(small ? 9 : 10, w: FontWeight.w700, color: c, ls: 0.8)),
    );
  }
}

// ─── Skeleton shimmer ─────────────────────────────────────────────────────────
class GSkel extends StatelessWidget {
  final double w, h; final double r;
  const GSkel({super.key, required this.w, required this.h, this.r = 10});
  @override
  Widget build(BuildContext ctx) => Shimmer.fromColors(
    baseColor: V.mint.withValues(alpha: 0.5), highlightColor: Colors.white,
    child: Container(width: w, height: h,
      decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(r))));
}

class GSkelCard extends StatelessWidget {
  const GSkelCard({super.key});
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white)),
    child: Shimmer.fromColors(baseColor: V.mint.withValues(alpha: 0.6), highlightColor: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: const BoxDecoration(color: V.mint, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 14, decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(7))),
            const SizedBox(height: 8),
            Container(height: 11, width: 160, decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(5))),
          ])),
        ]),
        const SizedBox(height: 14),
        Container(height: 11, decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(5))),
        const SizedBox(height: 6),
        Container(height: 11, width: 200, decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(5))),
      ])),
  );
}

// ─── Animated toast ───────────────────────────────────────────────────────────
void showMsg(BuildContext ctx, String msg, {bool err = false, bool ok = false}) {
  final overlay = Overlay.of(ctx);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MsgBanner(msg: msg, err: err, ok: ok, dismiss: () {
      try { entry.remove(); } catch (_) {}
    }),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () { try { entry.remove(); } catch (_) {} });
}

class _MsgBanner extends StatefulWidget {
  final String msg; final bool err, ok; final VoidCallback dismiss;
  const _MsgBanner({required this.msg, required this.err, required this.ok, required this.dismiss});
  @override State<_MsgBanner> createState() => _MsgBannerState();
}
class _MsgBannerState extends State<_MsgBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: 400.ms);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, -1.3), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override void initState() {
    super.initState(); _c.forward();
    Future.delayed(2600.ms, () async { if (mounted) { await _c.reverse(); widget.dismiss(); } });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final col = widget.err ? C.red : widget.ok ? C.green : C.forest;
    final icon = widget.err ? Icons.error_outline_rounded
               : widget.ok  ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded;
    return Positioned(
      top: MediaQuery.of(ctx).padding.top + 10, left: 14, right: 14,
      child: SlideTransition(position: _slide, child: FadeTransition(opacity: _fade,
        child: Material(color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: V.ink.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: col == C.forest ? Colors.white.withValues(alpha: 0.12) : col.withValues(alpha: 0.6)),
              boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              Icon(icon, color: col == C.forest ? V.lime : col, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.msg,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white))),
            ]),
          )))));
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class GEmpty extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Widget? action;
  const GEmpty({super.key, required this.title, required this.sub, this.icon = Icons.inbox_outlined, this.action});
  @override
  Widget build(BuildContext ctx) => Center(child: Padding(
    padding: const EdgeInsets.all(36),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      VOrb(icon: icon, size: 72, dark: false)
        .animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: vx(19, w: FontWeight.w700, color: V.ink))
        .animate().fadeIn(delay: 100.ms),
      const SizedBox(height: 6),
      Text(sub, textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 13, color: V.fog, height: 1.55))
        .animate().fadeIn(delay: 150.ms),
      if (action != null) ...[
        const SizedBox(height: 22),
        action!.animate().fadeIn(delay: 200.ms),
      ],
    ]),
  ));
}

// ─── Section header ───────────────────────────────────────────────────────────
class GSec extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const GSec(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext ctx) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Expanded(child: Text(title, style: vx(18, w: FontWeight.w600, color: V.ink, ls: -0.2))),
    if (action != null && onAction != null)
      GestureDetector(onTap: onAction, child: Text(action!, style: vx(13, w: FontWeight.w600, color: V.leaf))),
  ]);
}

// ─── Input Field ─────────────────────────────────────────────────────────────
class GField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData? icon;
  final TextInputType keyboard;
  final bool isPass;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  const GField({
    super.key, required this.ctrl, required this.label, required this.hint,
    this.icon, this.keyboard = TextInputType.text, this.isPass = false,
    this.maxLines = 1, this.onChanged,
  });

  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(label.toUpperCase(), style: vx(10.5, w: FontWeight.w700, color: V.fog, ls: 1.4))),
    Container(
      height: maxLines != null && maxLines! > 1 ? null : 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [BoxShadow(color: V.deep.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: ctrl, keyboardType: keyboard, obscureText: isPass, maxLines: maxLines,
        onChanged: onChanged,
        cursorColor: V.leaf,
        style: p(15, w: FontWeight.w600, color: V.ink),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: V.fog.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          prefixIcon: icon != null ? Icon(icon, color: V.leaf, size: 20) : null,
          border:             InputBorder.none,
          enabledBorder:      InputBorder.none,
          focusedBorder:      InputBorder.none,
          errorBorder:        InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder:     InputBorder.none,
          filled:             false,
          isDense:            true,
        ),
      ),
    ),
  ]);
}


// ─── Premium floating cart bar — tap the bag to expand and remove items ───────
class GFloatingCartBar extends StatefulWidget {
  final int count;
  final double total;
  final VoidCallback onTap;
  final String? subtitle;
  const GFloatingCartBar({super.key, required this.count, required this.total, required this.onTap, this.subtitle});

  @override State<GFloatingCartBar> createState() => _GFloatingCartBarState();
}

class _GFloatingCartBarState extends State<GFloatingCartBar> {
  bool _expanded = false;

  String _imageUrl(Map<String, dynamic> prod) {
    if (prod['images'] is List && (prod['images'] as List).isNotEmpty) {
      final url = (prod['images'] as List).first.toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    final img = prod['image']?.toString();
    if (img != null && img.isNotEmpty && img != 'null') return img;
    return '';
  }

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();
    return Positioned(
      left: 16, right: 16, bottom: 16 + MediaQuery.of(ctx).padding.bottom,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0E5C2A), C.forest, Color(0xFF03411A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(color: C.forest.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 12)),
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Expanded(child: Text('YOUR CART', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.8))),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ctx.read<CartProvider>().clear();
                    showMsg(ctx, 'Cart cleared');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('Clear cart', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: C.gold)),
                  ),
                ),
              ]),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: cart.items.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                    itemBuilder: (_, i) {
                      final item = cart.items[i];
                      final prod = asMap(item['product']);
                      final qty = asInt(item['qty']);
                      final id = asInt(prod['id']);
                      final img = _imageUrl(prod);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img.isNotEmpty
                              ? Image.network(img, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 36, height: 36, color: Colors.white12, child: const Icon(Icons.eco_rounded, color: Colors.white54, size: 16)))
                              : Container(width: 36, height: 36, color: Colors.white12, child: const Icon(Icons.eco_rounded, color: Colors.white54, size: 16)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(asStr(prod['name']), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => ctx.read<CartProvider>().remove(id),
                            child: Container(
                              width: 26, height: 26, alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.remove_rounded, size: 15, color: Colors.white),
                            ),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$qty', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white))),
                          GestureDetector(
                            onTap: () => ctx.read<CartProvider>().add(prod),
                            child: Container(
                              width: 26, height: 26, alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Remove the whole line, regardless of quantity
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ctx.read<CartProvider>().removeLine(id);
                              showMsg(ctx, '${asStr(prod['name'])} removed from cart');
                            },
                            child: Container(
                              width: 26, height: 26, alignment: Alignment.center,
                              decoration: BoxDecoration(color: C.red.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
            ),
          ],
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.shopping_bag_rounded, color: Colors.white, size: _expanded ? 26 : 20),
                  if (!_expanded) Positioned(top: 2, right: 2, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(99)),
                    child: Text('${widget.count}', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: C.forest)),
                  )),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: widget.onTap,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.subtitle ?? '${widget.count} item${widget.count == 1 ? '' : 's'} added', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                Text('₹${widget.total.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              ]),
            )),
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.gold, Color(0xFFE0BE6E)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: C.gold.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View Cart', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1A0F00))),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1A0F00), size: 15),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 350.ms, curve: Curves.easeOutQuart).fadeIn(duration: 250.ms);
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────
// Floating dark bio-glass dock; the active tab expands into a lime capsule.
class GNavBar extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final int cartCount;
  const GNavBar({super.key, required this.idx, required this.onTap, this.cartCount = 0});

  static const _items = [
    (icon: Icons.spa_outlined,             active: Icons.spa_rounded,             label: 'Home'),
    (icon: Icons.calendar_month_outlined,  active: Icons.calendar_month_rounded,  label: 'Bookings'),
    (icon: Icons.storefront_outlined,      active: Icons.storefront_rounded,      label: 'Shop'),
  ];

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.of(ctx).padding.bottom > 0 ? MediaQuery.of(ctx).padding.bottom : 14),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(colors: [Color(0xF2102A1C), Color(0xED153A26)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(children: List.generate(_items.length, (i) {
            final sel = i == idx;
            final badge = i == 2 && cartCount > 0;
            return Expanded(
              flex: sel ? 5 : 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: sel ? 16 : 10),
                    decoration: BoxDecoration(
                      color: sel ? V.lime : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Icon(sel ? _items[i].active : _items[i].icon, size: 22, color: sel ? V.ink : Colors.white70),
                        if (badge) Positioned(top: -6, right: -9, child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: sel ? V.ink : V.lime, borderRadius: BorderRadius.circular(99)),
                          child: Text('$cartCount', textAlign: TextAlign.center,
                            style: vx(9, w: FontWeight.w800, color: sel ? V.lime : V.ink)),
                        )),
                      ]),
                      if (sel) ...[
                        const SizedBox(width: 8),
                        Flexible(child: Text(_items[i].label, maxLines: 1, overflow: TextOverflow.clip,
                          style: vx(13.5, w: FontWeight.w700, color: V.ink))),
                      ],
                    ]),
                  ),
                ),
              ),
            );
          })),
        ),
      ),
    ),
  );
}
