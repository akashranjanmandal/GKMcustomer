import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

// PRIVÉ by GharKaMali — a members-only collection of sculptural planters.
//
// A press-and-hold gate opens onto a widescreen film frame, then a quiet,
// image-led page that ends in one action: reserve your seat.
//
// Type is deliberately restrained: Instrument Serif only for a few display
// lines, Inter for everything else, sentence case, normal tracking. Copy uses
// the client's own wording. All animation is one-shot or scroll-driven.

const _black = Color(0xFF080B09);
const _ivory = Color(0xFFEDE8DF);
const _muted = Color(0xFF9C978D);

const _waNumber = '919643701701';

TextStyle _display(double size, {Color color = _ivory, double h = 1.05}) =>
    GoogleFonts.instrumentSerif(fontSize: size, color: color, height: h, letterSpacing: -0.4);
TextStyle _text(double size, {Color color = _ivory, double h = 1.5, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.inter(fontSize: size, color: color, height: h, fontWeight: w, letterSpacing: -0.1);

// The PRIVÉ wordmark, set like the poster: Roman inscriptional capitals
// (Cinzel), tracked wide, in a soft gold.
class PriveWordmark extends StatelessWidget {
  final double size;
  final bool centered;
  const PriveWordmark({super.key, required this.size, this.centered = true});
  @override
  Widget build(BuildContext ctx) {
    final track = size * 0.14;
    return Padding(
      // letterSpacing also trails the last letter; offset it so the word sits centred.
      padding: EdgeInsets.only(left: centered ? track : 0),
      child: Text('PRIVÉ', style: GoogleFonts.cinzel(
        fontSize: size,
        height: 1,
        letterSpacing: track,
        fontWeight: FontWeight.w400,
        foreground: Paint()..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFF2DCA4), Color(0xFFCFA862), Color(0xFFE6C88A)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromLTWH(0, 0, size * 5, size)),
      )),
    );
  }
}

const _forms = [
  'assets/images/prive_pot1.jpg',
  'assets/images/prive_pot2.jpg',
  'assets/images/prive_pot3.jpg',
  'assets/images/prive_pot4.jpg',
];

// The five points from the collection brief, as written.
const _features = [
  'Rare pumice stone',
  'Handcrafted by artisans',
  'Architectural forms',
  'Interior & exterior luxury',
  'Bespoke sizes',
];

class PriveScreen extends StatefulWidget {
  const PriveScreen({super.key});
  @override
  State<PriveScreen> createState() => _PriveScreenState();
}

class _PriveScreenState extends State<PriveScreen> with TickerProviderStateMixin {
  final _sc = ScrollController();
  final _scrollTick = ValueNotifier<int>(0);
  bool _entered = false;

  late final AnimationController _gateIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final AnimationController _doors = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _film = AnimationController(vsync: this, duration: const Duration(seconds: 10));

  @override
  void initState() {
    super.initState();
    _sc.addListener(() => _scrollTick.value++);
  }

  @override
  void dispose() {
    _gateIn.dispose();
    _doors.dispose();
    _film.dispose();
    _sc.dispose();
    _scrollTick.dispose();
    super.dispose();
  }

  void _enter() {
    if (_entered) return;
    HapticFeedback.heavyImpact();
    setState(() => _entered = true);
    _doors.forward();
    _film.forward();
  }

