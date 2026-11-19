import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../theme/theme.dart';
import '../../widgets/cinematic.dart';
import '../../widgets/widgets.dart';

// Green Makeover — a scroll-driven film. Each "scene" pins to the screen while
// your scroll plays it, then releases:
//
//   1. Opening   the garden sits in a small window between "Green" and
//                "Makeover"; scrolling opens it to full screen as the words part.
//   2. Spaces    full-screen reel; each space wipes up over the last.
//   3. ₹399      the site-visit price counts up.
//   4. Included  cards slide up and stack on each other.
//   5. Our work  vertical scroll drives a horizontal film strip.
//   6. Packages  a 3D carousel.
//   7. Closing   the WhatsApp action.
//
// Everything is driven by scroll (or a one-shot intro), nothing loops, and each
// pinned scene computes its position from the scroll offset directly so it
// never lags a frame behind your finger.

const _wa = '919643701701';

Future<void> _whatsApp([String? pkg]) async {
  final msg = pkg == null
      ? 'Hi GharKaMali! I want to know about the Green Makeover.'
      : 'Hi GharKaMali! I want to know about the Green Makeover $pkg package.';
  try {
    await launchUrlString('https://wa.me/$_wa?text=${Uri.encodeComponent(msg)}', mode: LaunchMode.externalApplication);
  } catch (_) {}
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _seg(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

const _spaces = [
  (title: 'Balcony', img: 'assets/images/balcony.jpeg'),
  (title: 'Indoor', img: 'assets/images/indoor.jpeg'),
  (title: 'Lawn', img: 'assets/images/Lawn.jpeg'),
  (title: 'Terrace', img: 'assets/images/terrace.jpeg'),
  (title: 'Backyard', img: 'assets/images/backyard.jpeg'),
  (title: 'Office', img: 'assets/images/office_mobile.jpeg'),
];

const _work = [
  'assets/images/img-1.jpeg', 'assets/images/img-11.jpeg', 'assets/images/img-6.jpeg',
  'assets/images/img-2.jpeg', 'assets/images/img-10.jpeg', 'assets/images/img-14.jpeg',
  'assets/images/img-7.jpeg', 'assets/images/img-12.jpeg', 'assets/images/img-13.jpeg',
  'assets/images/img-15.jpeg',
];

class GreenMakeoverScreen extends StatefulWidget {
  const GreenMakeoverScreen({super.key});
  @override
  State<GreenMakeoverScreen> createState() => _GreenMakeoverScreenState();
}

class _GreenMakeoverScreenState extends State<GreenMakeoverScreen> with SingleTickerProviderStateMixin {
  final _sc = ScrollController();
  final _tick = ValueNotifier<int>(0);
  final _darkScene = ValueNotifier<bool>(true);
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();

  // Scene lengths, in screen heights.
  static const _openLen = 2.8;
  static const _reelLen = 1 + 1.15 * (6 - 1);

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      _tick.value++;
      final h = MediaQuery.of(context).size.height;
      _darkScene.value = _sc.offset < h * (_openLen + _reelLen - 1) + h * 0.9;
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _sc.dispose();
    _tick.dispose();
    _darkScene.dispose();
    super.dispose();
  }

  void _book() {
    HapticFeedback.mediumImpact();
    _whatsApp();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final ctaFrom = h * (_openLen + _reelLen - 1) + h * 0.8;

    final page = Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        CustomScrollView(
          controller: _sc,
          physics: const CinematicScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: PinnedScene(
              length: h * _openLen, scroll: _sc,
              builder: (t, _) => _Opening(t: t, intro: _intro, onBook: _book),
            )),
            SliverToBoxAdapter(child: PinnedScene(
              length: h * _reelLen, scroll: _sc,
              builder: (t, _) => _Reel(t: t),
            )),
            SliverToBoxAdapter(child: _Offer(tick: _tick, onBook: _book)),
            SliverToBoxAdapter(child: PinnedScene(
              length: _Included.step * (_Included.items.length - 1) + h,
              scroll: _sc,
              builder: (_, px) => _Included(px: px),
            )),
            SliverToBoxAdapter(child: PinnedScene(
              length: h + _Strip.travel(mq.size) * 1.6,
              scroll: _sc,
              builder: (t, _) => _Strip(t: t),
            )),
            SliverToBoxAdapter(child: _Packages(tick: _tick)),
            SliverToBoxAdapter(child: _Closing(tick: _tick, scroll: _sc, onBook: _book)),
          ],
        ),

        // Soft fade behind the status bar on the light scenes.
        Positioned(
          top: 0, left: 0, right: 0, height: mq.padding.top + 70,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _darkScene,
              builder: (_, dark, __) => AnimatedOpacity(
                opacity: dark ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFAF5F9F4), Color(0xD9F5F9F4), Color(0x00F5F9F4)], stops: [0, 0.6, 1]))),
              ),
            ),
          ),
        ),

        Positioned(
          top: mq.padding.top + 8, left: 12,
          child: VRoundBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
        ),

        // Floating CTA — only once the two opening scenes are over.
        Positioned(
          left: 20, right: 20, bottom: mq.padding.bottom + 16,
          child: AnimatedBuilder(
            animation: _sc,
            builder: (_, child) {
              final ready = _sc.hasClients && _sc.position.hasContentDimensions;
              final off = ready ? _sc.offset : 0.0;
              final max = ready ? _sc.position.maxScrollExtent : double.infinity;
              final show = off > ctaFrom && off < max - h * 0.55;
              return IgnorePointer(
                ignoring: !show,
                child: AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedSlide(
                    offset: show ? Offset.zero : const Offset(0, 0.6),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    child: child,
                  ),
                ),
              );
            },
            child: GBtn(label: 'Book consultation', icon: Icons.chat_bubble_outline_rounded, glass: true, onTap: _book),
          ),
        ),
      ]),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: _darkScene,
      builder: (_, dark, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
        child: child!,
      ),
      child: page,
    );
  }
}

