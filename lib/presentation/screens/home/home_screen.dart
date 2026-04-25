import 'dart:async';
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
              const SizedBox(height: 24),
              _buildBookingSection(ctx),
              const SizedBox(height: 32),
              _buildQuickActions(ctx),
              const SizedBox(height: 32),
              _buildShopSection(ctx),
              const SizedBox(height: 32),
              _buildPartnersSection(ctx),
              const SizedBox(height: 120),
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
        
        // Location Selector (Left Side)
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

        // Notification Icon (Right Side)
        Positioned(top: MediaQuery.of(ctx).padding.top + 6, right: 10, child: Stack(children: [
          IconButton(onPressed: () => Navigator.pushNamed(ctx, '/notifications'), icon: const Icon(Icons.notifications_outlined, color: Colors.white)),
          if (_notifCount > 0) Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        ])),

        // Hero Content
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
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, '/book'),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [C.forest, const Color(0xFF1E4D2B)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: C.forest.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Schedule a Visit', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Professional gardeners at your doorstep', style: p(13, color: Colors.white70)),
            ])),
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildQuickActions(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('Explore GKM', style: p(18, w: FontWeight.w800, color: Colors.black)),
       const SizedBox(height: 16),
       GridView.count(
         shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
         crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 20,
         childAspectRatio: 0.9,
         children: [
            _Feature(icon: Icons.yard_rounded, title: 'Plantopedia', onTap: () => widget.navTo(2)),
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
      const SizedBox(height: 12),
      _products.isEmpty ? const SizedBox(height: 200, child: Center(child: Text('No products available'))) :
      SizedBox(height: 240, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _products.length,
        itemBuilder: (_, i) => _ProductThumb(product: asMap(_products[i]), onTap: () => widget.navTo(3)),
      )),
    ],
  );

  Widget _buildPartnersSection(BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Best Value Plans', style: p(18, w: FontWeight.w800, color: Colors.black)),
          Text('Highly recommended subscription plans', style: p(13, color: Colors.black54)),
        ])),
      const SizedBox(height: 16),
      _plans.isEmpty ? const SizedBox(height: 100, child: Center(child: Text('No plans found'))) :
      SizedBox(height: 160, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _plans.length.clamp(0, 5),
        itemBuilder: (_, i) => _ServiceCard(plan: asMap(_plans[i]), onTap: () => Navigator.pushNamed(ctx, '/book', arguments: asInt(_plans[i]['id']))),
      )),
    ],
  );

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

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> plan; final VoidCallback onTap;
  const _ServiceCard({required this.plan, required this.onTap});
  @override
  Widget build(BuildContext ctx) {
    final price = asDouble(plan['price']);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160, margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFF2F9F5), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.04))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asStr(plan['name']), style: p(15, w: FontWeight.w800, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text('₹${price.toStringAsFixed(0)}', style: p(20, w: FontWeight.w900, color: C.forest)),
          Text(asStr(plan['plan_summary'] ?? 'best care'), style: p(11, w: FontWeight.w700, color: C.green)),
        ]),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _Feature({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: C.forest, size: 30)),
      const SizedBox(height: 8),
      Text(title, style: p(11, w: FontWeight.w700, color: Colors.black87), textAlign: TextAlign.center),
    ]),
  );
}

class _ProductThumb extends StatelessWidget {
  final Map<String, dynamic> product; final VoidCallback onTap;
  const _ProductThumb({required this.product, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 150, margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: Image.network(imgUrl(product['image']), fit: BoxFit.cover, width: double.infinity, errorBuilder: (_,__,___) => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.eco, color: Colors.green, size: 32)))))),
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asStr(product['name']), style: p(13, w: FontWeight.w700, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('₹${asDouble(product['price']).toStringAsFixed(0)}', style: p(15, w: FontWeight.w900, color: C.green)),
        ])),
      ]),
    ),
  );
}
