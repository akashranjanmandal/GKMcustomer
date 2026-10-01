import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// Green Makeover — full-bleed hero photo, ₹399 consultation offer, spaces we
// transform, what's included, a gallery of past work, packages, and a
// floating "Book consultation" button (WhatsApp).
class GreenMakeoverScreen extends StatefulWidget {
  const GreenMakeoverScreen({super.key});

  @override
  State<GreenMakeoverScreen> createState() => _GreenMakeoverScreenState();
}

class _GreenMakeoverScreenState extends State<GreenMakeoverScreen> {
  bool _canLoadImages = false;

  @override
  void initState() {
    super.initState();
    // Delay the gallery images until the slide-in transition completes.
    Future.delayed(350.ms, () {
      if (mounted) setState(() => _canLoadImages = true);
    });
  }

  void _openWhatsApp() async {
    const url =
        'https://wa.me/919643701701?text=Hi%20GharKaMali!%20I%20want%20to%20know%20about%20the%20Green%20Makeover%20package.';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  static const _spaces = [
    (title: 'Balcony', img: 'assets/images/balcony.jpeg'),
    (title: 'Indoor', img: 'assets/images/indoor.jpeg'),
    (title: 'Lawn', img: 'assets/images/Lawn.jpeg'),
    (title: 'Terrace', img: 'assets/images/terrace.jpeg'),
    (title: 'Backyard', img: 'assets/images/backyard.jpeg'),
    (title: 'Office', img: 'assets/images/office_mobile.jpeg'),
  ];

  static const _included = [
    (icon: Icons.architecture_outlined, title: 'Space planning', desc: 'Designed around your dimensions'),
    (icon: Icons.eco_outlined, title: 'Plant selection', desc: 'Right plants for your light'),
    (icon: Icons.format_paint_outlined, title: 'Designer pots', desc: 'Planters that suit your interiors'),
    (icon: Icons.auto_awesome_mosaic_outlined, title: 'Arrangement', desc: 'Stands and layered compositions'),
    (icon: Icons.local_shipping_outlined, title: 'Delivery', desc: 'Plants and materials, handled'),
    (icon: Icons.handyman_outlined, title: 'Installation', desc: 'Set up by trained gardeners'),
  ];

  static const _packages = [
    (title: 'Basic', price: '20,000', desc: 'Essential plants and standard pots for cosy spaces.', popular: false),
    (title: 'Premium', price: '35,000', desc: 'Curated design with designer pots and stands.', popular: true),
    (title: 'Luxury', price: '50,000', desc: 'Rare plants, imported pots and an architectural layout.', popular: false),
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final heroH = mq.size.height * 0.5;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
            SliverToBoxAdapter(child: _hero(heroH)),
            SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              _offer(),
              const SizedBox(height: 34),
              const VSection(title: 'Spaces we transform'),
              const SizedBox(height: 14),
              _spacesRow(),
              const SizedBox(height: 34),
              const VSection(title: "What's included"),
              const SizedBox(height: 14),
              _includedGrid(),
              const SizedBox(height: 34),
              const VSection(title: 'Our work'),
              const SizedBox(height: 14),
              _gallery(),
              const SizedBox(height: 34),
              const VSection(title: 'Packages'),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Every package is customised to your space and style.', style: p(13, color: V.fog)),
              ),
              const SizedBox(height: 14),
              for (final pk in _packages) _package(pk),
              SizedBox(height: mq.padding.bottom + 110),
            ])),
          ]),
          // Back button floating over the hero
          Positioned(
            top: mq.padding.top + 8, left: 12,
            child: VRoundBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
          ),
          // Floating CTA — no bar behind it
          Positioned(
            left: 20, right: 20, bottom: mq.padding.bottom + 16,
            child: GBtn(label: 'Book consultation', icon: Icons.chat_bubble_outline_rounded, onTap: _openWhatsApp),
          ).animate().slideY(begin: 1.5, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        ]),
      ),
    );
  }

  Widget _hero(double h) => SizedBox(
    height: h,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/img-3.jpeg', fit: BoxFit.cover, cacheWidth: 1200),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Colors.transparent, Color(0xE60B1F14)],
          stops: [0, 0.35, 1]))),
        Positioned(left: 22, right: 22, bottom: 26, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Green Makeover', style: vx(38, w: FontWeight.w600, color: Colors.white, ls: -1, h: 1)),
          const SizedBox(height: 8),
          Text('Turn any corner of your home or office into a garden — designed, planted and installed by our team.',
            style: p(13.5, color: Colors.white.withValues(alpha: 0.85), h: 1.45)),
        ]).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0)),
      ]),
    ),
  );

  Widget _offer() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: VGlassTile(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Start with a site visit', style: p(12.5, color: V.fog)),
          const SizedBox(height: 2),
          Text('₹399', style: vx(34, w: FontWeight.w600, color: V.ink, ls: -1, h: 1.05)),
          const SizedBox(height: 4),
          Text('A designer visits, measures and suggests a plan. Adjusted against your package.',
            style: p(12, color: V.fog, h: 1.4)),
        ])),
        const SizedBox(width: 12),
        const VOrb(icon: Icons.straighten_outlined, size: 52),
      ]),
    ),
  );

  Widget _spacesRow() => SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _spaces.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => Container(
        width: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(_spaces[i].img, fit: BoxFit.cover, cacheWidth: 360),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC0B1F14)], stops: [0.45, 1]))),
          Positioned(left: 12, bottom: 12, child: Text(_spaces[i].title, style: vx(16, w: FontWeight.w600, color: Colors.white))),
        ]),
      ),
    ),
  );

  Widget _includedGrid() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: VGlassTile(
      radius: 26,
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var r = 0; r < _included.length; r += 2) ...[
          if (r > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: V.ink.withValues(alpha: 0.07)),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _cell(_included[r])),
            Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 16), color: V.ink.withValues(alpha: 0.07)),
            Expanded(child: _cell(_included[r + 1])),
          ])),
        ],
      ]),
    ),
  );

  Widget _cell(({IconData icon, String title, String desc}) c) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(c.icon, size: 22, color: V.leaf),
      const SizedBox(height: 10),
      Text(c.title, style: vx(16, w: FontWeight.w600, color: V.ink, h: 1.2)),
      const SizedBox(height: 3),
      Text(c.desc, style: p(11.5, color: V.fog, h: 1.35)),
    ]),
  );

  Widget _gallery() => SizedBox(
    height: 300,
    child: !_canLoadImages
        ? const SizedBox.shrink()
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 16,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => Container(
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/img-${i + 1}.jpeg', fit: BoxFit.cover, cacheWidth: 660),
            ),
          ),
  );

  Widget _package(({String title, String price, String desc, bool popular}) pk) {
    final dark = pk.popular;
    final body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(pk.title, style: vx(21, w: FontWeight.w600, color: dark ? Colors.white : V.ink)),
          if (pk.popular) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
              child: Text('Most popular', style: p(10.5, w: FontWeight.w600, color: V.ink)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(pk.desc, style: p(12.5, color: dark ? Colors.white.withValues(alpha: 0.7) : V.fog, h: 1.4)),
      ])),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('from', style: p(11, color: dark ? Colors.white60 : V.fog)),
        Text('₹${pk.price}', style: vx(22, w: FontWeight.w600, color: dark ? Colors.white : V.ink)),
      ]),
    ]);
    const pad = EdgeInsets.fromLTRB(20, 18, 20, 18);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: _openWhatsApp,
        child: dark ? VPod(radius: 24, padding: pad, child: body) : GCard(padding: pad, radius: BorderRadius.circular(24), child: body),
      ),
    );
  }
}