// ─── Reveal-on-scroll (for the free-flowing sections) ───────────────────────
mixin _OnScreen<T extends StatefulWidget> on State<T> {
  ValueNotifier<int> get tick;
  bool shown = false;
  bool _pending = false;
  void onShow();

  void watch() {
    tick.addListener(_schedule);
    _schedule();
  }

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
    if (box.localToGlobal(Offset.zero).dy < MediaQuery.of(context).size.height * 0.85) {
      shown = true;
      tick.removeListener(_schedule);
      onShow();
    }
  }

  void unwatch() => tick.removeListener(_schedule);
}

// A line that rises out of its own mask once [on] turns true.
class _Rise extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool on;
  final int delayMs;
  const _Rise(this.text, {required this.style, required this.on, this.delayMs = 0});
  @override
  Widget build(BuildContext ctx) {
    final line = Text(text, style: style);
    if (!on) return Opacity(opacity: 0, child: line);
    return ClipRect(
      child: line.animate(delay: delayMs.ms)
          .slideY(begin: 1.1, end: 0, duration: 900.ms, curve: Curves.easeOutQuart)
          .fadeIn(duration: 400.ms),
    );
  }
}

// ─── 1. Opening ──────────────────────────────────────────────────────────────
class _Opening extends StatelessWidget {
  final double t;
  final AnimationController intro;
  final VoidCallback onBook;
  const _Opening({required this.t, required this.intro, required this.onBook});

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final w = mq.size.width, h = mq.size.height;
    final open = Curves.easeInOutCubic.transform(_seg(t, 0, 0.6));
    final caption = Curves.easeOutCubic.transform(_seg(t, 0.6, 0.8));
    final titleStyle = vx(math.min(68, w * 0.17), w: FontWeight.w600, color: Colors.white, ls: -2.4, h: 1);
    final winW0 = w * 0.66, winH0 = h * 0.38;

