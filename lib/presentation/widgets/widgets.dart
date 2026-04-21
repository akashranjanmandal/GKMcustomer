import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/theme.dart';
export 'location_picker_sheet.dart';

// ─── Header ──────────────────────────────────────────────────────────────────
class GHeader extends StatelessWidget {
  final Widget child;
  final double pb;
  const GHeader({super.key, required this.child, this.pb = 36});
  @override
  Widget build(BuildContext ctx) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        stops: [0, 0.45, 1], colors: [C.forest, Color(0xFF1E5D31), Color(0xFF144D24)]),
    ),
    child: SafeArea(bottom: false, child: Stack(children: [
      Positioned(top: -60, right: -60,
        child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, color: C.gold.withOpacity(0.055)))),
      Positioned(bottom: -50, left: -40,
        child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03)))),
      Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, pb), child: child),
    ])),
  );
}

// ─── Info/Detail Row ──────────────────────────────────────────────────────────
class GDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const GDetailRow({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext ctx) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: const Color(0xFFF2F9F5), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: C.forest)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.3)),
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
  Widget build(BuildContext ctx) => GestureDetector(
    onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
    onTapUp:   widget.onTap != null ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      transform: Matrix4.identity()..scale(_pressed ? 0.974 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.bg ?? C.white,
        borderRadius: widget.radius ?? BorderRadius.circular(22),
        border: widget.bordered ? Border.all(color: Colors.black.withOpacity(0.05)) : null,
        boxShadow: _pressed ? [] : (widget.shadows ?? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))]),
      ),
      padding: widget.padding,
      child: widget.child,
    ),
  );
}

// ─── Button ───────────────────────────────────────────────────────────────────
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
    this.icon, this.h = 52, this.w, this.fontSize, this.bg, this.labelColor,
  });
  @override State<GBtn> createState() => _GBtnState();
}
class _GBtnState extends State<GBtn> {
  bool _p = false;
  Color get _base => widget.bg ?? (widget.danger ? C.red : widget.gold ? C.gold : C.forest);
  Color get _fg   => widget.labelColor ?? (widget.gold ? const Color(0xFF1A0F00) : Colors.white);
  bool  get _dis  => widget.onTap == null || widget.loading;

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTapDown:  !_dis ? (_) => setState(() => _p = true)  : null,
    onTapUp:    !_dis ? (_) { setState(() => _p = false); widget.onTap!(); } : null,
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      transform: Matrix4.identity()..scale(_p ? 0.97 : 1.0),
      transformAlignment: Alignment.center,
      width: widget.w ?? double.infinity, height: widget.h,
      decoration: BoxDecoration(
        color: widget.outline ? Colors.transparent
             : _dis ? _base.withOpacity(0.50) : _base,
        borderRadius: BorderRadius.circular(16),
        border: widget.outline ? Border.all(color: _base, width: 2) : Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: widget.outline || _dis ? [] :
          [BoxShadow(color: _base.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: widget.loading
        ? Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 3,
              color: widget.outline ? _base : _fg)))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 20, color: widget.outline ? _base : _fg),
              const SizedBox(width: 10),
            ],
            Text(widget.label, style: GoogleFonts.poppins(
              fontSize: widget.fontSize ?? 16, fontWeight: FontWeight.w800,
              color: widget.outline ? _base : _fg, letterSpacing: 0.2)),
          ]),
    ),
  );
}

// ─── Status badge ─────────────────────────────────────────────────────────────
class GBadge extends StatelessWidget {
  final String status;
  final bool small;
  const GBadge(this.status, {super.key, this.small = false});
  String get label => status.replaceAll('_', ' ').toUpperCase();
  @override
  Widget build(BuildContext ctx) => Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 4),
    decoration: BoxDecoration(color: C.statusBg(status), borderRadius: BorderRadius.circular(99)),
    child: Text(label, style: GoogleFonts.poppins(
      fontSize: small ? 8.5 : 9.5, fontWeight: FontWeight.w700,
      color: C.statusFg(status), letterSpacing: 0.4)),
  );
}

// ─── Skeleton shimmer ─────────────────────────────────────────────────────────
class GSkel extends StatelessWidget {
  final double w, h; final double r;
  const GSkel({super.key, required this.w, required this.h, this.r = 10});
  @override
  Widget build(BuildContext ctx) => Shimmer.fromColors(
    baseColor: C.border, highlightColor: C.subtle,
    child: Container(width: w, height: h,
      decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(r))));
}

