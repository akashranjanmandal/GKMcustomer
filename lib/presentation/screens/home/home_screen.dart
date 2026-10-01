import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../data/services/auth.dart';
import '../../../data/services/cart_provider.dart';
import '../shop/shop_screen.dart';
import '../shop/product_view_screen.dart';
import '../../widgets/product_card.dart';
import '../../../data/services/api.dart';
import '../../../data/services/location_provider.dart';
import '../../../data/services/ops_status_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// Home — Verdant layout:
//   frosted top bar (location · alerts · profile) pinned ABOVE the content,
//   greeting, banner capsule, bento action deck, services, explore orbs,
//   featured products, plans, why-GKM, promotions, sign-off.
// No looping animations: carousels only auto-advance while this tab is
// visible, so the phone isn't kept rendering in the background.
class HomeScreen extends StatefulWidget {
  final Function(int) navTo;
  const HomeScreen({super.key, required this.navTo});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  final _api = Api();
  List<dynamic> _plans = [];
  List<dynamic> _products = [];
  int _notifCount = 0;

  @override void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Re-check the operations kill-switch alongside home data (init + pull-to-refresh).
    if (mounted) context.read<OpsStatusProvider>().load();
    try {
      final r = await Future.wait([
        _api.getPlans().catchError((_) => []),
        _api.getShopProducts(limit: 5).catchError((_) => []),
        _api.getNotifications().catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        // On-demand visits (e.g. ₹399/₹499) show first, then subscription plans.
        // Within each group the API's price-ascending order is preserved.
        final loadedPlans = asList(r[0]);
        loadedPlans.sort((a, b) {
          int rank(dynamic p) => asStr(asMap(p)['plan_type']) == 'subscription' ? 1 : 0;
          final byType = rank(a).compareTo(rank(b));
          if (byType != 0) return byType;
          return asDouble(asMap(a)['price']).compareTo(asDouble(asMap(b)['price']));
        });
        _plans = loadedPlans;
        _products = asList(r[1]);
        final notifs = asList(r[2]);
        _notifCount = notifs.where((e) => asBool(asMap(e)['is_read']) == false).length;
      });
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();
    final firstName = ctx.select<AuthProvider, String>((a) => a.name.split(' ').first);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          RefreshIndicator(
            onRefresh: _loadAll, color: V.leaf,
            child: CustomScrollView(slivers: [
              _buildTopBar(ctx),
              SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 10),
                _buildGreeting(firstName),
                const SizedBox(height: 18),
                _BannerCapsule(
                  images: const ['assets/images/banner-1.png', 'assets/images/banner-2.png'],
                  onTap: () => Navigator.pushNamed(ctx, '/book'),
                ),
                const SizedBox(height: 22),
                const GOpsBanner(margin: EdgeInsets.fromLTRB(16, 0, 16, 22)),
                _buildBento(ctx),
                const SizedBox(height: 34),
                _buildServices(ctx),
                const SizedBox(height: 34),
                _buildExplore(ctx),
                const SizedBox(height: 34),
                _buildShopSection(ctx),
                const SizedBox(height: 30),
                if (_plans.isNotEmpty) ...[
                  VSection(index: '05', title: 'Care plans', action: 'All plans', onAction: () => Navigator.pushNamed(ctx, '/plans')),
                  const SizedBox(height: 16),
                  _PlanDeck(plans: _plans, onTap: (id) => Navigator.pushNamed(ctx, '/book', arguments: id)),
                  const SizedBox(height: 30),
                ],
                _buildWhy(),
                const SizedBox(height: 34),
                const VSection(index: '07', title: 'Inspiration'),
                const SizedBox(height: 16),
                const _PromoStrip(images: [
                  'assets/images/marketting-1.jpeg',
                  'assets/images/marketting-2.jpeg',
                  'assets/images/marketting-3.jpeg',
                  'assets/images/marketting-4.jpeg',
                  'assets/images/marketting-5.jpeg',
                ]),
                const SizedBox(height: 36),
                _buildSignOff(),
                SizedBox(height: cart.count > 0 ? 120 : 28),
              ])),
            ]),
          ),
          if (cart.count > 0) _buildCartBar(ctx, cart.count, cart.total),
        ]),
      ),
    );
  }

  // ── Top bar — its own frosted strip, never drawn over the banner ─────────
  Widget _buildTopBar(BuildContext ctx) => SliverAppBar(
    pinned: true,
    automaticallyImplyLeading: false,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    toolbarHeight: 66,
    titleSpacing: 16,
    flexibleSpace: const VFrost(opacity: 0.55, child: SizedBox.expand()),
    title: Consumer<LocationProvider>(builder: (ctx, lp, _) => GestureDetector(
      onTap: () {
        if (lp.locations.isNotEmpty) {
          showSavedLocations(ctx);
        } else {
          showLocationPicker(ctx).then((loc) { if (loc != null) lp.save(loc); });
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white),
          boxShadow: [BoxShadow(color: V.deep.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const VOrb(icon: Icons.near_me_rounded, size: 34),
          const SizedBox(width: 10),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('SERVICE AT', style: vx(9, w: FontWeight.w700, color: V.fog, ls: 1.4)),
            const SizedBox(height: 2),
            Text(lp.label, style: vx(14, w: FontWeight.w700, color: V.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, color: V.fog, size: 18),
        ]),
      ),
    )),
    actions: [
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, '/notifications'),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.7),
            border: Border.all(color: Colors.white),
          ),
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            const Icon(Icons.notifications_none_rounded, color: V.ink, size: 21),
            if (_notifCount > 0) Positioned(top: 9, right: 10, child: Container(
              width: 9, height: 9,
              decoration: BoxDecoration(color: V.neon, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [BoxShadow(color: V.neon.withValues(alpha: 0.7), blurRadius: 6)]),
            )),
          ]),
        ),
      ),
      Consumer<AuthProvider>(builder: (ctx, auth, _) => GestureDetector(
        onTap: () => widget.navTo(4),
        child: Container(
          margin: const EdgeInsets.only(right: 16, left: 10),
          width: 44, height: 44,
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [V.neon, V.lime, V.leaf, V.neon]),
          ),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: V.ink),
            child: ClipOval(child: auth.profileImage != null
              ? Image.network(auth.profileImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: V.lime, size: 20))
              : const Icon(Icons.person_rounded, color: V.lime, size: 20)),
          ),
        ),
      )),
    ],
  );

  // ── Greeting ────────────────────────────────────────────────────────────
  Widget _buildGreeting(String firstName) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      VLabel('$_greeting${firstName.isEmpty || firstName == 'User' ? '' : ', $firstName'}'),
      const SizedBox(height: 10),
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(colors: [V.ink, V.leaf, Color(0xFF2BB673)]).createShader(r),
        child: Text('Grow something\nalive today.', style: vx(34, w: FontWeight.w700, color: Colors.white, ls: -1.2, h: 1.02)),
      ),
    ]).animate().fadeIn(duration: 500.ms).slideX(begin: -0.04, end: 0, curve: Curves.easeOutCubic),
  );

  // ── Bento action deck: one tall dark pod + two stacked glass tiles ───────
  Widget _buildBento(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      height: 236,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          flex: 11,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(ctx, '/book'),
            child: VPod(
              radius: 30,
              padding: const EdgeInsets.all(18),
              contourCenter: const Offset(1, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Stack(alignment: Alignment.center, children: [
                  VPulse(size: 56),
                  VOrb(icon: Icons.bolt_rounded, size: 38, accent: V.lime),
                ]),
                const Spacer(),
                Text('MALI ON\nDEMAND', style: vx(10, w: FontWeight.w700, color: V.neon, ls: 1.6, h: 1.3)),
                const SizedBox(height: 6),
                Text('Schedule\na visit', style: vx(23, w: FontWeight.w700, color: Colors.white, ls: -0.6, h: 1.0)),
                const SizedBox(height: 12),
                const VChip('Book'),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 10,
          child: Column(children: [
            Expanded(child: _BentoTile(
              icon: Icons.auto_awesome_rounded,
              eyebrow: 'DESIGN',
              title: 'Green\nMakeover',
              tint: C.gold,
              onTap: () => Navigator.pushNamed(ctx, '/green-makeover'),
            )),
            const SizedBox(height: 12),
            Expanded(child: _BentoTile(
              icon: Icons.all_inclusive_rounded,
              eyebrow: 'SUBSCRIBE',
              title: 'Care\nPlans',
              tint: V.mint,
              onTap: () => Navigator.pushNamed(ctx, '/plans'),
            )),
          ]),
        ),
      ]),
    ).animate().fadeIn(delay: 120.ms, duration: 450.ms).slideY(begin: 0.06, end: 0),
  );

  // ── 01 Services — tall glass capsules, title only ───────────────────────
  static const _services = [
    (icon: Icons.bolt_rounded, title: 'Mali on Demand'),
    (icon: Icons.event_repeat_rounded, title: 'Monthly Care'),
    (icon: Icons.balcony_rounded, title: 'Balcony & Terrace'),
    (icon: Icons.local_florist_rounded, title: 'Plants & Pots'),
    (icon: Icons.auto_awesome_rounded, title: 'Garden Makeover'),
    (icon: Icons.grass_rounded, title: 'Lawn Care'),
    (icon: Icons.pest_control_rounded, title: 'Pest Control'),
    (icon: Icons.eco_rounded, title: 'Soil & Compost'),
  ];

  Widget _buildServices(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    VSection(index: '01', title: 'Services', action: 'See all', onAction: () => Navigator.pushNamed(ctx, '/services')),
    const SizedBox(height: 16),
    SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = _services[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(ctx, '/services'),
            child: SizedBox(
              width: 118,
              child: VGlassTile(
                radius: 60,
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
                child: Column(children: [
                  VOrb(icon: s.icon, size: 54),
                  const Spacer(),
                  Text(s.title, textAlign: TextAlign.center, maxLines: 2,
                    style: vx(13, w: FontWeight.w700, color: V.ink, h: 1.15)),
                  const SizedBox(height: 8),
                  Text((i + 1).toString().padLeft(2, '0'), style: vx(10, w: FontWeight.w600, color: V.fog, ls: 1.2)),
                ]),
              ),
            ),
          );
        },
      ),
    ),
  ]);

  // ── 02 Explore — glowing orb launcher ───────────────────────────────────
  Widget _buildExplore(BuildContext ctx) {
    final items = [
      (icon: Icons.yard_rounded, title: 'Plantopedia', soon: true, onTap: () => widget.navTo(3)),
      (icon: Icons.spa_rounded, title: 'Services', soon: false, onTap: () => Navigator.pushNamed(ctx, '/services')),
      (icon: Icons.support_agent_rounded, title: 'Support', soon: false, onTap: () => Navigator.pushNamed(ctx, '/complaints')),
      (icon: Icons.storefront_rounded, title: 'Shop', soon: false, onTap: () => widget.navTo(2)),
      (icon: Icons.receipt_long_rounded, title: 'Orders', soon: false, onTap: () => Navigator.pushNamed(ctx, '/shop/orders')),
      (icon: Icons.workspace_premium_rounded, title: 'My Plans', soon: false, onTap: () => Navigator.pushNamed(ctx, '/subscriptions')),
      (icon: Icons.auto_awesome_rounded, title: 'Makeover', soon: false, onTap: () => Navigator.pushNamed(ctx, '/green-makeover')),
      (icon: Icons.notifications_none_rounded, title: 'Alerts', soon: false, onTap: () => Navigator.pushNamed(ctx, '/notifications')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const VSection(index: '02', title: 'Explore'),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: VGlassTile(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
          child: GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [
              for (final it in items)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: it.onTap,
                  child: Column(children: [
                    Stack(clipBehavior: Clip.none, children: [
                      VOrb(icon: it.icon, size: 52, dark: false, accent: V.leaf),
                      if (it.soon) Positioned(top: -6, right: -10, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
                        child: Text('SOON', style: vx(7.5, w: FontWeight.w700, color: V.lime, ls: 0.8)),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: vx(11.5, w: FontWeight.w600, color: V.ink)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ── 03 Featured products (cards unchanged) ──────────────────────────────
  Widget _buildShopSection(BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      VSection(index: '03', title: 'Shop', action: 'See all', onAction: () => widget.navTo(2)),
      const SizedBox(height: 16),
      _products.isEmpty
        ? const SizedBox(height: 200, child: Center(child: Text('No products available')))
        // Cards in one row share the tallest card's height so full product
        // names always fit.
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 2, 14),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < _products.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: SizedBox(
                      width: 168,
                      child: GProductCard(
                        pData: asMap(_products[i]),
                        onTap: () async {
                          final res = await ProductViewScreen.open(ctx, _products, i);
                          if (res == 'search') widget.navTo(2);
                        },
                      ),
                    ),
                  ),
              ]),
            ),
          ),
    ],
  );

  // ── 06 Why GKM — dark pod with a 2×N grid of short trust points ─────────
  static const _why = [
    (icon: Icons.verified_user_rounded, title: 'Verified\nexperts'),
    (icon: Icons.touch_app_rounded, title: 'Book in\na few taps'),
    (icon: Icons.price_check_rounded, title: 'Upfront\npricing'),
    (icon: Icons.event_available_rounded, title: 'Flexible\nslots'),
    (icon: Icons.local_florist_rounded, title: 'Quality\nplants'),
    (icon: Icons.support_agent_rounded, title: 'Real\nsupport'),
  ];

  Widget _buildWhy() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const VSection(index: '06', title: 'Why GKM'),
    const SizedBox(height: 16),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VPod(
        radius: 32,
        contourCenter: const Offset(0, 1),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trusted by\nthousands of gardens.', style: vx(22, w: FontWeight.w700, color: Colors.white, ls: -0.5, h: 1.08)),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              for (final w in _why)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(w.icon, color: V.neon, size: 22),
                  const SizedBox(height: 8),
                  Container(width: 18, height: 1.5, color: V.lime.withValues(alpha: 0.6)),
                  const SizedBox(height: 8),
                  Text(w.title, style: vx(12.5, w: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9), h: 1.2)),
                ]),
            ],
          ),
        ]),
      ),
    ),
  ]);

  // ── Sign-off ────────────────────────────────────────────────────────────
  Widget _buildSignOff() => Center(child: Column(children: [
    SizedBox(
      width: 120, height: 120,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(child: CustomPaint(painter: ContourPainter(
          color: V.leaf.withValues(alpha: 0.18), center: const Offset(0.5, 0.5), rings: 5))),
        Image.asset('assets/images/logo-colored.png', height: 44, fit: BoxFit.contain),
      ]),
    ),
    Text('Grown with care.', style: vx(16, w: FontWeight.w700, color: V.deep)),
    const SizedBox(height: 4),
    Text('© Plantura Care Pvt Ltd', style: vx(10.5, w: FontWeight.w500, color: V.fog, ls: 0.6)),
  ]));

  Widget _buildCartBar(BuildContext ctx, int count, double total) =>
    GFloatingCartBar(count: count, total: total, onTap: () {
      final cart = context.read<CartProvider>();
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => CheckoutPage(cart: cart.items, onOrdered: () => cart.clear())));
    });
}