    return AnimatedBuilder(
      animation: intro,
      builder: (_, __) {
        final i = intro.value;
        final win = Curves.easeOutCubic.transform(_seg(i, 0, 0.7));
        final t1 = Curves.easeOutQuart.transform(_seg(i, 0.2, 0.75));
        final t2 = Curves.easeOutQuart.transform(_seg(i, 0.32, 0.87));
        final cue = _seg(i, 0.75, 1) * (1 - _seg(t, 0, 0.12));
        final winW = _lerp(winW0, w, open), winH = _lerp(winH0, h, open);
        final words = (1 - open * 1.6).clamp(0.0, 1.0);

        return ColoredBox(
          color: V.ink,
          child: Stack(children: [
            // The window onto the garden.
            Center(
              child: Opacity(
                opacity: win,
                child: Transform.scale(
                  scale: 0.86 + 0.14 * win,
                  child: SizedBox(
                    width: winW, height: winH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_lerp(28, 0, open)),
                      child: Transform.scale(
                        scale: _lerp(1.4, 1.04, open) + 0.08 * (1 - win),
                        child: Image.asset('assets/images/img-3.jpeg', fit: BoxFit.cover, cacheWidth: 1100),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Shade for the caption once the window is full screen.
            Opacity(
              opacity: caption,
              child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0xF20B1F14)], stops: [0, 0.35, 1]))),
            ),
            // "Green" above the window, "Makeover" below; they part as it opens.
            Positioned(
              left: 0, right: 0, top: h / 2 - winH0 / 2 - titleStyle.fontSize! - 22,
              child: Opacity(
                opacity: words * t1,
                child: Transform.translate(
                  offset: Offset(-w * 0.75 * open, (1 - t1) * 34),
                  child: Center(child: Text('Green', style: titleStyle)),
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, top: h / 2 + winH0 / 2 + 16,
              child: Opacity(
                opacity: words * t2,
                child: Transform.translate(
                  offset: Offset(w * 0.75 * open, (1 - t2) * 34),
                  child: Center(child: Text('Makeover', style: titleStyle)),
                ),
              ),
            ),
            // Caption over the full-screen garden.
            Positioned(
              left: 24, right: 24, bottom: mq.padding.bottom + 44,
              child: IgnorePointer(
                ignoring: caption < 0.6,
                child: Opacity(
                  opacity: caption,
                  child: Transform.translate(
                    offset: Offset(0, (1 - caption) * 40),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Turn any corner of your home or office into a garden.',
                        style: vx(31, w: FontWeight.w600, color: Colors.white, ls: -0.8, h: 1.08)),
                      const SizedBox(height: 12),
                      Text('Designed, planted and installed by our team.',
                        style: p(14.5, color: Colors.white.withValues(alpha: 0.85), h: 1.45)),
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: onBook,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                          decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Book a site visit · ₹399', style: p(13.5, w: FontWeight.w600, color: V.ink)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: V.ink),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            // Scroll cue.
            Positioned(
              left: 0, right: 0, bottom: mq.padding.bottom + 20,
              child: Opacity(
                opacity: cue,
                child: Column(children: [
                  Text('Scroll to see more', style: p(12.5, color: Colors.white.withValues(alpha: 0.7))),
                  Transform.translate(
                    offset: Offset(0, math.sin(_seg(i, 0.8, 1) * math.pi) * 6),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.7), size: 22),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── 2. Spaces reel ──────────────────────────────────────────────────────────
class _Reel extends StatelessWidget {
  final double t;
  const _Reel({required this.t});

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final n = _spaces.length;
    final f = t * (n - 1);
    final i = f.floor().clamp(0, n - 2);
    final local = f - i;
    // Hold on each space, then wipe to the next.
    final wipe = Curves.easeInOutCubic.transform(_seg(local, 0.45, 1.0));
    final cur = _spaces[i], next = _spaces[i + 1];

    Widget img(String path, double scale) => Transform.scale(
          scale: scale,
          child: Image.asset(path, fit: BoxFit.cover, cacheHeight: 1400, gaplessPlayback: true),
        );

    final title = vx(60, w: FontWeight.w600, color: Colors.white, ls: -2, h: 1);
    return ColoredBox(
      color: V.ink,
      child: Stack(fit: StackFit.expand, children: [
        img(cur.img, 1.14 - 0.1 * local),
        ClipRect(clipper: _WipeUp(wipe), child: img(next.img, 1.22 - 0.12 * wipe)),
        // A thin bright edge riding the wipe.
        if (wipe > 0 && wipe < 1)
          Align(
            alignment: Alignment(0, 1 - 2 * wipe),
            child: Container(height: 1.2, color: Colors.white.withValues(alpha: 0.55)),
          ),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xE60B1F14)],
          stops: [0, 0.22, 0.55, 1]))),

        // Top: label and progress.
        Positioned(
          top: mq.padding.top + 70, left: 24, right: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Spaces we transform', style: p(13.5, w: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
            const SizedBox(height: 12),
            Row(children: [
              for (var k = 0; k < n; k++) ...[
                if (k > 0) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(99)),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (f + 1 - k).clamp(0.0, 1.0),
                      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99))),
                    ),
                  ),
                ),
              ],
            ]),
          ]),
        ),

        // Bottom: the space's name, swapping with the wipe.
        Positioned(
          left: 24, right: 24, bottom: mq.padding.bottom + 56,
          child: ClipRect(
            child: SizedBox(
              height: 66,
              child: Stack(children: [
                Transform.translate(
                  offset: Offset(0, -66 * wipe),
                  child: Opacity(opacity: 1 - wipe, child: Text(cur.title, style: title)),
                ),
                Transform.translate(
                  offset: Offset(0, 66 * (1 - wipe)),
                  child: Opacity(opacity: wipe, child: Text(next.title, style: title)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _WipeUp extends CustomClipper<Rect> {
  final double t;
  _WipeUp(this.t);
  @override
  Rect getClip(Size s) => Rect.fromLTRB(0, s.height * (1 - t), s.width, s.height);
  @override
  bool shouldReclip(_WipeUp o) => o.t != t;
}

// ─── 3. ₹399 site visit ──────────────────────────────────────────────────────
class _Offer extends StatefulWidget {
  final ValueNotifier<int> tick;
  final VoidCallback onBook;
  const _Offer({required this.tick, required this.onBook});
  @override
  State<_Offer> createState() => _OfferState();
}

class _OfferState extends State<_Offer> with _OnScreen<_Offer> {
  @override
  ValueNotifier<int> get tick => widget.tick;
  @override
  void initState() { super.initState(); watch(); }
  @override
  void onShow() => setState(() {});
  @override
  void dispose() { unwatch(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 84, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Rise('Start with a site visit', style: p(16, w: FontWeight.w500, color: V.fog), on: shown),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: shown ? 399 : 0),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutExpo,
              builder: (_, v, __) => Text('₹${v.round()}', style: vx(112, w: FontWeight.w600, color: V.deep, ls: -6, h: 1)),
            ),
          ),
          const SizedBox(height: 8),
          _Rise('A designer visits, measures and suggests a plan.', style: p(15, color: V.ink, h: 1.45), on: shown, delayMs: 250),
          _Rise('Adjusted against your package.', style: p(15, color: V.fog, h: 1.45), on: shown, delayMs: 340),
          const SizedBox(height: 22),
          AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: AnimatedSlide(
              offset: shown ? Offset.zero : const Offset(0, 0.4),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              child: GestureDetector(onTap: widget.onBook, child: const VChip('Book site visit', onDark: false)),
            ),
          ),
        ]),
      );
}

// ─── 4. What's included: cards that slide up and stack ──────────────────────
class _Included extends StatelessWidget {
  final double px;
  const _Included({required this.px});

  static const step = 300.0;
  static const _cardH = 190.0;
  static const items = [
    (icon: Icons.architecture_outlined, title: 'Space planning', desc: 'Designed around your dimensions.'),
    (icon: Icons.eco_outlined, title: 'Plant selection', desc: 'The right plants for your light.'),
    (icon: Icons.format_paint_outlined, title: 'Designer pots', desc: 'Planters that suit your interiors.'),
    (icon: Icons.auto_awesome_mosaic_outlined, title: 'Arrangement', desc: 'Stands and layered compositions.'),
    (icon: Icons.local_shipping_outlined, title: 'Delivery', desc: 'Plants and materials, handled.'),
    (icon: Icons.handyman_outlined, title: 'Installation', desc: 'Set up by trained gardeners.'),
  ];

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final top = mq.padding.top + 140;
    final n = items.length;
    return Stack(children: [
      Positioned(
        top: mq.padding.top + 72, left: 24, right: 24,
        child: Text("What's included", style: vx(34, w: FontWeight.w600, color: V.ink, ls: -1, h: 1)),
      ),
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final y = math.max(top + i * 14, top + i * step - px);
          final covered = ((px - i * step) / step).clamp(0.0, (n - 1 - i).toDouble());
          return Positioned(
            top: y, left: 16, right: 16, height: _cardH,
            child: Transform.scale(
              scale: 1 - 0.04 * covered,
              alignment: Alignment.topCenter,
              child: _IncludedCard(i: i),
            ),
          );
        }),
    ]);
  }
}

class _IncludedCard extends StatelessWidget {
  final int i;
  const _IncludedCard({required this.i});
  @override
  Widget build(BuildContext ctx) {
    final it = _Included.items[i];
    final dark = i.isOdd;
    final fg = dark ? Colors.white : V.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: dark ? V.deep : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: dark ? null : Border.all(color: V.ink.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.1) : V.mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(it.icon, size: 22, color: dark ? V.lime : V.deep),
        ),
        const Spacer(),
        Text(it.title, style: vx(28, w: FontWeight.w600, color: fg, ls: -0.8, h: 1.05)),
        const SizedBox(height: 6),
        Text(it.desc, style: p(13.5, color: dark ? Colors.white.withValues(alpha: 0.75) : V.fog, h: 1.4)),
      ]),
    );
  }
}

