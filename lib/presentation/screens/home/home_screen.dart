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
import '../../widgets/plan_card.dart';
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
                  VSection(title: 'Care plans', action: 'All plans', onAction: () => Navigator.pushNamed(ctx, '/plans')),
                  const SizedBox(height: 16),
                  _PlanDeck(plans: _plans, onTap: (id) => Navigator.pushNamed(ctx, '/book', arguments: id)),
                  const SizedBox(height: 30),
                ],
                _buildWhy(),
                const SizedBox(height: 34),
                _buildSignOff(),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + (cart.count > 0 ? 100 : 24)),
              ])),
            ]),
          ),
          if (cart.count > 0) _buildCartBar(ctx, cart.count, cart.total),
        ]),
      ),
    );
  }

  // ── Top bar — its own frosted strip, never drawn over the banner ─────────
  // Floating liquid-glass controls (location · alerts · profile) — no bar
  // behind them; a soft fade keeps the status bar readable over content.
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
    flexibleSpace: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFFF5F9F4).withValues(alpha: 0.95), const Color(0xFFF5F9F4).withValues(alpha: 0)],
    )), child: const SizedBox.expand())),
    title: Consumer<LocationProvider>(builder: (ctx, lp, _) => GestureDetector(
      onTap: () {
        if (lp.locations.isNotEmpty) {
          showSavedLocations(ctx);
        } else {
          showLocationPicker(ctx).then((loc) { if (loc != null) lp.save(loc); });
        }
      },
      child: VLiquid(
        radius: 26,
        tint: const Color(0x80FFFFFF),
        thickness: 24,
        interactive: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const VOrb(icon: Icons.location_on_outlined, size: 34),
            const SizedBox(width: 10),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Your location', style: p(10.5, color: V.fog)),
              const SizedBox(height: 2),
              Text(lp.label, style: vx(14, w: FontWeight.w700, color: V.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: V.fog, size: 18),
          ]),
        ),
      ),
    )),
    actions: [
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, '/notifications'),
        child: Stack(clipBehavior: Clip.none, children: [
          const VLiquid(
            oval: true,
            tint: Color(0x80FFFFFF),
            thickness: 20,
            interactive: true,
            child: SizedBox(width: 46, height: 46, child: Icon(Icons.notifications_none_rounded, color: V.ink, size: 21)),
          ),
          if (_notifCount > 0) Positioned(top: 2, right: 0, child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: 1.5)),
            child: Text(_notifCount > 9 ? '9+' : '$_notifCount', style: p(9, w: FontWeight.w700, color: Colors.white)),
          )),
        ]),
      ),
      Consumer<AuthProvider>(builder: (ctx, auth, _) => GestureDetector(
        onTap: () => widget.navTo(4),
        child: Padding(
          padding: const EdgeInsets.only(right: 16, left: 10),
          child: VLiquid(
            oval: true,
            tint: const Color(0x80FFFFFF),
            thickness: 20,
            interactive: true,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: V.deep),
                child: ClipOval(child: auth.profileImage != null
                  ? Image.network(auth.profileImage!, cacheWidth: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20))
                  : const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20)),
              ),
            ),
          ),
        ),
      )),
    ],
  );

  // ── Greeting ────────────────────────────────────────────────────────────
  Widget _buildGreeting(String firstName) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_greeting, style: p(14, color: V.fog)),
      const SizedBox(height: 2),
      Text(firstName.isEmpty || firstName == 'User' ? 'Welcome back' : firstName,
        style: vx(30, w: FontWeight.w600, color: V.ink, ls: -0.6)),
    ]).animate().fadeIn(duration: 350.ms).slideY(begin: -0.35, end: 0, duration: 550.ms, curve: Curves.easeOutQuart),
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
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.event_available_outlined, color: Colors.white, size: 21),
                ),
                const Spacer(),
                Text('Schedule\na visit', style: vx(24, w: FontWeight.w600, color: Colors.white, ls: -0.5, h: 1.05)),
                const SizedBox(height: 6),
                Text('A gardener at your door', style: p(12, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 14),
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
              icon: Icons.yard_outlined,
              title: 'Green\nMakeover',
              tint: C.gold,
              onTap: () => Navigator.pushNamed(ctx, '/green-makeover'),
            )),
            const SizedBox(height: 12),
            Expanded(child: _BentoTile(
              icon: Icons.event_repeat_outlined,
              title: 'Care\nPlans',
              tint: V.mint,
              onTap: () => Navigator.pushNamed(ctx, '/plans'),
            )),
          ]),
        ),
      ]),
    ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: -0.12, end: 0, delay: 120.ms, duration: 550.ms, curve: Curves.easeOutQuart),
  );

  // ── Services — photo cards ──────────────────────────────────────────
  static const _services = [
    (img: 'assets/images/img-6.jpeg', title: 'Garden care visit'),
    (img: 'assets/images/backyard.jpeg', title: 'Monthly maintenance'),
    (img: 'assets/images/terrace.jpeg', title: 'Balcony & terrace'),
    (img: 'assets/images/office_mobile.jpeg', title: 'Indoor & office plants'),
    (img: 'assets/images/img-3.jpeg', title: 'Garden makeover'),
    (img: 'assets/images/Lawn.jpeg', title: 'Lawn care'),
  ];

  Widget _buildServices(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    VSection(title: 'Services', action: 'See all', onAction: () => Navigator.pushNamed(ctx, '/services')),
    const SizedBox(height: 14),
    SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = _services[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(ctx, '/services'),
            child: Container(
              width: 148,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(s.img, fit: BoxFit.cover, cacheWidth: 450),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xD90B1F14)], stops: [0.4, 1]))),
                Positioned(left: 14, right: 14, bottom: 14,
                  child: Text(s.title, style: vx(16.5, w: FontWeight.w600, color: Colors.white, h: 1.15))),
              ]),
            ),
          );
        },
      ),
    ),
  ]);

  // ── 02 Explore — glowing orb launcher ───────────────────────────────────
  Widget _buildExplore(BuildContext ctx) {
    final items = [
      (icon: Icons.menu_book_outlined, title: 'Plantopedia', soon: true, onTap: () => widget.navTo(3)),
      (icon: Icons.spa_outlined, title: 'Services', soon: false, onTap: () => Navigator.pushNamed(ctx, '/services')),
      (icon: Icons.headset_mic_outlined, title: 'Support', soon: false, onTap: () => Navigator.pushNamed(ctx, '/complaints')),
      (icon: Icons.storefront_outlined, title: 'Shop', soon: false, onTap: () => widget.navTo(2)),
      (icon: Icons.receipt_long_outlined, title: 'Orders', soon: false, onTap: () => Navigator.pushNamed(ctx, '/shop/orders')),
      (icon: Icons.event_repeat_outlined, title: 'My Plans', soon: false, onTap: () => Navigator.pushNamed(ctx, '/subscriptions')),
      (icon: Icons.yard_outlined, title: 'Makeover', soon: false, onTap: () => Navigator.pushNamed(ctx, '/green-makeover')),
      (icon: Icons.notifications_none_outlined, title: 'Alerts', soon: false, onTap: () => Navigator.pushNamed(ctx, '/notifications')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const VSection(title: 'Explore'),
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
              for (final (k, it) in items.indexed)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: it.onTap,
                  child: Column(children: [
                    Stack(clipBehavior: Clip.none, children: [
                      VOrb(icon: it.icon, size: 50, dark: false, shine: true, shineDelay: Duration(milliseconds: 250 + k * 70)),
                      if (it.soon) Positioned(top: -6, right: -10, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
                        child: Text('Soon', style: p(8.5, w: FontWeight.w600, color: Colors.white)),
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
      VSection(title: 'Shop', action: 'See all', onAction: () => widget.navTo(2)),
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

  // ── Why GKM — light two-column panel with hairline dividers ─────────
  static const _why = [
    (icon: Icons.verified_outlined, title: 'Verified gardeners', desc: 'Trained and background-checked'),
    (icon: Icons.sell_outlined, title: 'Upfront pricing', desc: 'No hidden charges, ever'),
    (icon: Icons.schedule_outlined, title: 'Flexible slots', desc: 'Visits that fit your day'),
    (icon: Icons.local_florist_outlined, title: 'Quality plants', desc: 'Healthy stock, good pots'),
    (icon: Icons.headset_mic_outlined, title: 'Real support', desc: 'People who reply, fast'),
    (icon: Icons.task_alt_outlined, title: 'End-to-end care', desc: 'From setup to upkeep'),
  ];

  Widget _buildWhy() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const VSection(title: 'Why Ghar Ka Mali'),
    const SizedBox(height: 14),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VGlassTile(
        radius: 26,
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var r = 0; r < _why.length; r += 2) ...[
            if (r > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: V.ink.withValues(alpha: 0.07)),
            IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _whyCell(_why[r])),
              Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 16), color: V.ink.withValues(alpha: 0.07)),
              Expanded(child: r + 1 < _why.length ? _whyCell(_why[r + 1]) : const SizedBox()),
            ])),
          ],
        ]),
      ),
    ),
  ]);

  Widget _whyCell(({IconData icon, String title, String desc}) w) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(w.icon, size: 22, color: V.leaf),
      const SizedBox(height: 10),
      Text(w.title, style: vx(16, w: FontWeight.w600, color: V.ink, h: 1.2)),
      const SizedBox(height: 3),
      Text(w.desc, style: p(11.5, color: V.fog, h: 1.35)),
    ]),
  );

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
            child: Stack(children: [
              PageView.builder(
              controller: _pc,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: widget.onTap,
                child: Image.asset(widget.images[i], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: V.mint)),
              ),
            ),
              // Glass page indicator floating on the banner image
              if (widget.images.length > 1) Positioned(
                left: 0, right: 0, bottom: 12,
                child: Center(child: VLiquid(
                  radius: 99,
                  tint: const Color(0x40FFFFFF),
                  thickness: 14,
                  blur: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < widget.images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _i ? 22 : 7, height: 7,
                          decoration: BoxDecoration(
                            color: i == _i ? Colors.white : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ]),
                  ),
                )),
              ),
            ]),
          ),
        ),
      ),
    ]),
  ).animate().fadeIn(delay: 60.ms, duration: 350.ms).slideY(begin: -0.12, end: 0, delay: 60.ms, duration: 550.ms, curve: Curves.easeOutQuart);
}

