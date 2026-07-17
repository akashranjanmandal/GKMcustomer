import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/services/cart_provider.dart';
import '../shop/shop_screen.dart';
import 'package:video_player/video_player.dart';
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
  List<String> _taglines = ['Expert Gardeners', 'Organic Fertilizer', 'Plant Health Check'];
  int _tagIdx = 0;
  Timer? _tagTimer;
  int _notifCount = 0;
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;

  @override void initState() {
    super.initState();
    _loadAll();
    _tagTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (mounted) setState(() => _tagIdx = (_tagIdx + 1) % _taglines.length);
    });
    _initVideo();
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('assets/images/video.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) { setState(() => _videoReady = true); _videoCtrl.play(); }
      }).catchError((_) {});
  }

  @override void dispose() { _tagTimer?.cancel(); _videoCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    try {
      final r = await Future.wait([
        _api.getPlans().catchError((_) => []),
        _api.getShopProducts(limit: 5).catchError((_) => []),
        _api.getActiveTaglines().catchError((_) => []),
        _api.getNotifications().catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = asList(r[0]);
        _products = asList(r[1]);
        final tags = asList(r[2]);
        if (tags.isNotEmpty) {
          _taglines = tags.map((e) => asStr(asMap(e)['text'])).toList();
        } else {
          _taglines = ['Professional gardening made simple', 'Expert Gardeners', 'Organic Fertilizer'];
        }
        final notifs = asList(r[3]);
        _notifCount = notifs.where((e) => asBool(asMap(e)['is_read']) == false).length;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: _loadAll, color: C.forest,
          child: CustomScrollView(slivers: [
            _buildSliverHeader(ctx),
            SliverToBoxAdapter(child: Column(children: [
              const SizedBox(height: 28),
              _buildBookingSection(ctx),
              const SizedBox(height: 28),
              _buildGreenMakeoverBanner(ctx),
              const SizedBox(height: 40),
              _buildQuickActions(ctx),
              const SizedBox(height: 40),
              _buildPromotionsSection(ctx),
              const SizedBox(height: 40),
              _buildShopSection(ctx),
              const SizedBox(height: 40),
              _buildPlansSection(ctx),
              const SizedBox(height: 130),
            ])),
          ]),
        ),
        if (cart.count > 0) _buildCartBar(ctx, cart.count, cart.total),
      ]),
    );
  }

  Widget _buildSliverHeader(BuildContext ctx) => SliverAppBar(
    expandedHeight: 480, pinned: true,
    backgroundColor: C.forest, elevation: 0,
    flexibleSpace: FlexibleSpaceBar(
      background: Stack(fit: StackFit.expand, children: [
        _videoReady
          ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoCtrl.value.size.width, height: _videoCtrl.value.size.height, child: VideoPlayer(_videoCtrl))))
          : Container(color: C.forest),
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.8)]))),

        Positioned(top: MediaQuery.of(ctx).padding.top + 10, left: 16, child: Consumer<LocationProvider>(builder: (ctx, lp, _) => GestureDetector(
          onTap: () {
            if (lp.locations.isNotEmpty) {
              showSavedLocations(ctx);
            } else {
              showLocationPicker(ctx).then((loc) { if (loc != null) lp.save(loc); });
            }
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded, color: C.gold, size: 14), const SizedBox(width: 6),
              Flexible(child: Text(lp.label, style: p(11, w: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
            ]))))),

        Positioned(top: MediaQuery.of(ctx).padding.top + 6, right: 10, child: Stack(children: [
          IconButton(onPressed: () => Navigator.pushNamed(ctx, '/notifications'), icon: const Icon(Icons.notifications_outlined, color: Colors.white)),
          if (_notifCount > 0) Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        ])),

        Positioned(left: 24, right: 24, bottom: 40, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(8)), child: Text('Professional gardening made simple', style: p(10, w: FontWeight.w900, color: Colors.black, ls: 0.5))),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: AnimatedSwitcher(
              duration: 500.ms,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                _taglines[_tagIdx],
                key: ValueKey(_tagIdx),
                style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text('GharKaMali hai na!', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: C.gold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          GBtn(label: 'BOOK A SERVICE', w: 180, h: 52, onTap: () => Navigator.pushNamed(ctx, '/book'), bg: Colors.white, labelColor: C.forest),
        ])),
      ]),
    ),
  );

  Widget _buildBookingSection(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Make your garden better', style: p(20, w: FontWeight.w800, color: Colors.black)),
      const SizedBox(height: 18),
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, '/book'),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [C.forest, const Color(0xFF1E4D2B)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: C.forest.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Schedule a Visit', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Professional gardeners at your doorstep', style: p(13, color: Colors.white70, h: 1.4)),
            ])),
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildGreenMakeoverBanner(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GestureDetector(
      onTap: () => Navigator.pushNamed(ctx, '/green-makeover'),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: C.forest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=600&h=400&fit=crop'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(C.forest.withOpacity(0.85), BlendMode.srcOver),
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(8)),
              child: Text('PREMIUM', style: p(9, w: FontWeight.w900, color: C.forest, ls: 1)),
            ),
            const SizedBox(height: 12),
            Text('Green Makeover', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Complete plant setups starting ₹20k', style: p(12, w: FontWeight.w500, color: Colors.white70, h: 1.4)),
          ])),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: C.forest, size: 20),
          ),
        ]),
      ),
    ),
  );

  Widget _buildQuickActions(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('Explore GKM', style: p(18, w: FontWeight.w800, color: Colors.black)),
       const SizedBox(height: 20),
       GridView.count(
         shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
         crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 20,
         childAspectRatio: 0.9,
         children: [
            _Feature(icon: Icons.yard_rounded, title: 'Plantopedia', onTap: () => widget.navTo(2)),
            _Feature(icon: Icons.auto_awesome, title: 'Makeover', onTap: () => Navigator.pushNamed(ctx, '/green-makeover')),
            _Feature(icon: Icons.shopping_bag_rounded, title: 'My Orders', onTap: () => Navigator.pushNamed(ctx, '/shop/orders')),
            _Feature(icon: Icons.support_agent_rounded, title: 'Support', onTap: () => Navigator.pushNamed(ctx, '/complaints')),
            _Feature(icon: Icons.local_florist_rounded, title: 'Store', onTap: () => widget.navTo(3)),
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
          TextButton(onPressed: () => widget.navTo(3), child: Text('See all', style: p(13, w: FontWeight.w700, color: C.forest))),
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
                onTap: () => widget.navTo(3),
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

  Widget _buildCartBar(BuildContext ctx, int count, double total) => Positioned(
    left: 16, right: 16, bottom: 20 + MediaQuery.of(ctx).padding.bottom,
    child: GestureDetector(
      onTap: () {
        final cart = context.read<CartProvider>();
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => CheckoutPage(cart: cart.items, onOrdered: () => cart.clear())));
      },
      child: Container(
        height: 68, padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: C.forest.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)), child: Text('$count', style: p(14, w: FontWeight.w900, color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count item${count == 1 ? '' : 's'} in cart', style: p(14, w: FontWeight.w800, color: Colors.white)),
            Text('₹${total.toStringAsFixed(0)} total', style: p(11, color: Colors.white70)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View Cart', style: p(13, w: FontWeight.w900, color: Colors.black87)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black87, size: 12),
            ]),
          ),
        ]),
      ),
    ),
  ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutQuart);
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
  final IconData icon; final String title; final VoidCallback onTap;
  const _Feature({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: C.forest, size: 30)),
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
