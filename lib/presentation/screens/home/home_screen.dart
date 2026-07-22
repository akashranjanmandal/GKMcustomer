import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/services/auth.dart';
import '../../../data/services/cart_provider.dart';
import '../shop/shop_screen.dart';
import '../../../data/services/api.dart';
import '../../../data/services/location_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) navTo;
  const HomeScreen({super.key, required this.navTo});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  final _api = Api();
  bool _loading = true;
  List<dynamic> _plans = [];
  List<dynamic> _products = [];
  int _notifCount = 0;
  final _scrollCtrl = ScrollController();
  bool _navCollapsed = false;

  @override void initState() {
    super.initState();
    _loadAll();
    _scrollCtrl.addListener(() {
      final collapsed = _scrollCtrl.offset > (MediaQuery.of(context).size.height * 0.30 - 90);
      if (collapsed != _navCollapsed) setState(() => _navCollapsed = collapsed);
    });
  }

  @override void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    try {
      final r = await Future.wait([
        _api.getPlans().catchError((_) => []),
        _api.getShopProducts(limit: 5).catchError((_) => []),
        _api.getNotifications().catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = asList(r[0]);
        _products = asList(r[1]);
        final notifs = asList(r[2]);
        _notifCount = notifs.where((e) => asBool(asMap(e)['is_read']) == false).length;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();
    final heroH = MediaQuery.of(ctx).size.height * 0.30;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: _loadAll, color: C.forest,
          child: CustomScrollView(controller: _scrollCtrl, slivers: [
            _buildHeroSliver(ctx, heroH),
            SliverToBoxAdapter(child: Column(children: [
              const SizedBox(height: 24),
              _buildTwoColumnCards(ctx),
              const SizedBox(height: 40),
              _buildQuickActions(ctx),
              const SizedBox(height: 40),
              _buildShopSection(ctx),
              const SizedBox(height: 40),
              _buildPlansSection(ctx),
              const SizedBox(height: 40),
              _buildPromotionsSection(ctx),
              const SizedBox(height: 32),
              _buildFooter(ctx),
              const SizedBox(height: 28),
            ])),
          ]),
        ),
        if (cart.count > 0) _buildCartBar(ctx, cart.count, cart.total),
      ]),
    );
  }

  // ── Hero image slider with the top nav overlaid directly on top of it ─────
  // The nav (address / notifications / profile) sits over the hero images —
  // once the hero scrolls away, the pinned bar crossfades to a plain white nav.
  Widget _buildHeroSliver(BuildContext ctx, double heroH) {
    final collapsed = _navCollapsed;
    final fg = collapsed ? C.t1 : Colors.white;
    final fgMuted = collapsed ? C.t3 : Colors.white70;
    final chipBg = collapsed ? C.forest.withOpacity(0.08) : Colors.white.withOpacity(0.22);

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: heroH,
      collapsedHeight: 60,
      backgroundColor: collapsed ? Colors.white : Colors.transparent,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroSlider(ctx),
      ),
      title: Consumer<LocationProvider>(builder: (ctx, lp, _) => GestureDetector(
        onTap: () {
          if (lp.locations.isNotEmpty) {
            showSavedLocations(ctx);
          } else {
            showLocationPicker(ctx).then((loc) { if (loc != null) lp.save(loc); });
          }
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.location_on_rounded, color: fg, size: 16)),
          const SizedBox(width: 8),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Deliver to', style: p(10, w: FontWeight.w600, color: fgMuted)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(lp.label, style: p(13, w: FontWeight.w800, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.keyboard_arrow_down_rounded, color: fgMuted, size: 16),
            ]),
          ])),
        ]),
      )),
      actions: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(ctx, '/notifications'),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
            child: Stack(clipBehavior: Clip.none, children: [
              Icon(Icons.notifications_outlined, color: fg, size: 18),
              if (_notifCount > 0) Positioned(top: -3, right: -5, child: Container(padding: const EdgeInsets.all(3.5), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)))),
            ]),
          ),
        ),
        Consumer<AuthProvider>(builder: (ctx, auth, _) => GestureDetector(
          onTap: () => widget.navTo(4),
          child: Container(
            margin: const EdgeInsets.only(right: 16, left: 10),
            width: 34, height: 34,
            decoration: BoxDecoration(color: C.forest, shape: BoxShape.circle, border: Border.all(color: collapsed ? C.border : Colors.white, width: 1.5)),
            child: ClipOval(child: auth.profileImage != null
              ? Image.network(auth.profileImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white, size: 18))
              : const Icon(Icons.person_rounded, color: Colors.white, size: 18)),
          ),
        )),
      ],
    );
  }

  // ── Hero image slider — fills the flexible space above ─────────────────────
  Widget _buildHeroSlider(BuildContext ctx) => _HeroSlider(
    images: const [
      'assets/images/marketting-1.jpeg',
      'assets/images/marketting-2.jpeg',
      'assets/images/marketting-3.jpeg',
      'assets/images/marketting-4.jpeg',
      'assets/images/marketting-5.jpeg',
    ],
  );

  // ── Two light, premium action cards ─────────────────────────────────────
  Widget _buildTwoColumnCards(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Expanded(child: _HeroCard(
        title: 'Schedule a Visit',
        icon: Icons.bolt_rounded,
        iconColor: C.forest,
        gradient: const [Color(0xFFF3FBF4), Color(0xFFE3F5E8)],
        btnLabel: 'Book',
        btnIcon: Icons.bolt_rounded,
        onTap: () => Navigator.pushNamed(ctx, '/book'),
      )),
      const SizedBox(width: 14),
      Expanded(child: _HeroCard(
        title: 'Green Makeover',
        icon: Icons.auto_awesome_rounded,
        iconColor: const Color(0xFFC69328),
        gradient: const [Color(0xFFFBF8F0), Color(0xFFF6EFDD)],
        btnLabel: 'Consult',
        btnIcon: Icons.arrow_forward_rounded,
        onTap: () => Navigator.pushNamed(ctx, '/green-makeover'),
      )),
    ]),
  );

  // ── Company footer ─────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext ctx) => Center(child: Column(children: [
    Image.asset('assets/images/logo-colored.png', height: 46, fit: BoxFit.contain),
    const SizedBox(height: 4),
    Text('© Plantura Care Pvt Ltd', style: p(11, color: C.t4)),
  ]));

  Widget _buildQuickActions(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('Explore GKM', style: p(18, w: FontWeight.w800, color: Colors.black)),
       const SizedBox(height: 16),
       GridView.count(
         shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
         crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 18,
         childAspectRatio: 0.82,
         children: [
            _Feature(icon: Icons.yard_rounded, title: 'Plantopedia', comingSoon: true, onTap: () => widget.navTo(3)),
            _Feature(icon: Icons.auto_awesome, title: 'Makeover', onTap: () => Navigator.pushNamed(ctx, '/green-makeover')),
            _Feature(icon: Icons.shopping_bag_rounded, title: 'My Orders', onTap: () => Navigator.pushNamed(ctx, '/shop/orders')),
            _Feature(icon: Icons.support_agent_rounded, title: 'Support', onTap: () => Navigator.pushNamed(ctx, '/complaints')),
            _Feature(icon: Icons.local_florist_rounded, title: 'Shop', onTap: () => widget.navTo(2)),
            _Feature(icon: Icons.notifications_none_rounded, title: 'Notifications', onTap: () => Navigator.pushNamed(ctx, '/notifications')),
         ],
       ),
    ]),
  );

  Widget _buildShopSection(BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Featured Products', style: p(18, w: FontWeight.w800, color: Colors.black)),
          TextButton(onPressed: () => widget.navTo(2), child: Text('See all', style: p(13, w: FontWeight.w700, color: C.forest))),
        ])),
      const SizedBox(height: 16),
      _products.isEmpty
        ? const SizedBox(height: 200, child: Center(child: Text('No products available')))
        : SizedBox(
            height: 256,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: _products.length,
              itemBuilder: (_, i) => _ProductThumb(
                product: asMap(_products[i]),
                onTap: () => widget.navTo(2),
              ),
            ),
          ),
    ],
  );

  Widget _buildPromotionsSection(BuildContext ctx) => const _PromotionsCarousel(
    images: [
      'assets/images/marketting-1.jpeg',
      'assets/images/marketting-2.jpeg',
      'assets/images/marketting-3.jpeg',
      'assets/images/marketting-4.jpeg',
      'assets/images/marketting-5.jpeg',
    ],
  );

  Widget _buildPlansSection(BuildContext ctx) {
    if (_plans.isEmpty) return const SizedBox.shrink();
    return _HotstarPlansCarousel(
      plans: _plans,
      onTap: (id) => Navigator.pushNamed(ctx, '/book', arguments: id),
    );
  }

  Widget _buildCartBar(BuildContext ctx, int count, double total) =>
    GFloatingCartBar(count: count, total: total, onTap: () {
      final cart = context.read<CartProvider>();
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => CheckoutPage(cart: cart.items, onOrdered: () => cart.clear())));
    });
}