class GSkelCard extends StatelessWidget {
  const GSkelCard({super.key});
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border)),
    child: Shimmer.fromColors(baseColor: C.border, highlightColor: C.subtle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(13))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 14, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(7))),
            const SizedBox(height: 8),
            Container(height: 11, width: 160, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(5))),
          ])),
        ]),
        const SizedBox(height: 14),
        Container(height: 11, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(5))),
        const SizedBox(height: 6),
        Container(height: 11, width: 200, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(5))),
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
              color: C.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: col, width: 4)),
              boxShadow: s3(),
            ),
            child: Row(children: [
              Icon(icon, color: col, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.msg,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: C.t2))),
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
      Container(width: 76, height: 76,
        decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(22)),
        child: Icon(icon, size: 34, color: C.t4))
        .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
      const SizedBox(height: 18),
      Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: C.t1))
        .animate().fadeIn(delay: 100.ms),
      const SizedBox(height: 6),
      Text(sub, textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 13, color: C.t3, height: 1.55))
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
  Widget build(BuildContext ctx) => Row(children: [
    Container(width: 3, height: 16,
      decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(99))),
    const SizedBox(width: 8),
    Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: C.t1))),
    if (action != null && onAction != null)
      GestureDetector(onTap: onAction, child: Text(action!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: C.forest))),
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
    if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54))),
    Container(
      height: maxLines != null && maxLines! > 1 ? null : 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border, width: 1.2),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: ctrl, keyboardType: keyboard, obscureText: isPass, maxLines: maxLines,
        onChanged: onChanged,
        style: p(15, w: FontWeight.w600, color: C.t1),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: C.t4, fontSize: 14, fontWeight: FontWeight.w400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: icon != null ? Icon(icon, color: C.forest.withOpacity(0.5), size: 20) : null,
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


// ─── Bottom nav ───────────────────────────────────────────────────────────────
class GNavBar extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  final int cartCount;
  const GNavBar({super.key, required this.idx, required this.onTap, this.cartCount = 0});

  static const _items = [
    (icon: Icons.home_outlined,           active: Icons.home_rounded,            label: 'Home'),
    (icon: Icons.calendar_month_outlined,  active: Icons.calendar_month_rounded,  label: 'Bookings'),
    (icon: Icons.qr_code_scanner_rounded, active: Icons.qr_code_scanner_rounded, label: 'Scan'),
    (icon: Icons.storefront_outlined,     active: Icons.storefront_rounded,      label: 'Shop'),
    (icon: Icons.person_outline_rounded,  active: Icons.person_rounded,          label: 'Me'),
  ];

  @override
  Widget build(BuildContext ctx) => Container(
    height: 70 + MediaQuery.of(ctx).padding.bottom,
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0,-4))],
    ),
    child: SafeArea(top: false,
      child: Row(children: List.generate(_items.length, (i) {
        final sel = i == idx;
        if (i == 2) {
          return Expanded(child: GestureDetector(
            onTap: () => onTap(i),
            child: Column(children: [
               Transform.translate(
                 offset: const Offset(0, -10),
                 child: Container(
                   padding: const EdgeInsets.all(12),
                   decoration: const BoxDecoration(
                     color: C.forest,
                     shape: BoxShape.circle,
                     boxShadow: [BoxShadow(color: C.forest, blurRadius: 12, offset: Offset(0, 4))],
                   ),
                   child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                 ),
               ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 1.seconds),
               const Text('Scan', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E5BB1))),
            ]),
          ));
        }
        // Shop tab (index 3) gets cart badge
        final showBadge = i == 3 && cartCount > 0;
        return Expanded(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { HapticFeedback.selectionClick(); onTap(i); },
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(sel ? _items[i].active : _items[i].icon,
                size: 24, color: sel ? C.forest : Colors.black45),
              if (showBadge) Positioned(top: -4, right: -6,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$cartCount',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                )),
            ]),
            const SizedBox(height: 4),
            Text(_items[i].label, style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? C.forest : Colors.black45)),
          ]),
        ));
      }))),
  );
}
