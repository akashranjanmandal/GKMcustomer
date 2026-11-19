import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../widgets/cinematic.dart';

// PRIVÉ by GharKaMali — a members-only collection of sculptural planters.
//
// Set on the poster's forest green with a warm light from the top right.
// A swipe parts the doors onto a widescreen film frame, then an image-led page
// that ends in one action: reserve your seat.
//
// Type: the PRIVÉ wordmark in Cinzel (as on the poster), Instrument Serif for
// a few headings, Inter for everything else. All animation is one-shot or
// scroll-driven — nothing loops.

const _green = Color(0xFF1F3D30);
const _panel = Color(0xFF284A3B);
const _ink = Color(0xFF13281D);
const _ivory = Color(0xFFF6F1E7);
const _muted = Color(0xFFC6CFC3);
const _gold = Color(0xFFDDBF82);

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
          colors: [Color(0xFFF6E3B0), Color(0xFFD6B26C), Color(0xFFEBD096)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromLTWH(0, 0, size * 5, size)),
      )),
    );
  }
}

// The GharKaMali logo in gold, as on the poster. Cropped above the small
// tagline, which turns into an unreadable smudge at these sizes.
class PriveLogo extends StatelessWidget {
  final double width;
  const PriveLogo({super.key, this.width = 120});
  @override
  Widget build(BuildContext ctx) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.835,
          child: Image.asset('assets/images/logo.png',
              width: width, cacheWidth: (width * 3).round(), filterQuality: FilterQuality.medium),
        ),
      );
}

// "Scroll to see more" with a chevron.
class _ScrollCue extends StatelessWidget {
  final double nudge;
  const _ScrollCue({this.nudge = 0});
  @override
  Widget build(BuildContext ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Scroll to see more', style: _text(13, color: _muted)),
        const SizedBox(height: 4),
        Transform.translate(
          offset: Offset(0, nudge),
          child: const Icon(Icons.keyboard_arrow_down_rounded, color: _gold, size: 24),
        ),
      ]);
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

  late final AnimationController _gateIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  late final AnimationController _doors = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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

  // ── Gate: swipe up (or tap) to part the doors ──
  void _dragGate(DragUpdateDetails d, double h) {
    if (_entered) return;
    _doors.value = (_doors.value - (d.primaryDelta ?? 0) / (h * 0.45)).clamp(0.0, 1.0);
  }

  void _releaseGate(DragEndDetails d) {
    if (_entered) return;
    if (_doors.value > 0.28 || (d.primaryVelocity ?? 0) < -500) {
      _open();
    } else {
      _doors.animateBack(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _open() {
    if (_entered) return;
    HapticFeedback.mediumImpact();
    setState(() => _entered = true);
    _doors.animateTo(1, curve: Curves.easeOutCubic);
    _film.forward();
  }

  void _reserve() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
        backgroundColor: _green,
        body: Stack(children: [
          CustomScrollView(
            controller: _sc,
            physics: _entered ? const CinematicScrollPhysics() : const NeverScrollableScrollPhysics(),
            slivers: [
              // Both opening scenes pin while you scroll, so neither can be skipped past.
              SliverToBoxAdapter(child: PinnedScene(length: h * 1.9, scroll: _sc, builder: (t, _) => _Hero(film: _film, t: t))),
              SliverToBoxAdapter(child: PinnedScene(length: h * 1.9, scroll: _sc, builder: (t, _) => _Statement(t: t))),
              SliverToBoxAdapter(child: _FormsGrid(tick: _scrollTick)),
              SliverToBoxAdapter(child: _Material(scroll: _sc)),
              SliverToBoxAdapter(child: _Features(tick: _scrollTick)),
              SliverToBoxAdapter(child: _Finale(tick: _scrollTick, onReserve: _reserve)),
              SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 24)),
            ],
          ),

          // Top fade for the status bar / back button
          Positioned(top: 0, left: 0, right: 0, height: mq.padding.top + 64,
            child: const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xE61F3D30), Color(0x001F3D30)]))))),

          // Floating reserve button — after the hero, hidden near the end
          Positioned(
            left: 20, right: 20, bottom: mq.padding.bottom + 14,
            child: AnimatedBuilder(
              animation: _sc,
              builder: (_, child) {
                final ready = _sc.hasClients && _sc.position.hasContentDimensions;
                final off = ready ? _sc.offset : 0.0;
                final max = ready ? _sc.position.maxScrollExtent : double.infinity;
                final show = _entered && off > h * 2.75 && off < max - 300;
                return IgnorePointer(
                  ignoring: !show,
                  child: AnimatedOpacity(
                    opacity: show ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    child: AnimatedSlide(offset: show ? Offset.zero : const Offset(0, 0.5), duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, child: child),
                  ),
                );
              },
              child: _ReserveButton(onTap: _reserve, shadow: true),
            ),
          ),

          // The gate
          AnimatedBuilder(
            animation: _doors,
            builder: (_, __) {
              if (_doors.isCompleted) return const SizedBox.shrink();
              final t = _doors.value;
              final w = mq.size.width;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) { if (!_entered) HapticFeedback.selectionClick(); },
                onVerticalDragUpdate: (d) => _dragGate(d, h),
                onVerticalDragEnd: _releaseGate,
                onTap: _open,
                child: Stack(children: [
                  Positioned(top: 0, bottom: 0, left: -w / 2 * t, width: w / 2 + 1, child: const _DoorPanel(left: true)),
                  Positioned(top: 0, bottom: 0, right: -w / 2 * t, width: w / 2 + 1, child: const _DoorPanel(left: false)),
                  Positioned.fill(
                    child: Opacity(
                      opacity: (1 - t * 2.4).clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(0, -t * 60), child: _Gate(intro: _gateIn)),
                    ),
                  ),
                ]),
              );
            },
          ),

          // Warm light from the top right, as on the poster (static).
          const Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(1.1, -0.9), radius: 1.3,
              colors: [Color(0x26F2C77E), Color(0x00F2C77E)]),
          ))))),

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
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0xFF1B3729), _green],
          ),
        ),
      );
}