  void _reserve() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _SeatSheet(),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final h = mq.size.height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _black,
        body: Stack(children: [
          CustomScrollView(
            controller: _sc,
            physics: _entered ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Hero(height: h, film: _film, scroll: _sc)),
              SliverToBoxAdapter(child: _Statement(tick: _scrollTick)),
              SliverToBoxAdapter(child: _FormsGrid(tick: _scrollTick)),
              SliverToBoxAdapter(child: _Material(tick: _scrollTick, scroll: _sc)),
              SliverToBoxAdapter(child: _Features(tick: _scrollTick)),
              SliverToBoxAdapter(child: _Finale(tick: _scrollTick, onReserve: _reserve)),
              SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 24)),
            ],
          ),

          // Static film grain (painted once, cached)
          const Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _GrainPainter())))),

          // Top fade for the status bar / back button
          Positioned(top: 0, left: 0, right: 0, height: mq.padding.top + 64,
            child: const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xE6080B09), Color(0x00080B09)]))))),

          // Floating reserve button — after the hero, hidden near the end
          Positioned(
            left: 20, right: 20, bottom: mq.padding.bottom + 14,
            child: AnimatedBuilder(
              animation: _sc,
              builder: (_, child) {
                final ready = _sc.hasClients && _sc.position.hasContentDimensions;
                final off = ready ? _sc.offset : 0.0;
                final max = ready ? _sc.position.maxScrollExtent : double.infinity;
                final show = _entered && off > h * 0.7 && off < max - 300;
                return IgnorePointer(
                  ignoring: !show,
                  child: AnimatedOpacity(
                    opacity: show ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    child: AnimatedSlide(offset: show ? Offset.zero : const Offset(0, 0.5), duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, child: child),
                  ),
                );
              },
              child: _ReserveButton(onTap: _reserve),
            ),
          ),

          // The gate
          AnimatedBuilder(
            animation: _doors,
            builder: (_, __) {
              if (_doors.isCompleted) return const SizedBox.shrink();
              final t = Curves.easeInOutCubic.transform(_doors.value);
              final w = mq.size.width;
              return Stack(children: [
                Positioned(top: 0, bottom: 0, left: -w / 2 * t, width: w / 2 + 1, child: const _DoorPanel(left: true)),
                Positioned(top: 0, bottom: 0, right: -w / 2 * t, width: w / 2 + 1, child: const _DoorPanel(left: false)),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _entered,
                    child: Opacity(opacity: (1 - t * 2.2).clamp(0.0, 1.0), child: _Gate(intro: _gateIn, onEnter: _enter)),
                  ),
                ),
              ]);
            },
          ),

          // Back
          Positioned(
            top: mq.padding.top + 4, left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.arrow_back_rounded, color: _ivory, size: 22),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Gate ────────────────────────────────────────────────────────────────────
class _DoorPanel extends StatelessWidget {
  final bool left;
  const _DoorPanel({required this.left});
  @override
  Widget build(BuildContext ctx) => DecoratedBox(
        decoration: BoxDecoration(
          color: _black,
          border: Border(
            right: left ? BorderSide(color: _ivory.withValues(alpha: 0.12), width: 0.5) : BorderSide.none,
            left: left ? BorderSide.none : BorderSide(color: _ivory.withValues(alpha: 0.12), width: 0.5),
          ),
        ),
      );
}