// ─── Hero slider — replaces the old video hero, sits at ~30% screen height ───
// Fills whatever space its parent (SliverAppBar's FlexibleSpaceBar) gives it.
class _HeroSlider extends StatefulWidget {
  final List<String> images;
  const _HeroSlider({required this.images});
  @override State<_HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<_HeroSlider> {
  late final PageController _pageCtrl;
  int _current = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.images.isEmpty) return;
      final next = (_current + 1) % widget.images.length;
      _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => Image.asset(
          widget.images[i],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: C.subtle, child: const Center(child: Icon(Icons.image_rounded, color: Colors.black26, size: 40))),
        ),
      ),
      // Top scrim so the overlaid nav (white icons/text) stays readable on bright images.
      Positioned(
        left: 0, right: 0, top: 0, height: 110,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.45), Colors.transparent],
            ),
          ),
        ),
      ),
      // Bottom dot indicators
      Positioned(
        left: 0, right: 0, bottom: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.images.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
              ),
            );
          }),
        ),
      ),
    ]);
  }
}

// ─── Two-column light action card ─────────────────────────────────────────
// Layout mirrors the "Book Pronto" reference cards: title top-left, a small
// pill button beneath it, and a large decorative icon anchored bottom-right.
class _HeroCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final String btnLabel;
  final IconData btnIcon;
  final VoidCallback onTap;
  const _HeroCard({
    required this.title, required this.icon, required this.iconColor,
    required this.gradient, required this.btnLabel, required this.btnIcon, required this.onTap,
  });

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Title left, decorative icon right — same row so they can never overlap.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w800, color: C.t1, height: 1.2)),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 34, height: 34,
              child: Stack(alignment: Alignment.center, children: [
                Icon(icon, color: iconColor.withOpacity(0.55), size: 30),
                Positioned.fill(
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.white.withOpacity(0.9), Colors.transparent],
                      stops: const [0.35, 0.5, 0.65],
                    ).createShader(rect),
                    child: Icon(icon, color: iconColor, size: 30),
                  ).animate(onPlay: (c) => c.repeat())
                   .shimmer(duration: 1200.ms, delay: 900.ms, color: Colors.white.withOpacity(0.7)),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: C.forest.withOpacity(0.18)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(btnIcon, color: C.forest, size: 12),
              const SizedBox(width: 5),
              Text(btnLabel, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.forest)),
            ]),
          ),
        ),
      ]),
    ),
  );
}