class _Gate extends StatelessWidget {
  final AnimationController intro;
  const _Gate({required this.intro});

  @override
  Widget build(BuildContext ctx) {
    final logo = CurvedAnimation(parent: intro, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    final title = CurvedAnimation(parent: intro, curve: const Interval(0.15, 0.55, curve: Curves.easeOut));
    final line = CurvedAnimation(parent: intro, curve: const Interval(0.3, 0.65, curve: Curves.easeOut));
    final cue = CurvedAnimation(parent: intro, curve: const Interval(0.8, 1.0, curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: intro,
      builder: (_, __) => Column(children: [
        const Spacer(flex: 4),
        Opacity(opacity: logo.value, child: const PriveLogo(width: 118)),
        const SizedBox(height: 34),
        Opacity(
          opacity: title.value,
          child: Transform.translate(offset: Offset(0, (1 - title.value) * 10), child: const PriveWordmark(size: 52)),
        ),
        const SizedBox(height: 18),
        Opacity(opacity: line.value, child: Text('Artisanal planters for curated spaces.', style: _text(15.5, color: _ivory))),
        const Spacer(flex: 3),
        _Arches(intro: intro),
        const Spacer(flex: 3),
        Opacity(opacity: cue.value, child: _ScrollCue(nudge: math.sin(cue.value * math.pi) * 6)),
        SizedBox(height: MediaQuery.of(ctx).padding.bottom + 26),
      ]),
    );
  }
}

// Four arched windows onto the collection, echoing the arch in the poster.
// They rise in one after another as the page opens.
class _Arches extends StatelessWidget {
  final AnimationController intro;
  const _Arches({required this.intro});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < _forms.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: Builder(builder: (_) {
              final t = Curves.easeOutCubic.transform(((intro.value - 0.4 - i * 0.08) / 0.32).clamp(0.0, 1.0));
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 18),
                  child: AspectRatio(
                    aspectRatio: 0.62,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(200), bottom: Radius.circular(3)),
                        border: Border.all(color: _gold.withValues(alpha: 0.45), width: 0.8),
                      ),
                      child: Image.asset(_forms[i], fit: BoxFit.cover, cacheWidth: 300),
                    ),
                  ),
                ),
              );
            })),
          ],
        ]),
      );
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
  const _Reveal({required this.child, required this.tick});
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
  void onShow() => setState(() => _visible = true);
  @override
  void dispose() { unwatch(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.06),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

// ─── Hero: widescreen frame that opens like an aperture ─────────────────────
class _Hero extends StatelessWidget {
  final AnimationController film;
  final double t; // progress through the pinned scene
  const _Hero({required this.film, required this.t});

  @override
  Widget build(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    final frameH = w / 2.2;
    final aperture = CurvedAnimation(parent: film, curve: const Interval(0.02, 0.14, curve: Curves.easeInOutCubic));
    final text = CurvedAnimation(parent: film, curve: const Interval(0.1, 0.28, curve: Curves.easeOut));
    final cue = CurvedAnimation(parent: film, curve: const Interval(0.26, 0.4, curve: Curves.easeOut));
    // Holds still for most of the pin, then lifts and fades into the next scene.
    final out = Curves.easeInCubic.transform(((t - 0.62) / 0.38).clamp(0.0, 1.0));
    final cueOut = (1 - t * 5).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -60 * out),
      child: Opacity(
        opacity: 1 - out,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Spacer(flex: 4),
          SizedBox(
            width: w, height: frameH,
            child: AnimatedBuilder(
              animation: film,
              builder: (_, __) {
                final p = Curves.easeOutSine.transform(film.value);
                return ClipRect(
                  clipper: _Aperture(aperture.value),
                  // Anchored low and never below 1.1x, so the poster's thin rule
                  // along the top edge of this crop stays out of frame.
                  child: Transform.scale(
                    scale: 1.22 - 0.12 * p + 0.08 * t,
                    alignment: const Alignment(0, 0.75),
                    child: Image.asset('assets/images/prive_scene.jpg', fit: BoxFit.cover, alignment: Alignment(-0.7 + 1.2 * p, 0.2)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
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
                    const SizedBox(height: 16),
                    Text('Artisanal planters for curated spaces.', style: _text(16, color: _ivory)),
                    const SizedBox(height: 4),
                    Text('by GharKaMali', style: _text(14, color: _muted)),
                  ]),
                ),
              ),
            ),
          ),
          const Spacer(flex: 5),
          AnimatedBuilder(
            animation: cue,
            builder: (_, __) => Opacity(
              opacity: cue.value * cueOut,
              child: Center(child: _ScrollCue(nudge: math.sin(cue.value * math.pi) * 6)),
            ),
          ),
          const SizedBox(height: 28),
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
  final double t; // progress through the pinned scene
  const _Statement({required this.t});

  static const _words = ['A', 'limited', 'collection', 'of', 'sculptural', 'planters.'];

  @override
  Widget build(BuildContext ctx) {
    final n = _words.length;
    final out = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
    return Opacity(
      opacity: 1 - out,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: const Alignment(-1, -0.05),
          child: Text.rich(TextSpan(children: [
            for (var k = 0; k < n; k++)
              TextSpan(
                text: k == n - 1 ? _words[k] : '${_words[k]} ',
                style: _display(46, h: 1.12, color: _ivory.withValues(
                  // Each word brightens in turn across the first 75% of the scene.
                  alpha: 0.16 + 0.84 * ((t - k * 0.11) / 0.14).clamp(0.0, 1.0),
                )),
              ),
          ])),
        ),
      ),
    );
  }
}