// True only while this widget is on screen: its tab is active (TickerMode)
// and its route is on top. Used to stop carousel timers doing work off-screen.
bool _onScreen(BuildContext ctx) =>
    TickerMode.of(ctx) && (ModalRoute.of(ctx)?.isCurrent ?? true);

// ─── Banner capsule — rounded, inset card; nothing overlaps it ──────────────
class _BannerCapsule extends StatefulWidget {
  final List<String> images;
  final VoidCallback onTap;
  const _BannerCapsule({required this.images, required this.onTap});
  @override State<_BannerCapsule> createState() => _BannerCapsuleState();
}

class _BannerCapsuleState extends State<_BannerCapsule> {
  final _pc = PageController();
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.images.length < 2 || !_onScreen(context)) return;
      _pc.animateToPage((_i + 1) % widget.images.length, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() { _t?.cancel(); _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(children: [
      // Banner art is 3:2 — keep the exact ratio so nothing is cropped.
      AspectRatio(
        aspectRatio: 3 / 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: V.deep.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: widget.onTap,
                child: Image.asset(widget.images[i], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: V.mint)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Segmented indicator below the banner (not on it)
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < widget.images.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _i ? 28 : 10, height: 4,
            decoration: BoxDecoration(
              color: i == _i ? V.leaf : V.leaf.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ]),
    ]),
  ).animate().fadeIn(delay: 60.ms, duration: 450.ms).scale(begin: const Offset(0.97, 0.97), curve: Curves.easeOutCubic);
}