// ─── 5. Our work: vertical scroll drives a horizontal film strip ────────────
class _Strip extends StatelessWidget {
  final double t;
  const _Strip({required this.t});

  static const _gap = 14.0;
  static double _tileH(Size s) => s.height * 0.5;
  static double _tileW(Size s) => _tileH(s) * 0.7;
  static double _rowW(Size s) => 24 * 2 + _work.length * (_tileW(s) + _gap) - _gap;
  static double travel(Size s) => math.max(0, _rowW(s) - s.width);

  void _open(BuildContext ctx, int i) {
    HapticFeedback.selectionClick();
    Navigator.of(ctx).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: _Viewer(initial: i)),
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final s = mq.size;
    final tw = _tileW(s), th = _tileH(s);
    final x = -travel(s) * t;
    return Stack(children: [
      Positioned(
        top: mq.padding.top + 72, left: 24, right: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Our work', style: vx(34, w: FontWeight.w600, color: V.ink, ls: -1, h: 1)),
          const SizedBox(height: 6),
          Text('Tap any photo to see it full screen.', style: p(13, color: V.fog)),
        ]),
      ),
      Positioned(
        top: mq.padding.top + 160, left: 0, width: _rowW(s), height: th,
        child: Transform.translate(
          offset: Offset(x, 0),
          child: Row(children: [
            const SizedBox(width: 24),
            for (var k = 0; k < _work.length; k++) ...[
              if (k > 0) const SizedBox(width: _gap),
              Builder(builder: (_) {
                // Each frame's photo drifts against the strip for depth.
                final cx = 24 + k * (tw + _gap) + tw / 2 + x;
                final rel = ((cx - s.width / 2) / s.width).clamp(-1.5, 1.5);
                return GestureDetector(
                  onTap: () => _open(ctx, k),
                  child: Hero(
                    tag: 'gm-${_work[k]}',
                    child: Container(
                      width: tw, height: th,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Transform.translate(
                          offset: Offset(-rel * 36, 0),
                          child: Transform.scale(scale: 1.22, child: Image.asset(_work[k], fit: BoxFit.cover, cacheWidth: 520)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ]),
        ),
      ),
      // Progress line.
      Positioned(
        left: 24, right: 24, top: mq.padding.top + 160 + th + 28,
        child: Container(
          height: 2,
          decoration: BoxDecoration(color: V.ink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.08 + 0.92 * t,
            child: Container(decoration: BoxDecoration(color: V.deep, borderRadius: BorderRadius.circular(99))),
          ),
        ),
      ),
    ]);
  }
}

class _Viewer extends StatefulWidget {
  final int initial;
  const _Viewer({required this.initial});
  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final _pc = PageController(initialPage: widget.initial);
  late int _i = widget.initial;
  double _drag = 0;

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black.withValues(alpha: (1 - _drag.abs() / 400).clamp(0.0, 1.0)),
        child: Stack(children: [
          GestureDetector(
            // Drag down (or up) to close.
            onVerticalDragUpdate: (d) => setState(() => _drag += d.primaryDelta ?? 0),
            onVerticalDragEnd: (d) {
              if (_drag.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
                Navigator.pop(ctx);
              } else {
                setState(() => _drag = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: PageView.builder(
                controller: _pc,
                itemCount: _work.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => Center(
                  child: Hero(
                    tag: 'gm-${_work[i]}',
                    child: Image.asset(_work[i], fit: BoxFit.contain, cacheWidth: 1200),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: mq.padding.top + 8, right: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: mq.padding.bottom + 20,
            child: Center(child: Text('${_i + 1} of ${_work.length}', style: p(13, color: Colors.white70))),
          ),
        ]),
      ),
    );
  }
}

// ─── 6. Packages: a 3D carousel ──────────────────────────────────────────────
class _Packages extends StatefulWidget {
  final ValueNotifier<int> tick;
  const _Packages({required this.tick});
  @override
  State<_Packages> createState() => _PackagesState();
}

class _PackagesState extends State<_Packages> with _OnScreen<_Packages> {
  static const _items = [
    (title: 'Basic', price: '20,000', img: 'assets/images/img-13.jpeg', desc: 'Essential plants and standard pots for cosy spaces.', popular: false),
    (title: 'Premium', price: '35,000', img: 'assets/images/img-11.jpeg', desc: 'Curated design with designer pots and stands.', popular: true),
    (title: 'Luxury', price: '50,000', img: 'assets/images/img-2.jpeg', desc: 'Rare plants, imported pots and an architectural layout.', popular: false),
  ];
  final _pc = PageController(viewportFraction: 0.8, initialPage: 1);

  @override
  ValueNotifier<int> get tick => widget.tick;
  @override
  void initState() { super.initState(); watch(); }
  @override
  void onShow() => setState(() {});
  @override
  void dispose() { unwatch(); _pc.dispose(); super.dispose(); }

  double get _page => _pc.hasClients && _pc.position.hasContentDimensions ? (_pc.page ?? 1) : 1;

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 40, bottom: 64),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Rise('Packages', style: vx(34, w: FontWeight.w600, color: V.ink, ls: -1, h: 1.05), on: shown),
              const SizedBox(height: 6),
              _Rise('Every package is customised to your space and style.', style: p(13, color: V.fog, h: 1.4), on: shown, delayMs: 120),
            ]),
          ),
          const SizedBox(height: 18),
          // Tabs that follow the carousel.
          AnimatedBuilder(
            animation: _pc,
            builder: (_, __) {
              final cur = _page.round();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  for (var k = 0; k < _items.length; k++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pc.animateToPage(k, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: vx(17, w: FontWeight.w600, color: k == cur ? V.ink : V.fog.withValues(alpha: 0.6)),
                          child: Text(_items[k].title),
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 700),
            child: AnimatedSlide(
              offset: shown ? Offset.zero : const Offset(0.15, 0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                height: 440,
                child: PageView.builder(
                  controller: _pc,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _items.length,
                  onPageChanged: (_) => HapticFeedback.selectionClick(),
                  itemBuilder: (_, i) => AnimatedBuilder(
                    animation: _pc,
                    builder: (_, child) {
                      final d = (_page - i).clamp(-1.0, 1.0);
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateY(d * 0.5),
                        child: Transform.scale(
                          scale: 1 - d.abs() * 0.1,
                          child: Opacity(opacity: 1 - d.abs() * 0.45, child: child),
                        ),
                      );
                    },
                    child: _PackageCard(item: _items[i]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _PackageCard extends StatelessWidget {
  final ({String title, String price, String img, String desc, bool popular}) item;
  const _PackageCard({required this.item});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: () => _whatsApp(item.title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(item.img, fit: BoxFit.cover, cacheWidth: 800),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xF00B1F14)], stops: [0.3, 0.92]))),
              if (item.popular)
                Positioned(
                  top: 18, left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
                    child: Text('Most popular', style: p(11, w: FontWeight.w600, color: V.ink)),
                  ),
                ),
              Positioned(
                left: 22, right: 22, bottom: 22,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title, style: vx(36, w: FontWeight.w600, color: Colors.white, ls: -1, h: 1)),
                  const SizedBox(height: 8),
                  Text(item.desc, style: p(13, color: Colors.white.withValues(alpha: 0.85), h: 1.45)),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('from', style: p(11.5, color: Colors.white70)),
                      Text('₹${item.price}', style: vx(26, w: FontWeight.w600, color: Colors.white, h: 1.1)),
                    ]),
                    const Spacer(),
                    const VChip('Enquire'),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      );
}

// ─── 7. Closing scene ────────────────────────────────────────────────────────
class _Closing extends StatefulWidget {
  final ValueNotifier<int> tick;
  final ScrollController scroll;
  final VoidCallback onBook;
  const _Closing({required this.tick, required this.scroll, required this.onBook});
  @override
  State<_Closing> createState() => _ClosingState();
}

class _ClosingState extends State<_Closing> with _OnScreen<_Closing> {
  @override
  ValueNotifier<int> get tick => widget.tick;
  @override
  void initState() { super.initState(); watch(); }
  @override
  void onShow() => Future.delayed(const Duration(milliseconds: 150), () { if (mounted) setState(() {}); });
  @override
  void dispose() { unwatch(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final h = mq.size.height * 0.68;
    final title = vx(44, w: FontWeight.w600, color: Colors.white, ls: -1.4, h: 1.02);
    return SizedBox(
      height: h + mq.padding.bottom,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: widget.scroll,
              builder: (_, child) {
                // Zooms out as it rises into view.
                var k = 0.0;
                final box = ctx.findRenderObject();
                if (box is RenderBox && box.hasSize && box.attached) {
                  k = (box.localToGlobal(Offset.zero).dy / mq.size.height).clamp(0.0, 1.0);
                }
                return Transform.scale(scale: 1.0 + 0.25 * k, child: child);
              },
              child: Image.asset('assets/images/terrace.jpeg', fit: BoxFit.cover, cacheWidth: 1000),
            ),
          ),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x330B1F14), Color(0xF20B1F14)], stops: [0.2, 0.85]))),
          Positioned(
            left: 24, right: 24, bottom: mq.padding.bottom + 30,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Rise('Book a', style: title, on: shown),
              _Rise('consultation', style: title, on: shown, delayMs: 120),
              const SizedBox(height: 12),
              _Rise('Tell us about your space on WhatsApp and we’ll plan a visit.',
                style: p(14, color: Colors.white.withValues(alpha: 0.85), h: 1.45), on: shown, delayMs: 260),
              const SizedBox(height: 22),
              AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: GBtn(label: 'Chat on WhatsApp', icon: Icons.chat_bubble_outline_rounded, onTap: widget.onBook),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