class _Gate extends StatefulWidget {
  final AnimationController intro;
  final VoidCallback onEnter;
  const _Gate({required this.intro, required this.onEnter});
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100), reverseDuration: const Duration(milliseconds: 350));
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _hold.addListener(() {
      final step = (_hold.value * 10).floor();
      if (_hold.status == AnimationStatus.forward && step > _lastTick) HapticFeedback.selectionClick();
      _lastTick = step;
    });
    _hold.addStatusListener((s) { if (s == AnimationStatus.completed) widget.onEnter(); });
  }

  @override
  void dispose() { _hold.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final title = CurvedAnimation(parent: widget.intro, curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    final rest = CurvedAnimation(parent: widget.intro, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: widget.intro,
      builder: (_, __) => Column(children: [
        const Spacer(flex: 5),
        Opacity(
          opacity: title.value,
          child: Transform.translate(offset: Offset(0, (1 - title.value) * 10), child: const PriveWordmark(size: 50)),
        ),
        const SizedBox(height: 16),
        Opacity(opacity: rest.value, child: Text('by GharKaMali', style: _text(13, color: _muted))),
        const Spacer(flex: 6),
        Opacity(
          opacity: rest.value,
          child: GestureDetector(
            onTapDown: (_) { HapticFeedback.lightImpact(); _hold.forward(); },
            onTapUp: (_) { if (!_hold.isCompleted) _hold.reverse(); },
            onTapCancel: () { if (!_hold.isCompleted) _hold.reverse(); },
            child: AnimatedBuilder(
              animation: _hold,
              builder: (_, __) => Column(children: [
                SizedBox(
                  width: 64, height: 64,
                  child: CustomPaint(
                    painter: _RingPainter(_hold.value),
                    child: Center(child: Container(
                      width: 6 + 8 * _hold.value, height: 6 + 8 * _hold.value,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _ivory.withValues(alpha: 0.6 + 0.4 * _hold.value)),
                    )),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Hold to enter', style: _text(12.5, color: _muted)),
              ]),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(ctx).padding.bottom + 44),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 1);
    canvas.drawArc(r, 0, 2 * math.pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _ivory.withValues(alpha: 0.18));
    if (t > 0) {
      canvas.drawArc(r, -math.pi / 2, 2 * math.pi * t, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..color = _ivory);
    }
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.t != t;
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final rnd = math.Random(7);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.03);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.05);
    final n = (s.width * s.height / 90).round();
    for (var i = 0; i < n; i++) {
      canvas.drawRect(Rect.fromLTWH(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height, 1, 1), i.isEven ? light : dark);
    }
  }
  @override
  bool shouldRepaint(_GrainPainter o) => false;
}

// ─── Reveal-on-scroll ────────────────────────────────────────────────────────
mixin _OnScreen<T extends StatefulWidget> on State<T> {
  ValueNotifier<int> get tick;
  bool shown = false;
  bool _pending = false;
  void onShow();

  void watch() {
    tick.addListener(_schedule);
    _schedule();
  }

  // Scroll notifications arrive before the viewport re-lays out, so measure
  // after the frame — otherwise the last tick of a fling reads stale positions.
  void _schedule() {
    if (_pending || shown) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) { _pending = false; _check(); });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _check() {
    if (shown || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    if (box.localToGlobal(Offset.zero).dy < MediaQuery.of(context).size.height * 0.88) {
      shown = true;
      tick.removeListener(_schedule);
      onShow();
    }
  }

  void unwatch() => tick.removeListener(_schedule);
}

class _Reveal extends StatefulWidget {
  final Widget child;
  final ValueNotifier<int> tick;
  final Duration delay;
  const _Reveal({required this.child, required this.tick, this.delay = Duration.zero});
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with _OnScreen<_Reveal> {
  bool _visible = false;
  @override
  ValueNotifier<int> get tick => widget.tick;
  @override
  void initState() { super.initState(); watch(); }
  @override
  void onShow() => Future.delayed(widget.delay, () { if (mounted) setState(() => _visible = true); });
  @override
  void dispose() { unwatch(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.06),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

// ─── Hero: widescreen frame that opens like an aperture ─────────────────────
class _Hero extends StatelessWidget {
  final double height;
  final AnimationController film;
  final ScrollController scroll;
  const _Hero({required this.height, required this.film, required this.scroll});

  @override
  Widget build(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    final frameH = w / 2.2;
    final aperture = CurvedAnimation(parent: film, curve: const Interval(0.03, 0.16, curve: Curves.easeInOutCubic));
    final text = CurvedAnimation(parent: film, curve: const Interval(0.14, 0.34, curve: Curves.easeOut));
    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: scroll,
        builder: (_, child) {
          final off = scroll.hasClients ? scroll.offset.clamp(0.0, height) : 0.0;
          return Transform.translate(offset: Offset(0, off * 0.3), child: Opacity(opacity: (1 - off / (height * 0.7)).clamp(0.0, 1.0), child: child));
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Spacer(flex: 4),
          SizedBox(
            width: w, height: frameH,
            child: AnimatedBuilder(
              animation: Listenable.merge([film, aperture]),
              builder: (_, __) {
                final p = Curves.easeOutSine.transform(film.value);
                return ClipRect(
                  clipper: _Aperture(aperture.value),
                  // Anchored low and never below 1.1x, so the poster's thin rule
                  // along the top edge of this crop stays out of frame.
                  child: Transform.scale(
                    scale: 1.22 - 0.12 * p,
                    alignment: const Alignment(0, 0.75),
                    child: Image.asset('assets/images/prive_scene.jpg', fit: BoxFit.cover, alignment: Alignment(-0.7 + 1.2 * p, 0.2)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: text,
            builder: (_, __) => Opacity(
              opacity: text.value,
              child: Transform.translate(
                offset: Offset(0, (1 - text.value) * 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const PriveWordmark(size: 46, centered: false),
                    const SizedBox(height: 14),
                    Text('Artisanal planters for curated spaces.', style: _text(15, color: _muted)),
                  ]),
                ),
              ),
            ),
          ),
          const Spacer(flex: 6),
        ]),
      ),
    );
  }
}

class _Aperture extends CustomClipper<Rect> {
  final double t;
  _Aperture(this.t);
  @override
  Rect getClip(Size s) {
    final half = s.height / 2 * math.max(t, 0.004);
    return Rect.fromLTRB(0, s.height / 2 - half, s.width, s.height / 2 + half);
  }
  @override
  bool shouldReclip(_Aperture o) => o.t != t;
}

// ─── Statement (client wording) ──────────────────────────────────────────────
class _Statement extends StatelessWidget {
  final ValueNotifier<int> tick;
  const _Statement({required this.tick});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 56),
        child: _Reveal(tick: tick, child: Text('A limited collection of sculptural planters.', style: _display(36, h: 1.1))),
      );
}

// ─── The forms: staggered grid; each frame unveils bottom-up ────────────────
class _FormsGrid extends StatelessWidget {
  final ValueNotifier<int> tick;
  const _FormsGrid({required this.tick});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [
            _Frame(img: _forms[0], tick: tick, ratio: 0.72),
            const SizedBox(height: 14),
            _Frame(img: _forms[2], tick: tick, ratio: 0.82),
          ])),
          const SizedBox(width: 14),
          Expanded(child: Column(children: [
            const SizedBox(height: 64),
            _Frame(img: _forms[1], tick: tick, ratio: 1.0, delay: 140),
            const SizedBox(height: 14),
            _Frame(img: _forms[3], tick: tick, ratio: 0.9, delay: 140),
          ])),
        ]),
      );
}