// ─── Bento glass tile ───────────────────────────────────────────────────────
class _BentoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color tint;
  final VoidCallback onTap;
  const _BentoTile({required this.icon, required this.title, required this.tint, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: VGlassTile(
      radius: 24,
      tint: tint,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(children: [
        Expanded(child: Text(title, style: vx(18, w: FontWeight.w600, color: V.ink, h: 1.05, ls: -0.3))),
        Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, size: 24, color: V.deep),
          const Icon(Icons.arrow_forward_rounded, size: 18, color: V.fog),
        ]),
      ]),
    ),
  );
}

// ─── Plan deck — compact plan cards ─────────────────────────────────────────
class _PlanDeck extends StatefulWidget {
  final List<dynamic> plans;
  final void Function(int id) onTap;
  const _PlanDeck({required this.plans, required this.onTap});
  @override State<_PlanDeck> createState() => _PlanDeckState();
}

class _PlanDeckState extends State<_PlanDeck> {
  final _pc = PageController(viewportFraction: 0.84);
  int _i = 0;

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => SizedBox(
    height: 410,
    child: PageView.builder(
      controller: _pc,
      clipBehavior: Clip.none,
      itemCount: widget.plans.length,
      onPageChanged: (i) => setState(() => _i = i),
      itemBuilder: (_, i) {
        final plan = asMap(widget.plans[i]);
        return AnimatedScale(
          scale: i == _i ? 1 : 0.95,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 16),
            child: GPlanCard(plan: plan, compact: true, onSelect: () => widget.onTap(asInt(plan['id']))),
          ),
        );
      },
    ),
  );
}