// ─── Bento glass tile ───────────────────────────────────────────────────────
class _BentoTile extends StatelessWidget {
  final IconData icon;
  final String eyebrow, title;
  final Color tint;
  final VoidCallback onTap;
  const _BentoTile({required this.icon, required this.eyebrow, required this.title, required this.tint, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: VGlassTile(
      radius: 26,
      tint: tint,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(eyebrow, style: vx(9, w: FontWeight.w700, color: V.leaf, ls: 1.4)),
          const SizedBox(height: 4),
          Text(title, style: vx(16, w: FontWeight.w700, color: V.ink, h: 1.0, ls: -0.3)),
        ])),
        Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          VOrb(icon: icon, size: 34),
          const Icon(Icons.north_east_rounded, size: 16, color: V.deep),
        ]),
      ]),
    ),
  );
}

// ─── Plan deck — dark data cards ────────────────────────────────────────────
class _PlanDeck extends StatefulWidget {
  final List<dynamic> plans;
  final void Function(int id) onTap;
  const _PlanDeck({required this.plans, required this.onTap});
  @override State<_PlanDeck> createState() => _PlanDeckState();
}

class _PlanDeckState extends State<_PlanDeck> {
  final _pc = PageController(viewportFraction: 0.8);
  int _i = 0;

  // Accent per card, cycled — keeps the deck varied but on-palette.
  static const _accents = [V.neon, V.lime, Color(0xFF7CE7FF), C.gold, Color(0xFFB9F6CA)];

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => SizedBox(
    height: 268,
    child: PageView.builder(
      controller: _pc,
      clipBehavior: Clip.none,
      itemCount: widget.plans.length,
      onPageChanged: (i) => setState(() => _i = i),
      itemBuilder: (_, i) {
        final plan = asMap(widget.plans[i]);
        final accent = _accents[i % _accents.length];
        final price = asDouble(plan['price']);
        final visits = asInt(plan['visits_per_month']);
        final plants = asInt(plan['max_plants']);
        final sub = asStr(plan['price_subtitle']).isNotEmpty ? asStr(plan['price_subtitle']) : '/ plan';
        final features = asList(plan['features']).map((e) => e.toString()).where((s) => s.isNotEmpty).take(3).toList();
        final best = asBool(plan['is_best_value']);
        return AnimatedScale(
          scale: i == _i ? 1 : 0.93,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: () => widget.onTap(asInt(plan['id'])),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 18),
              child: VPod(
                radius: 30,
                glow: accent,
                contourCenter: Offset(i.isEven ? 1 : 0, 0),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(asStr(plan['name']).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: vx(11, w: FontWeight.w700, color: accent, ls: 1.6))),
                    if (best) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)),
                      child: Text('BEST', style: vx(9, w: FontWeight.w800, color: V.ink, ls: 1)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${price.toStringAsFixed(0)}', style: vx(36, w: FontWeight.w700, color: Colors.white, ls: -1.4, h: 1)),
                    const SizedBox(width: 6),
                    Flexible(child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: vx(11.5, color: Colors.white54)),
                    )),
                  ]),
                  const SizedBox(height: 14),
                  if (visits > 0 || plants > 0) Row(children: [
                    if (visits > 0) _readout('$visits', 'VISITS / MO', accent),
                    if (visits > 0 && plants > 0) Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 14), color: Colors.white24),
                    if (plants > 0) _readout('$plants', 'PLANTS', accent),
                  ]),
                  const Spacer(),
                  for (final f in features) Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      Icon(Icons.check_rounded, size: 13, color: accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: vx(12, w: FontWeight.w500, color: Colors.white70))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _readout(String v, String label, Color accent) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(v, style: vx(20, w: FontWeight.w700, color: accent, h: 1)),
    const SizedBox(height: 3),
    Text(label, style: vx(8.5, w: FontWeight.w700, color: Colors.white54, ls: 1.2)),
  ]);
}

// ─── Promotions — tilted-deck image strip ───────────────────────────────────
class _PromoStrip extends StatefulWidget {
  final List<String> images;
  const _PromoStrip({required this.images});
  @override State<_PromoStrip> createState() => _PromoStripState();
}

class _PromoStripState extends State<_PromoStrip> {
  final _pc = PageController(viewportFraction: 0.84);
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.images.length < 2 || !_onScreen(context)) return;
      _pc.animateToPage((_i + 1) % widget.images.length, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() { _t?.cancel(); _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => SizedBox(
    height: 190,
    child: PageView.builder(
      controller: _pc,
      clipBehavior: Clip.none,
      itemCount: widget.images.length,
      onPageChanged: (i) => setState(() => _i = i),
      itemBuilder: (_, i) => AnimatedScale(
        scale: i == _i ? 1 : 0.92,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: V.deep.withValues(alpha: 0.14), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.asset(widget.images[i], fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder: (_, __, ___) => const ColoredBox(color: V.mint)),
            ),
          ),
        ),
      ),
    ),
  );
}