class _Frame extends StatefulWidget {
  final String img;
  final double ratio;
  final int delay;
  final ValueNotifier<int> tick;
  const _Frame({required this.img, required this.tick, required this.ratio, this.delay = 0});
  @override
  State<_Frame> createState() => _FrameState();
}

class _FrameState extends State<_Frame> with SingleTickerProviderStateMixin, _OnScreen<_Frame> {
  late final AnimationController _unveil = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  @override
  ValueNotifier<int> get tick => widget.tick;
  @override
  void initState() { super.initState(); watch(); }
  @override
  void onShow() => Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _unveil.forward(); });
  @override
  void dispose() { unwatch(); _unveil.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AspectRatio(
        aspectRatio: widget.ratio,
        child: AnimatedBuilder(
          animation: _unveil,
          builder: (_, child) {
            final t = Curves.easeInOutCubic.transform(_unveil.value);
            return ClipRect(clipper: _BottomUp(t), child: Transform.scale(scale: 1.12 - 0.12 * t, child: child));
          },
          child: Image.asset(widget.img, fit: BoxFit.cover),
        ),
      );
}

class _BottomUp extends CustomClipper<Rect> {
  final double t;
  _BottomUp(this.t);
  @override
  Rect getClip(Size s) => Rect.fromLTRB(0, s.height * (1 - t), s.width, s.height);
  @override
  bool shouldReclip(_BottomUp o) => o.t != t;
}