// ─── Hotstar-style Plans Carousel ────────────────────────────────────────────

class _HotstarPlansCarousel extends StatefulWidget {
  final List<dynamic> plans;
  final void Function(int id) onTap;
  const _HotstarPlansCarousel({required this.plans, required this.onTap});
  @override State<_HotstarPlansCarousel> createState() => _HotstarPlansCarouselState();
}

class _HotstarPlansCarouselState extends State<_HotstarPlansCarousel> {
  late final PageController _pageCtrl;
  int _current = 0;
  Timer? _autoTimer;

  // Tier definitions — applied by index (wraps around if more plans than tiers).
  // Each tier is a deep, metallic gradient (dark → darker) with a bright accent
  // used for the badge / price / glow so cards read premium, not cartoonish.
  static const _tiers = [
    _Tier('BRONZE',   Color(0xFFE8A05C), [Color(0xFF4A3122), Color(0xFF2A1B12)]),
    _Tier('SILVER',   Color(0xFFD7E0E6), [Color(0xFF394149), Color(0xFF20262C)]),
    _Tier('GOLD',     Color(0xFFF2D78B), [Color(0xFF4A3D14), Color(0xFF2A2208)]),
    _Tier('PLATINUM', Color(0xFFAFD4F5), [Color(0xFF1E3A52), Color(0xFF0F2233)]),
    _Tier('DIAMOND',  Color(0xFFE6B8F0), [Color(0xFF3D2148), Color(0xFF24132B)]),
  ];