// ─── The forms: staggered grid; each frame unveils bottom-up ────────────────
class _FormsGrid extends StatelessWidget {
  final ValueNotifier<int> tick;
  const _FormsGrid({required this.tick});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 64),
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
  late final AnimationController _unveil = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
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

// ─── Material: the stone texture as a quiet interlude ───────────────────────
class _Material extends StatelessWidget {
  final ScrollController scroll;
  const _Material({required this.scroll});
  @override
  Widget build(BuildContext ctx) {
    final h = MediaQuery.of(ctx).size.height * 0.42;
    return SizedBox(
      height: h,
      child: Stack(fit: StackFit.expand, children: [
        ClipRect(child: RepaintBoundary(child: AnimatedBuilder(
          animation: scroll,
          builder: (_, child) {
            var drift = 0.0;
            final box = ctx.findRenderObject();
            if (box is RenderBox && box.hasSize && box.attached) {
              drift = (box.localToGlobal(Offset.zero).dy / MediaQuery.of(ctx).size.height - 0.5) * 70;
            }
            return Transform.translate(offset: Offset(0, drift), child: Transform.scale(scale: 1.25, child: child));
          },
          child: Opacity(opacity: 0.85, child: Image.asset('assets/images/prive_texture.jpg', fit: BoxFit.cover)),
        ))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_green, Color(0x001F3D30), Color(0x001F3D30), _green], stops: [0, 0.25, 0.75, 1]))),
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
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        child: _Reveal(
          tick: tick,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _gold.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < _features.length; i++)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: _ivory.withValues(alpha: 0.12)))),
                  child: Text(_features[i], style: _text(17)),
                ),
            ]),
          ),
        ),
      );
}

// ─── Finale ──────────────────────────────────────────────────────────────────
class _Finale extends StatelessWidget {
  final ValueNotifier<int> tick;
  final VoidCallback onReserve;
  const _Finale({required this.tick, required this.onReserve});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: _Reveal(tick: tick, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pre-order now', style: _display(42)),
          const SizedBox(height: 12),
          Text('Privé is available by pre-order. Reserve a seat and we’ll contact you on WhatsApp when the collection is ready.',
            style: _text(15.5, color: _muted)),
          const SizedBox(height: 28),
          _ReserveButton(onTap: onReserve),
          const SizedBox(height: 56),
          const Center(child: Opacity(opacity: 0.85, child: PriveLogo(width: 84))),
        ])),
      );
}

class _ReserveButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool shadow;
  const _ReserveButton({required this.onTap, this.shadow = false});
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
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(4),
              boxShadow: widget.shadow ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))] : null,
            ),
            child: Text('Reserve your seat', style: _text(15.5, color: _ink, w: FontWeight.w600)),
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
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.35), width: 0.8)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _ivory.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 24),
          Text('Reserve your seat', style: _display(34)),
          const SizedBox(height: 10),
          Text('We’ll message you on WhatsApp to confirm your reservation. No payment is needed now.',
            style: _text(15.5, color: _muted)),
          const SizedBox(height: 26),
          GestureDetector(
            onTap: () => _send(ctx),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(4)),
              child: Text('Continue on WhatsApp', style: _text(15.5, color: _ink, w: FontWeight.w600)),
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