// ─── Material ────────────────────────────────────────────────────────────────
class _Material extends StatelessWidget {
  final ValueNotifier<int> tick;
  final ScrollController scroll;
  const _Material({required this.tick, required this.scroll});
  @override
  Widget build(BuildContext ctx) {
    final h = MediaQuery.of(ctx).size.height * 0.5;
    return SizedBox(
      height: h,
      child: Stack(fit: StackFit.expand, children: [
        ClipRect(child: RepaintBoundary(child: AnimatedBuilder(
          animation: scroll,
          builder: (_, child) {
            var drift = 0.0;
            final box = ctx.findRenderObject();
            if (box is RenderBox && box.hasSize && box.attached) {
              drift = (box.localToGlobal(Offset.zero).dy / MediaQuery.of(ctx).size.height - 0.5) * 80;
            }
            return Transform.translate(offset: Offset(0, drift), child: Transform.scale(scale: 1.25, child: child));
          },
          child: Opacity(opacity: 0.55, child: Image.asset('assets/images/prive_texture.jpg', fit: BoxFit.cover)),
        ))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_black, Color(0x00080B09), Color(0x00080B09), _black], stops: [0, 0.3, 0.7, 1]))),
      ]),
    );
  }
}

// ─── Features (client wording) ───────────────────────────────────────────────
class _Features extends StatelessWidget {
  final ValueNotifier<int> tick;
  const _Features({required this.tick});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _features.length; i++)
            _Reveal(
              tick: tick,
              delay: Duration(milliseconds: 90 * i),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: _ivory.withValues(alpha: 0.1)))),
                child: Text(_features[i], style: _text(17)),
              ),
            ),
        ]),
      );
}

// ─── Finale ──────────────────────────────────────────────────────────────────
class _Finale extends StatelessWidget {
  final ValueNotifier<int> tick;
  final VoidCallback onReserve;
  const _Finale({required this.tick, required this.onReserve});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
        child: _Reveal(tick: tick, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pre-order now', style: _display(40)),
          const SizedBox(height: 12),
          Text('Privé is available by pre-order. Reserve a seat and we’ll contact you on WhatsApp when the collection is ready.',
            style: _text(15, color: _muted)),
          const SizedBox(height: 28),
          _ReserveButton(onTap: onReserve),
          const SizedBox(height: 56),
          Center(child: Text('Privé by GharKaMali', style: _text(12, color: _muted.withValues(alpha: 0.7)))),
        ])),
      );
}

class _ReserveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ReserveButton({required this.onTap});
  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _down = false;
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 54,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _ivory, borderRadius: BorderRadius.circular(2)),
            child: Text('Reserve your seat', style: _text(15, color: _black, w: FontWeight.w500)),
          ),
        ),
      );
}

// ─── Seat sheet ──────────────────────────────────────────────────────────────
class _SeatSheet extends StatelessWidget {
  const _SeatSheet();

  Future<void> _send(BuildContext ctx) async {
    HapticFeedback.mediumImpact();
    const msg = 'Hello GharKaMali, I would like to reserve my seat for Privé.';
    var ok = false;
    try {
      ok = await launchUrlString('https://wa.me/$_waNumber?text=${Uri.encodeComponent(msg)}', mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (ok && ctx.mounted) Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).padding.bottom + 22),
        decoration: const BoxDecoration(
          color: Color(0xFF111512),
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _ivory.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 24),
          Text('Reserve your seat', style: _display(32)),
          const SizedBox(height: 10),
          Text('We’ll message you on WhatsApp to confirm your reservation. No payment is needed now.',
            style: _text(15, color: _muted)),
          const SizedBox(height: 26),
          GestureDetector(
            onTap: () => _send(ctx),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _ivory, borderRadius: BorderRadius.circular(2)),
              child: Text('Continue on WhatsApp', style: _text(15, color: _black, w: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now', style: _text(14, color: _muted)),
          )),
        ]),
      );
}