  @override
  void initState() {
    super.initState();
    // Narrower viewport → smaller cards (~40px narrower) with peek of neighbours.
    _pageCtrl = PageController(viewportFraction: 0.78, initialPage: 0);
    _startAuto();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAuto() {
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.plans.isEmpty) return;
      final next = (_current + 1) % widget.plans.length;
      _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  _Tier _tierFor(int index) => _tiers[index % _tiers.length];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Best Value Plans', style: p(18, w: FontWeight.w800, color: Colors.black)),
              const SizedBox(height: 4),
              Text('Tailored gardening subscriptions', style: p(12, color: Colors.black45, h: 1.4)),
            ])),
            // Position counter (scales to any number of plans, unlike a dot row)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _tierFor(_current).gradient.last,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${_current + 1}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: _tierFor(_current).accent)),
                Text(' / ${widget.plans.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          // Tall enough to surface stats + full feature list. Card content scrolls
          // internally so even the largest plans (18 features) show everything.
          height: 310,
          child: PageView.builder(
            controller: _pageCtrl,
            // Don't clip — lets each card's drop-shadow render fully past the edges.
            clipBehavior: Clip.none,
            itemCount: widget.plans.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final plan = asMap(widget.plans[i]);
              final tier = _tierFor(i);
              final price = asDouble(plan['price']);
              final name  = asStr(plan['name']);
              // Prefer the human tagline; fall back to summary, then a default.
              final tagline = asStr(plan['tagline']).isNotEmpty
                  ? asStr(plan['tagline'])
                  : asStr(plan['plan_summary'] ?? 'best care');
              final priceSubtitle = asStr(plan['price_subtitle']).isNotEmpty
                  ? asStr(plan['price_subtitle'])
                  : '/ plan';
              final visits = asInt(plan['visits_per_month']);
              final maxPlants = asInt(plan['max_plants']);
              final isBestValue = asBool(plan['is_best_value']);
              final features = asList(plan['features']).map((e) => e.toString()).toList();
              final isActive = i == _current;

              return AnimatedScale(
                scale: isActive ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onTap: () => widget.onTap(asInt(plan['id'])),
                  child: Container(
                    // Generous bottom margin so the drop-shadow is fully visible.
                    margin: const EdgeInsets.fromLTRB(6, 10, 6, 28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: tier.accent.withOpacity(isActive ? 0.40 : 0.12),
                          blurRadius: isActive ? 28 : 12,
                          spreadRadius: isActive ? 1 : 0,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(isActive ? 0.25 : 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(children: [
                        // Deep metallic gradient background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: tier.gradient,
                            ),
                          ),
                        ),

                        // Soft accent glow sweeping from the top-right corner
                        Positioned(
                          top: -70, right: -70,
                          child: Container(
                            width: 200, height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                tier.accent.withOpacity(0.30),
                                tier.accent.withOpacity(0.0),
                              ]),
                            ),
                          ),
                        ),

                        // Subtle diagonal sheen line for a metallic feel
                        Positioned(
                          top: -20, left: -40,
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 60, height: 320,
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                        ),

                        // Hairline border highlight
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: tier.accent.withOpacity(0.22), width: 1),
                            ),
                          ),
                        ),

                        // Content — header pinned, features scroll if they overflow
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Top row: tier icon  +  price  +  BEST VALUE ──
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: tier.accent.withOpacity(0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: tier.accent.withOpacity(0.45), width: 1),
                                  ),
                                  child: Icon(_tierIcon(i), size: 14, color: tier.accent),
                                ),
                                const SizedBox(width: 10),
                                // Name + tagline
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(tagline, style: p(9.5, color: Colors.white54, h: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ])),
                                const SizedBox(width: 8),
                                if (isBestValue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tier.accent,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.bolt_rounded, size: 9, color: tier.gradient.last),
                                      const SizedBox(width: 2),
                                      Text('BEST', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: tier.gradient.last, letterSpacing: 0.5)),
                                    ]),
                                  ),
                              ]),

                              const SizedBox(height: 12),

                              // ── Price line (own row so it can't collide with pills) ──
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: tier.accent, height: 1)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(priceSubtitle, style: p(9.5, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ]),

                              const SizedBox(height: 10),

                              // ── Stat pills (own row, left-aligned) ──
                              if (visits > 0 || maxPlants > 0)
                                Row(children: [
                                  if (visits > 0) _statPill(Icons.event_repeat_rounded, '$visits', 'visits/mo', tier.accent),
                                  if (visits > 0 && maxPlants > 0) const SizedBox(width: 8),
                                  if (maxPlants > 0) _statPill(Icons.spa_rounded, '$maxPlants', 'plants', tier.accent),
                                ]),

                              const SizedBox(height: 12),
                              Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                              const SizedBox(height: 10),

                              // ── All features — scrollable so nothing is hidden ──
                              Expanded(
                                child: features.isEmpty
                                  ? const SizedBox.shrink()
                                  : SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Wrap(
                                        spacing: 5, runSpacing: 5,
                                        children: features.map((f) => _featureChip(f, tier.accent)).toList(),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _tierIcon(int index) {
    switch (index % _tiers.length) {
      case 0: return Icons.workspace_premium_rounded;   // bronze
      case 1: return Icons.military_tech_rounded;        // silver
      case 2: return Icons.star_rounded;                 // gold
      case 3: return Icons.diamond_rounded;              // platinum
      default: return Icons.auto_awesome_rounded;        // diamond+
    }
  }

  // Compact icon + value (+ optional unit) stat pill, e.g. "3 /mo" or "15".
  Widget _statPill(IconData icon, String value, String label, Color accent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: accent),
      const SizedBox(width: 4),
      Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 2),
        Text(label, style: p(8.5, color: Colors.white54)),
      ],
    ]),
  );

  // Small rounded feature chip with a tick. Width-capped so long names ellipsize.
  Widget _featureChip(String text, Color accent) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 160),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withOpacity(0.22), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_rounded, size: 9, color: accent),
        const SizedBox(width: 3),
        Flexible(child: Text(text, style: p(9, w: FontWeight.w600, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

class _Tier {
  final String label;
  final Color accent;          // bright metallic accent (badge text, price, glow)
  final List<Color> gradient;  // deep background gradient (dark → darker)
  const _Tier(this.label, this.accent, this.gradient);
}

// ─── Promotions Carousel ─────────────────────────────────────────────────────

class _PromotionsCarousel extends StatefulWidget {
  final List<String> images;
  const _PromotionsCarousel({required this.images});
  @override State<_PromotionsCarousel> createState() => _PromotionsCarouselState();
}

class _PromotionsCarouselState extends State<_PromotionsCarousel> {
  late final PageController _pageCtrl;
  int _current = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.86, initialPage: 0);
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.images.isEmpty) return;
      final next = (_current + 1) % widget.images.length;
      _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Why Choose GharKaMali?", style: p(18, w: FontWeight.w800, color: Colors.black)),
            const SizedBox(height: 4),
            Text('Offers & highlights from GharKaMali', style: p(12, color: Colors.black45, h: 1.4)),
          ]),
        ),
        const SizedBox(height: 18),
        // Use the screen width and a 4:5 card aspect ratio so portrait/square
        // marketing artwork shows in full without cropping or distortion.
        SizedBox(
          height: MediaQuery.of(context).size.width * 0.86 * (5 / 4),
          child: PageView.builder(
            controller: _pageCtrl,
            clipBehavior: Clip.none, // let shadows bleed
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final active = i == _current;
              return AnimatedScale(
                scale: active ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(6, 6, 6, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFFF1F5F1), // neutral mat behind letterboxed images
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(active ? 0.22 : 0.10),
                        blurRadius: active ? 24 : 12,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(fit: StackFit.expand, children: [
                      // `contain` shows the full artwork at its natural ratio,
                      // never cropped. The neutral container colour acts as a
                      // mat around it if the aspect doesn't perfectly match.
                      Image.asset(
                        widget.images[i],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF1F5F1),
                          child: const Center(child: Icon(Icons.image_rounded, color: Colors.black26, size: 40)),
                        ),
                      ),
                      // Subtle bottom gradient so any text/logo on the image edge stays legible
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.18)],
                              stops: const [0.65, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.images.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? C.forest : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Feature extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap; final bool comingSoon;
  const _Feature({required this.icon, required this.title, required this.onTap, this.comingSoon = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (comingSoon) ...[
        Text('COMING SOON', style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: C.gold, letterSpacing: 0.6))
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1600.ms, color: Colors.white),
        const SizedBox(height: 6),
      ],
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 72, height: 72,
          child: Stack(alignment: Alignment.center, children: [
            Container(color: const Color(0xFFF8F8F8)),
            Icon(icon, color: C.forest, size: 34),
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.white.withOpacity(0.85), Colors.transparent],
                  stops: const [0.35, 0.5, 0.65],
                ).createShader(rect),
                child: Icon(icon, color: C.forest, size: 34),
              ).animate(onPlay: (c) => c.repeat())
               .shimmer(duration: 1300.ms, delay: 800.ms, color: Colors.white.withOpacity(0.7)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Text(title, style: p(11, w: FontWeight.w700, color: Colors.black87), textAlign: TextAlign.center),
    ]),
  );
}

class _ProductThumb extends StatelessWidget {
  final Map<String, dynamic> product; final VoidCallback onTap;
  const _ProductThumb({required this.product, required this.onTap});

  String _getImageUrl() {
    if (product['images'] is List && (product['images'] as List).isNotEmpty) {
      final url = (product['images'] as List).first.toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    if (product['image'] != null) {
      final url = product['image'].toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    return 'https://gkm.gobt.in/uploads/shop/placeholder.jpg';
  }

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 156, margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CachedNetworkImage(
              imageUrl: _getImageUrl(),
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(
                color: const Color(0xFFF1F5F1),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50))),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFF1F5F1),
                child: Center(child: Icon(Icons.eco_rounded, color: C.green.withOpacity(0.4), size: 36)),
              ),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asStr(product['name']), style: p(13, w: FontWeight.w700, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('₹${asDouble(product['price']).toStringAsFixed(0)}', style: p(15, w: FontWeight.w900, color: C.green)),
        ])),
      ]),
    ),
  );
}
