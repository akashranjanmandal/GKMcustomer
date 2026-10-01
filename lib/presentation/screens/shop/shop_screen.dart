import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/cart_provider.dart';
import '../../../data/services/invoice_service.dart';
import '../../../data/services/location_provider.dart';
import '../../../data/services/ops_status_provider.dart';
import '../../../data/services/razorpay_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/location_picker_sheet.dart';
import '../../widgets/product_card.dart';
import 'product_view_screen.dart';

class ShopScreen extends StatefulWidget {
  // Back arrow action. In the bottom-nav shell this returns to the Home tab;
  // when pushed as a route it falls back to popping.
  final VoidCallback? onBack;
  const ShopScreen({super.key, this.onBack});
  @override State<ShopScreen> createState() => _ShopState();
}

class _ShopState extends State<ShopScreen> {
  final _api = Api();
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _selectedCat = 'All';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  int _page = 1, _pages = 1, _total = 0;

  @override void initState() {
    super.initState();
    _load();
    // Infinite scroll: fetch the next page once the user nears the bottom.
    _scrollCtrl.addListener(() {
      if (_loading || _loadingMore || !_hasMore) return;
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
        _fetchMore();
      }
    });
  }
  @override void dispose() { _searchCtrl.dispose(); _searchFocus.dispose(); _scrollCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await _api.getShopCategories().catchError((_) => []);
      if (mounted) setState(() => _categories = ['All', ...asList(cats).map((e) => asStr(asMap(e)['name']))]);
    } catch (_) {}
    _page = 1;
    await _fetch();
  }

  // Fetch page 1 fresh (used on initial load / filter changes / pull-to-refresh).
  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getShopProductsPaged(
        category: _selectedCat == 'All' ? null : _selectedCat,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
        page: _page,
        limit: 24,
      );
      if (mounted) setState(() {
        _products = asList(r['items']);
        _total = asInt(r['total']);
        _pages = asInt(r['pages']);
        _hasMore = _page < _pages;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  // Lazily append the next page as the user scrolls near the bottom —
  // replaces old-school numbered pagination with continuous loading.
  Future<void> _fetchMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final r = await _api.getShopProductsPaged(
        category: _selectedCat == 'All' ? null : _selectedCat,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
        page: nextPage,
        limit: 24,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _products = [..._products, ...asList(r['items'])];
        _total = asInt(r['total']);
        _pages = asInt(r['pages']);
        _hasMore = _page < _pages;
        _loadingMore = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingMore = false); }
  }

  // Any filter/search change resets to page 1.
  void _filter() { _page = 1; _hasMore = true; _fetch(); }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _filter);
  }

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Column(children: [
          _buildHeader(ctx),
          _buildSearchSection(),
          Expanded(child: RefreshIndicator(
            onRefresh: _load, color: C.forest,
            child: _loading
              ? GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: 0.58), itemCount: 6, itemBuilder: (_,__) => Container(decoration: BoxDecoration(color: kCardTop.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.7)))))
              : _products.isEmpty
                ? const GEmpty(title: 'No items found', sub: 'Try a different category or search term', icon: Icons.shopping_bag_outlined)
                : CustomScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text('$_total product${_total == 1 ? '' : 's'}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      // Two cards per row; each row is as tall as its tallest
                      // card so full product names are always visible.
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, r) {
                              final cards = [
                                for (var i = r * 2; i < r * 2 + 2 && i < _products.length; i++)
                                  GProductCard(pData: asMap(_products[i]), onTap: () => _showDetail(i)),
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: GProductGridRow(cards: cards),
                              ).animate().fadeIn(delay: Duration(milliseconds: (r % 12) * 40)).slideY(begin: 0.05, end: 0);
                            },
                            childCount: (_products.length + 1) ~/ 2,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).padding.bottom + 110),
                          child: _loadingMore
                            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.forest)))
                            : !_hasMore && _products.isNotEmpty
                              ? Center(child: Text("You've reached the end", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600)))
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
          )),
        ]),
        if (cart.count > 0) _buildCartBar(ctx, cart.count, cart.total, cart.items.length),
      ]),
    ));
  }

  Future<void> _showDetail(int index) async {
    final res = await ProductViewScreen.open(context, _products, index);
    if (res == 'search' && mounted) _searchFocus.requestFocus();
  }

  void _back(BuildContext ctx) => widget.onBack != null ? widget.onBack!() : Navigator.maybePop(ctx);

  Widget _buildHeader(BuildContext ctx) => VPageHeader(
    title: 'Shop',
    subtitle: 'Plants, pots, seeds and everything to care for them.',
    onBack: () => _back(ctx),
    trailing: VPillAction(label: 'My orders', icon: Icons.receipt_long_outlined, onTap: () => Navigator.pushNamed(ctx, '/shop/orders')),
  );

  Widget _buildSearchSection() => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Search: single container, stripped TextField ──────────────────
      GGlass(
        radius: BorderRadius.circular(99),
        child: SizedBox(height: 52, child: Row(children: [
          const SizedBox(width: 18),
          const Icon(Icons.search_rounded, color: V.fog, size: 21),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: _onSearch,
            style: p(14, w: FontWeight.w600, color: C.t1),
            decoration: InputDecoration(
              hintText: 'Search seeds, fertilizers, pots...',
              hintStyle: TextStyle(color: C.t4, fontSize: 13, fontWeight: FontWeight.w400),
              border:             InputBorder.none,
              enabledBorder:      InputBorder.none,
              focusedBorder:      InputBorder.none,
              errorBorder:        InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder:     InputBorder.none,
              filled:             false,
              isDense:            true,
              contentPadding:     EdgeInsets.zero,
            ),
          )),
        ])),
      ),
      const SizedBox(height: 12),
      // ── Category pills ────────────────────────────────────────────────
      SizedBox(height: 38, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => VFilterChip(
          label: _categories[i],
          sel: _categories[i] == _selectedCat,
          onTap: () { setState(() => _selectedCat = _categories[i]); _filter(); },
        ),
      )),
    ]),
  );

  Widget _buildCartBar(BuildContext ctx, int count, double total, int distinct) => GFloatingCartBar(
    count: count,
    total: total,
    subtitle: distinct == count ? '$count item${count == 1 ? '' : 's'} in cart' : '$distinct product${distinct == 1 ? '' : 's'} · $count items',
    onTap: () {
      final cart = context.read<CartProvider>();
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => CheckoutPage(cart: cart.items, onOrdered: () => cart.clear())));
    },
  );
}

// Opens the product detail sheet from anywhere (e.g. the product viewer).
void showProductDetailSheet(BuildContext context, Map<String, dynamic> pData) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _ProductDetails(pData: pData, onAdd: () {
      HapticFeedback.lightImpact();
      context.read<CartProvider>().add(pData);
    }),
  );
}

class _ProductDetails extends StatefulWidget {
  final Map<String, dynamic> pData; final VoidCallback onAdd;
  const _ProductDetails({required this.pData, required this.onAdd});
  @override State<_ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<_ProductDetails> {
  final _api = Api();
  late Map<String, dynamic> _data = widget.pData;
  bool _loadingFull = true;
  int _imgIdx = 0;
  final _faqOpen = <int>{};

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  // The list tile only carries summary fields (name/price/image/category).
  // Fetch the full record (long_description, features, faqs, rating, tags,
  // multi-image gallery, badge) so the modal can show a complete detail page.
  Future<void> _loadFull() async {
    final id = asInt(widget.pData['id']);
    if (id == 0) { setState(() => _loadingFull = false); return; }
    try {
      final full = await _api.getShopProduct(id);
      if (mounted && full is Map) {
        setState(() { _data = {...widget.pData, ...Map<String, dynamic>.from(full)}; _loadingFull = false; });
      } else if (mounted) {
        setState(() => _loadingFull = false);
      }
    } catch (_) { if (mounted) setState(() => _loadingFull = false); }
  }

  List<String> _images() {
    final imgs = _data['images'];
    if (imgs is List && imgs.isNotEmpty) {
      return imgs.map((e) => e.toString()).where((s) => s.isNotEmpty && s != 'null').toList();
    }
    final single = _data['image']?.toString();
    if (single != null && single.isNotEmpty && single != 'null') return [single];
    return ['https://gkm.gobt.in/uploads/shop/placeholder.jpg'];
  }

  @override
  Widget build(BuildContext ctx) {
    final screenH = MediaQuery.of(ctx).size.height;
    final topInset = MediaQuery.of(ctx).padding.top;
    final images = _images();
    final price = asDouble(_data['price']);
    final mrp = asDouble(_data['mrp']);
    final discount = mrp > price ? ((mrp - price) / mrp * 100).round() : 0;
    final rating = asDouble(_data['rating']);
    final reviewCount = asInt(_data['review_count']);
    final badge = asStr(_data['badge']);
    final longDesc = asStr(_data['long_description']);
    final features = asList(_data['features']).map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    final faqs = asList(_data['faqs']).map((e) => asMap(e)).where((m) => m.isNotEmpty).toList();
    final tags = asList(_data['tags']).map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    final stock = _data['stock_quantity'] == null ? null : asInt(_data['stock_quantity']);
    final outOfStock = stock != null && stock <= 0;

    return Container(
      height: screenH - topInset,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.97), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(children: [
        // ── Drag handle ──────────────────────────────────────────────────
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 8),

        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── Product image gallery — contained on white, nothing cropped ──
              Container(
                color: Colors.white,
                height: screenH * 0.38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(children: [
                  PageView.builder(
                    onPageChanged: (i) => setState(() => _imgIdx = i),
                    itemCount: images.length,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.contain,
                        width: double.infinity,
                        placeholder: (_, __) => Container(color: const Color(0xFFF6F8F5), child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)))),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF6F8F5),
                          child: Center(child: Icon(Icons.eco_rounded, size: 64, color: C.green.withOpacity(0.4))),
                        ),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0, right: 0, bottom: 6,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(images.length, (i) => Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i == _imgIdx ? C.forest : C.border),
                      ))),
                    ),
                ]),
              ),

              // ── Info ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Badge + category
                  if (badge.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: C.forest.withOpacity(0.08), borderRadius: BorderRadius.circular(7)),
                      child: Text(badge.toUpperCase(), style: p(9.5, w: FontWeight.w800, color: C.forest, ls: 0.5)),
                    ),
                  ),
                  // Name + price row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(asStr(_data['name']), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: C.t1)),
                      const SizedBox(height: 2),
                      Text(asStr(asMap(_data['category'])['name'], 'Garden Care'), style: p(13, w: FontWeight.w600, color: C.forest.withOpacity(0.65))),
                    ])),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: C.green)),
                      if (mrp > price)
                        Text('₹${mrp.toStringAsFixed(0)}', style: const TextStyle(decoration: TextDecoration.lineThrough, decorationColor: Color(0xFF9AAA94), color: Color(0xFF9AAA94), fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ]),

                  // Rating + discount row
                  if (rating > 0 || discount > 0) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(children: [
                      if (rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFC69328)),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1), style: p(12.5, w: FontWeight.w800, color: C.t1)),
                        if (reviewCount > 0) ...[
                          const SizedBox(width: 3),
                          Text('($reviewCount)', style: p(11.5, color: C.t4)),
                        ],
                      ],
                      if (rating > 0 && discount > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: C.t4, shape: BoxShape.circle))),
                      if (discount > 0) Text('$discount% off', style: p(12.5, w: FontWeight.w700, color: C.green)),
                    ]),
                  ),

                  // Stock status
                  if (stock != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(outOfStock ? Icons.remove_circle_outline_rounded : Icons.check_circle_outline_rounded, size: 14, color: outOfStock ? C.red : C.green),
                      const SizedBox(width: 5),
                      Text(outOfStock ? 'Out of stock' : (stock <= 5 ? 'Only $stock left' : 'In stock'), style: p(12, w: FontWeight.w700, color: outOfStock ? C.red : (stock <= 5 ? Colors.orange.shade800 : C.green))),
                    ]),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEEF4EA)),
                  const SizedBox(height: 16),

                  // Description — prefers the full long_description once loaded
                  Text('Product Details', style: p(14, w: FontWeight.w800, color: C.t1)),
                  const SizedBox(height: 6),
                  Builder(builder: (_) {
                    String clean(dynamic v) { final t = asStr(v).trim(); return t == 'null' ? '' : t; }
                    final text = clean(longDesc).isNotEmpty ? clean(longDesc) : clean(_data['description']);
                    return Text(text.isNotEmpty ? text : 'No description available for this product yet.',
                      style: p(13, color: C.t3, h: 1.6));
                  }),

                  // Features — clean checklist, not colorful chips
                  if (features.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Key Features', style: p(14, w: FontWeight.w800, color: C.t1)),
                    const SizedBox(height: 10),
                    ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: C.forest.withOpacity(0.75)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f, style: p(13, color: C.t2, h: 1.4))),
                      ]),
                    )),
                  ],

                  // Tags — subtle outlined pills, not bright colors
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: C.border)),
                      child: Text(t, style: p(11, w: FontWeight.w600, color: C.t3)),
                    )).toList()),
                  ],

                  // FAQs — expandable, understated
                  if (faqs.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Questions & Answers', style: p(14, w: FontWeight.w800, color: C.t1)),
                    const SizedBox(height: 10),
                    ...List.generate(faqs.length, (i) {
                      final open = _faqOpen.contains(i);
                      final q = asStr(faqs[i]['q']);
                      final a = asStr(faqs[i]['a']);
                      if (q.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          GestureDetector(
                            onTap: () => setState(() => open ? _faqOpen.remove(i) : _faqOpen.add(i)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(children: [
                                Expanded(child: Text(q, style: p(12.5, w: FontWeight.w700, color: C.t1))),
                                Icon(open ? Icons.remove_rounded : Icons.add_rounded, size: 18, color: C.t3),
                              ]),
                            ),
                          ),
                          if (open) Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Align(alignment: Alignment.centerLeft, child: Text(a, style: p(12, color: C.t3, h: 1.5))),
                          ),
                        ]),
                      );
                    }),
                  ],

                  if (_loadingFull) Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.forest.withOpacity(0.4)))),
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ]),
          ),
        ),

        // ── Sticky Add to Cart ─────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).padding.bottom + 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFEEF4EA))),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -6))],
          ),
          child: GCartStepper(
            qty: ctx.select<CartProvider, int>((c) => c.qty(asInt(_data['id']))),
            onAdd: widget.onAdd,
            onRemove: () { HapticFeedback.lightImpact(); ctx.read<CartProvider>().remove(asInt(_data['id'])); },
            disabled: outOfStock,
            height: 50,
            light: false,
          ),
        ),
      ]),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  final List<dynamic> cart; final VoidCallback onOrdered;
  const CheckoutPage({super.key, required this.cart, required this.onOrdered});
  @override State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _api = Api(); bool _busy = false;
  bool _applyGst = false;
  String _gstState = 'Uttar Pradesh';
  final _gstinCtrl = TextEditingController();
  final _bizCtrl = TextEditingController();

  // Discount coupon
  final _couponCtrl = TextEditingController();
  String? _appliedCode;
  double _discount = 0;
  String? _couponMsg;
  bool _couponBusy = false;
  List<dynamic> _availableCoupons = [];
  bool _couponsLoaded = false; // false until the first /coupons response lands
  double? _couponsLoadedFor; // subtotal the available-coupon list was fetched for
  Timer? _couponsDebounce;
  
  // Track quantity modifications
  late Map<int, int> _qtyMap;
  // Lines removed on this screen (kept in sync with CartProvider)
  final Set<int> _removed = {};

  @override
  void initState() {
    super.initState();
    // Initialize quantity map from cart items
    _qtyMap = {};
    for (var item in widget.cart) {
      final prodId = asInt(asMap(item['product'])['id']);
      _qtyMap[prodId] = asInt(item['qty']);
    }
    _loadCoupons();
  }

  // The server evaluates every coupon against (scope=products, subtotal) and
  // returns eligible-first rows with `eligible`, `reason` and the exact
  // `discount_amount`. Re-fetched whenever the subtotal changes.
  Future<void> _loadCoupons() async {
    final sub = _subtotal;
    if (_couponsLoadedFor == sub) return;
    try {
      final res = await _api.getAvailableCoupons('products', sub);
      // Drop a stale response if the cart moved on meanwhile.
      if (!mounted || _subtotal != sub) return;
      setState(() { _availableCoupons = asList(res); _couponsLoaded = true; _couponsLoadedFor = sub; });
    } catch (_) {/* non-critical */}
  }

  // Light debounce so rapid stepper taps collapse into a single refresh.
  void _scheduleCouponRefresh() {
    _couponsDebounce?.cancel();
    _couponsDebounce = Timer(const Duration(milliseconds: 350), () { if (mounted) _loadCoupons(); });
  }

  List<dynamic> get _visibleCart => widget.cart.where((e) => !_removed.contains(asInt(asMap(e['product'])['id']))).toList();

  double get _subtotal => _visibleCart.fold<double>(0.0, (s, e) => s + asDouble(asMap(e['product'])['price']) * (_qtyMap[asInt(asMap(e['product'])['id'])] ?? asInt(e['qty'])));

  Future<void> _applyCoupon([String? codeArg]) async {
    final code = (codeArg ?? _couponCtrl.text).trim().toUpperCase();
    if (code.isEmpty) { setState(() => _couponMsg = 'Enter a coupon code'); return; }
    setState(() { _couponBusy = true; _couponMsg = null; _couponCtrl.text = code; });
    try {
      final res = await _api.validateCoupon(code, _subtotal);
      if (res is Map && res['code'] != null && res['discount_amount'] != null) {
        setState(() { _appliedCode = asStr(res['code']); _discount = asDouble(res['discount_amount']); _couponMsg = null; });
        if (mounted) showMsg(context, 'Coupon ${res['code']} applied', ok: true);
      } else {
        final msg = (res is Map ? asStr(res['message']) : '');
        setState(() { _appliedCode = null; _discount = 0; _couponMsg = msg.isEmpty ? 'Invalid coupon code' : msg; });
      }
    } on ApiError catch (e) {
      setState(() { _appliedCode = null; _discount = 0; _couponMsg = e.message; });
    } finally { if (mounted) setState(() => _couponBusy = false); }
  }

  void _removeCoupon() => setState(() { _appliedCode = null; _discount = 0; _couponCtrl.clear(); _couponMsg = null; });

  // Stock cap: only enforced when the product actually carries a stock
  // figure from the API — otherwise increment is unrestricted.
  int? _stockFor(int productId) {
    for (final e in widget.cart) {
      final prod = asMap(e['product']);
      if (asInt(prod['id']) == productId) {
        final raw = prod['stock'] ?? prod['available_stock'] ?? prod['quantity_available'];
        if (raw == null) return null;
        return asInt(raw);
      }
    }
    return null;
  }

  void _incrementQty(int productId) {
    final stock = _stockFor(productId);
    final current = _qtyMap[productId] ?? 0;
    if (stock != null && current >= stock) {
      showMsg(context, 'Only $stock left in stock', err: true);
      return;
    }
    setState(() {
      _qtyMap[productId] = current + 1;
    });
    context.read<CartProvider>().setQty(productId, current + 1);
    _scheduleCouponRefresh();
  }

  void _decrementQty(int productId) {
    final current = _qtyMap[productId] ?? 0;
    if (current <= 1) return; // steppers stop at 1 — the ✕ removes the line
    setState(() => _qtyMap[productId] = current - 1);
    context.read<CartProvider>().setQty(productId, current - 1);
    _scheduleCouponRefresh();
  }

  // Delete a whole line regardless of its quantity.
  void _removeLine(int productId, String name) {
    HapticFeedback.lightImpact();
    setState(() { _removed.add(productId); _qtyMap.remove(productId); });
    context.read<CartProvider>().removeLine(productId);
    _scheduleCouponRefresh();
    showMsg(context, '$name removed from cart');
    if (_visibleCart.isEmpty && mounted) Navigator.pop(context);
  }

  void _clearCart() {
    HapticFeedback.lightImpact();
    context.read<CartProvider>().clear();
    showMsg(context, 'Cart cleared');
    Navigator.pop(context);
  }

  @override void dispose() { _couponsDebounce?.cancel(); _gstinCtrl.dispose(); _bizCtrl.dispose(); _couponCtrl.dispose(); super.dispose(); }

  String _getImageUrl(Map<String, dynamic> prod) {
    if (prod['images'] is List && (prod['images'] as List).isNotEmpty) {
      final url = (prod['images'] as List).first.toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    if (prod['image'] != null) {
      final url = prod['image'].toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    return 'https://gkm.gobt.in/uploads/shop/placeholder.jpg';
  }

  @override
  Widget build(BuildContext ctx) {
    final loc = context.watch<LocationProvider>();
    final visibleCart = _visibleCart;
    final totalValue = _subtotal;
    final grand = (totalValue - _discount).clamp(0, double.infinity);

    Widget billLine(String l, String v, {Color? color, bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(l, style: strong ? vx(18, w: FontWeight.w600, color: V.ink) : p(13, color: color ?? V.fog)),
        const Spacer(),
        Text(v, style: strong ? vx(24, w: FontWeight.w600, color: V.ink) : p(13, w: FontWeight.w600, color: color ?? V.ink)),
      ]),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: VPageHeader(
            title: 'Checkout',
            subtitle: '${visibleCart.length} item${visibleCart.length == 1 ? '' : 's'} in your cart',
            trailing: visibleCart.isNotEmpty
              ? GestureDetector(onTap: _clearCart, child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Clear cart', style: p(13, w: FontWeight.w600, color: C.red))))
              : null,
          )),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(ctx).padding.bottom + 120),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ── Deliver to ─────────────────────────────────────────────
              GestureDetector(
                onTap: () async {
                  final picked = await showLocationPicker(context);
                  if (picked != null) loc.save(picked);
                },
                child: GCard(
                  padding: const EdgeInsets.all(16),
                  radius: BorderRadius.circular(22),
                  child: Row(children: [
                    const VOrb(icon: Icons.location_on_outlined, size: 44),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Deliver to', style: p(11.5, color: V.fog)),
                      Text(loc.hasLocation ? loc.label : 'Choose an address', style: vx(17, w: FontWeight.w600, color: V.ink)),
                      if (loc.hasLocation) Text(loc.fullAddress, style: p(12, color: V.fog, h: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),
                    Text('Change', style: p(12.5, w: FontWeight.w600, color: V.leaf)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              GSec('Items'),
              const SizedBox(height: 12),
              GCard(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                radius: BorderRadius.circular(22),
                child: Column(children: [
                  for (var k = 0; k < visibleCart.length; k++) ...[
                    if (k > 0) Container(height: 1, color: V.ink.withValues(alpha: 0.06)),
                    Builder(builder: (_) {
                      final prod = asMap(visibleCart[k]['product']);
                      final prodId = asInt(prod['id']);
                      final q = _qtyMap[prodId] ?? asInt(visibleCart[k]['qty']);
                      final price = asDouble(prod['price']);
                      final stock = _stockFor(prodId);
                      final atMax = stock != null && q >= stock;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(
                              imageUrl: _getImageUrl(prod), width: 58, height: 58, fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: V.mint),
                              errorWidget: (_, __, ___) => Container(color: V.mint, child: const Icon(Icons.local_florist_outlined, color: V.deep)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(asStr(prod['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: p(13.5, w: FontWeight.w600, color: V.ink, h: 1.3)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('₹${(price * q).toStringAsFixed(0)}', style: vx(16, w: FontWeight.w600, color: V.ink)),
                              if (atMax) ...[
                                const SizedBox(width: 8),
                                Text('Max in stock', style: p(10.5, w: FontWeight.w600, color: C.amber)),
                              ],
                            ]),
                          ])),
                          const SizedBox(width: 8),
                          // − qty + ; the minus on qty 1 removes the item
                          Container(
                            height: 36,
                            decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(99)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => q <= 1 ? _removeLine(prodId, asStr(prod['name'])) : _decrementQty(prodId),
                                child: SizedBox(width: 34, height: 36, child: Icon(q <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, size: 17, color: q <= 1 ? C.red : V.deep)),
                              ),
                              Text('$q', style: p(13.5, w: FontWeight.w700, color: V.deep)),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: atMax ? null : () => _incrementQty(prodId),
                                child: SizedBox(width: 34, height: 36, child: Icon(Icons.add_rounded, size: 17, color: atMax ? V.fog.withValues(alpha: 0.4) : V.deep)),
                              ),
                            ]),
                          ),
                        ]),
                      );
                    }),
                  ],
                ]),
              ),
              const SizedBox(height: 24),
              GSec('Coupon'),
              const SizedBox(height: 10),
              _couponSection(),
              const SizedBox(height: 24),
              GSec('Bill'),
              const SizedBox(height: 12),
              GCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                radius: BorderRadius.circular(22),
                child: Column(children: [
                  billLine('Items', '₹${totalValue.toStringAsFixed(0)}'),
                  if (_discount > 0) billLine('Coupon ${_appliedCode ?? ''}', '− ₹${_discount.toStringAsFixed(0)}', color: const Color(0xFF166534)),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: CustomPaint(size: const Size(double.infinity, 1), painter: _HDash())),
                  const SizedBox(height: 6),
                  billLine('To pay', '₹${grand.toStringAsFixed(0)}', strong: true),
                ]),
              ),
              const SizedBox(height: 16),
              // ── GST invoice (business purchases) ───────────────────────
              GCard(
                padding: const EdgeInsets.all(16),
                radius: BorderRadius.circular(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('GST invoice', style: vx(16, w: FontWeight.w600, color: V.ink)),
                      Text('For business purchases', style: p(12, color: V.fog)),
                    ])),
                    Switch.adaptive(
                      value: _applyGst,
                      activeColor: V.leaf,
                      onChanged: (v) => setState(() => _applyGst = v),
                    ),
                  ]),
                  if (_applyGst) ...[
                    const SizedBox(height: 14),
                    Text('State of supply', style: p(12, w: FontWeight.w600, color: V.fog)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _gstState,
                          isExpanded: true,
                          style: p(13.5, color: V.ink),
                          items: const [
                            DropdownMenuItem(value: 'Uttar Pradesh', child: Text('Uttar Pradesh')),
                            DropdownMenuItem(value: 'Delhi', child: Text('Delhi')),
                            DropdownMenuItem(value: 'Maharashtra', child: Text('Maharashtra')),
                            DropdownMenuItem(value: 'Karnataka', child: Text('Karnataka')),
                            DropdownMenuItem(value: 'Tamil Nadu', child: Text('Tamil Nadu')),
                            DropdownMenuItem(value: 'Gujarat', child: Text('Gujarat')),
                            DropdownMenuItem(value: 'Rajasthan', child: Text('Rajasthan')),
                            DropdownMenuItem(value: 'West Bengal', child: Text('West Bengal')),
                            DropdownMenuItem(value: 'Haryana', child: Text('Haryana')),
                            DropdownMenuItem(value: 'Bihar', child: Text('Bihar')),
                            DropdownMenuItem(value: 'Other', child: Text('Other State')),
                          ],
                          onChanged: (v) => setState(() => _gstState = v ?? _gstState),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_gstState == 'Uttar Pradesh' ? 'SGST + CGST will apply (same state)' : 'IGST will apply (other state)',
                      style: p(11.5, color: V.leaf)),
                    const SizedBox(height: 12),
                    _buildGstField(label: 'GSTIN', ctrl: _gstinCtrl, hint: 'e.g. 09AAAAA0000A1Z5'),
                    const SizedBox(height: 10),
                    _buildGstField(label: 'Business name', ctrl: _bizCtrl, hint: 'Registered business name'),
                  ],
                ]),
              ),
            ])),
          ),
        ]),
        // Floating pay button — no bar behind it
        Positioned(
          left: 16, right: 16, bottom: MediaQuery.of(ctx).padding.bottom + 14,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!loc.hasLocation) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text('Choose a delivery address first', style: p(12, color: C.red, w: FontWeight.w600))),
            GBtn(label: 'Pay ₹${grand.toStringAsFixed(0)}', loading: _busy, onTap: (loc.hasLocation && !_busy && visibleCart.isNotEmpty) ? _place : null),
          ]),
        ),
      ]),
    );
  }

  Widget _buildGstField({required String label, required TextEditingController ctrl, required String hint}) =>
      GField(ctrl: ctrl, label: label, hint: hint);

  Widget _couponSection() {
    if (_appliedCode != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(18), border: Border.all(color: V.leaf.withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(Icons.local_offer_outlined, color: V.deep, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('$_appliedCode applied · you save ₹${_discount.toStringAsFixed(0)}', style: p(13.5, w: FontWeight.w600, color: V.deep))),
          GestureDetector(onTap: _removeCoupon, child: Text('Remove', style: p(12.5, w: FontWeight.w600, color: C.red))),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 54,
        padding: const EdgeInsets.only(left: 18, right: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white)),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _couponCtrl,
            textCapitalization: TextCapitalization.characters,
            style: p(14, w: FontWeight.w600, color: V.ink, ls: 1),
            decoration: InputDecoration(
              hintText: 'Enter coupon code', hintStyle: p(13.5, color: V.fog),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              filled: false, isDense: true, contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) { if (_couponMsg != null) setState(() => _couponMsg = null); },
          )),
          GestureDetector(
            onTap: _couponBusy ? null : () => _applyCoupon(),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
              child: _couponBusy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Apply', style: p(13.5, w: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
      if (_couponMsg != null) Padding(padding: const EdgeInsets.only(top: 8, left: 6), child: Text(_couponMsg!, style: p(12, w: FontWeight.w500, color: C.red))),
      if (_couponsLoaded) ..._couponGroups(),
    ]);
  }

  // Eligible coupons first (tap = apply), then "not eligible yet" with the
  // server's reason. Eligibility and savings come from the server.
  List<Widget> _couponGroups() {
    final rows = _availableCoupons.map((c) => asMap(c)).toList();
    if (rows.isEmpty) return const [];
    final eligible = rows.where((c) => c['eligible'] == true).toList();
    final ineligible = rows.where((c) => c['eligible'] != true).toList();
    return [
      const SizedBox(height: 12),
      ...eligible.map(_availableCouponCard),
      if (ineligible.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 8), child: Text('Unlock with a bigger order', style: p(12, color: V.fog))),
        ...ineligible.map(_availableCouponCard),
      ],
    ];
  }

  Widget _availableCouponCard(Map<String, dynamic> c) {
    final eligible = c['eligible'] == true;
    final saving = asDouble(c['discount_amount']);
    final reason = asStr(c['reason']);
    final code = asStr(c['code']);
    final desc = asStr(c['description']);
    return GestureDetector(
      onTap: (eligible && !_couponBusy) ? () => _applyCoupon(code) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: eligible ? V.mint : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: eligible ? V.leaf.withValues(alpha: 0.45) : Colors.white),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eligible ? '$code · save ₹${saving.toStringAsFixed(0)}' : code, style: p(13, w: FontWeight.w700, color: eligible ? V.deep : V.fog, ls: 0.3)),
            if (desc.isNotEmpty || !eligible) Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(eligible ? desc : (reason.isNotEmpty ? reason : 'Not eligible yet'), style: p(11.5, color: eligible ? V.leaf : V.fog))),
          ])),
          if (eligible) Text('Apply', style: p(12.5, w: FontWeight.w600, color: V.deep)),
        ]),
      ),
    );
  }

  Future<void> _place() async {
    // Operations kill-switch — short-circuit before hitting the API. The
    // server enforces this regardless (503 on create endpoints).
    final ops = context.read<OpsStatusProvider>();
    if (ops.paused) { showMsg(context, ops.displayMessage, err: true); return; }
    final loc = context.read<LocationProvider>();
    setState(() => _busy = true);
    try {
      final items = _visibleCart.map((e) {
        final prodId = asInt(asMap(e['product'])['id']);
        return {'product_id': prodId, 'quantity': _qtyMap[prodId] ?? asInt(e['qty'])};
      }).toList();
      final res = await _api.createShopOrder(
        items: items,
        shippingAddress: loc.fullAddress,
        city: loc.city,
        pincode: loc.pincode,
        lat: loc.lat, lng: loc.lng,
        zoneId: loc.zoneId,
        paymentMethod: 'razorpay',
        applyGst: _applyGst,
        shippingState: _applyGst ? _gstState : null,
        billingGstin: _applyGst ? _gstinCtrl.text.trim() : null,
        billingBusinessName: _applyGst ? _bizCtrl.text.trim() : null,
        couponCode: _appliedCode,
      );
      // Order is created pending; pay for it via Razorpay.
      final orderId = asInt(asMap(res)['order_id']);
      final pay = await RazorpayService().pay(type: 'order', orderId: orderId);
      if (!mounted) return;
      if (pay.ok) {
        widget.onOrdered(); // paid — clear the cart
        showMsg(context, 'Payment successful — order placed!', ok: true);
        Navigator.pop(context);
      } else {
        // Cancel/failure: the backend voided the unpaid order (stock + coupon
        // restored). Keep the cart intact so the customer can retry payment.
        showMsg(context, pay.cancelled ? 'Payment cancelled — order not placed.' : (pay.message ?? 'Payment failed'), err: !pay.cancelled);
      }
    } on ApiError catch (e) {
      if (mounted) showMsg(context, e.message, err: true);
    } finally { if (mounted) setState(() => _busy = false); }
  }
}

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override State<MyOrdersScreen> createState() => _MyOrdersState();
}

String _orderAddr(String s) {
  final reg = RegExp(r'-?\d{1,3}\.\d{4,}');
  if (reg.allMatches(s).length >= 2) return 'Service location';
  return s.isEmpty ? '—' : s;
}

String _orderDate(Map<String, dynamic> o) {
  final d = DateTime.tryParse(asStr(o['createdAt'] ?? o['created_at']));
  if (d == null) return '';
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String? _itemImage(Map<String, dynamic> item) {
  final prod = asMap(item['product']);
  for (final v in [prod['images'], item['images']]) {
    final l = asList(v);
    if (l.isNotEmpty && l.first.toString().isNotEmpty) return l.first.toString();
  }
  for (final v in [prod['image'], item['image'], item['product_image']]) {
    final t = asStr(v);
    if (t.isNotEmpty && t != 'null') return t;
  }
  return null;
}

class _Thumb extends StatelessWidget {
  final String? url; final double size;
  const _Thumb({required this.url, this.size = 44});
  @override
  Widget build(BuildContext ctx) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(size * 0.28), border: Border.all(color: Colors.white, width: 2)),
    clipBehavior: Clip.antiAlias,
    child: url == null
      ? Icon(Icons.local_florist_outlined, size: size * 0.45, color: V.deep)
      : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(Icons.local_florist_outlined, size: size * 0.45, color: V.deep)),
  );
}

class _MyOrdersState extends State<MyOrdersScreen> {
  final _api = Api(); List<dynamic> _orders = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getMyShopOrders();
      if (mounted) setState(() { _orders = asList(r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).padding.bottom + 32;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: V.leaf, onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          const SliverToBoxAdapter(child: VPageHeader(title: 'Orders', subtitle: 'Everything you ordered from the shop.')),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (_loading)
            SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 4)))
          else if (_orders.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: GEmpty(
              title: 'No orders yet', sub: 'Plants and supplies you order will appear here.', icon: Icons.shopping_bag_outlined,
              action: GBtn(label: 'Visit the shop', onTap: () => Navigator.pushNamed(ctx, '/shop'), w: 200, h: 48)))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                final o = asMap(_orders[i]);
                final items = asList(o['items']).map(asMap).toList();
                final count = items.fold<int>(0, (t, it) => t + (asInt(it['quantity']) > 0 ? asInt(it['quantity']) : 1));
                final firstName = items.isNotEmpty ? asStr(asMap(items.first['product'])['name'] ?? items.first['product_name']) : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GCard(
                    padding: const EdgeInsets.all(16),
                    radius: BorderRadius.circular(22),
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        // Overlapping product thumbnails
                        SizedBox(
                          width: items.isEmpty ? 44 : 44 + (items.length.clamp(1, 3) - 1) * 26.0,
                          height: 44,
                          child: Stack(children: [
                            if (items.isEmpty) const _Thumb(url: null),
                            for (var k = 0; k < items.length && k < 3; k++)
                              Positioned(left: k * 26.0, child: _Thumb(url: _itemImage(items[k]))),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(firstName.isNotEmpty ? (items.length > 1 ? '$firstName + ${items.length - 1} more' : firstName) : asStr(o['order_number'], 'Order #${o['id']}'),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: vx(16, w: FontWeight.w600, color: V.ink)),
                          const SizedBox(height: 2),
                          Text('$count item${count == 1 ? '' : 's'}  ·  ${_orderDate(o)}', style: p(11.5, color: V.fog)),
                        ])),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        GBadge(asStr(o['status'], 'pending'), small: true),
                        const SizedBox(width: 8),
                        Text(asStr(o['order_number'], '#${o['id']}'), style: p(11, color: V.fog)),
                        const Spacer(),
                        Text('₹${asDouble(o['total_amount']).toStringAsFixed(0)}', style: vx(19, w: FontWeight.w600, color: V.ink)),
                      ]),
                    ]),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 40)).slideY(begin: 0.05, end: 0, delay: Duration(milliseconds: i * 40));
              }, childCount: _orders.length)),
            ),
        ]),
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderDetailScreen({super.key, required this.order});

  static const _steps = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];
  static int _stage(String s) => switch (s) {
    'confirmed' || 'processing' || 'packed' => 1,
    'shipped' || 'out_for_delivery' || 'dispatched' => 2,
    'delivered' || 'completed' => 3,
    _ => 0,
  };

  @override
  Widget build(BuildContext ctx) {
    final items = asList(order['items']).map(asMap).toList();
    final status = asStr(order['status'], 'pending');
    final cancelled = status == 'cancelled' || status == 'failed' || status == 'refunded';
    final gstAmt = asDouble(order['gst_amount']);
    final applyGst = order['apply_gst'] == true || order['apply_gst'] == 1;
    final state = asStr(order['shipping_state'], '');
    final isUP = state.toLowerCase().contains('uttar') || state.toLowerCase() == 'up';
    final subtotal = items.fold<double>(0, (acc, m) => acc + asDouble(m['price']) * asInt(m['quantity']));
    final stage = _stage(status);

    Widget billRow(String l, String v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(l, style: strong ? vx(17, w: FontWeight.w600, color: V.ink) : p(13, color: V.fog)),
        const Spacer(),
        Text(v, style: strong ? vx(20, w: FontWeight.w600, color: V.ink) : p(13, w: FontWeight.w600, color: V.ink)),
      ]),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(children: [
            VRoundBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(ctx)),
            const Spacer(),
            VPillAction(label: 'Invoice', icon: Icons.download_rounded,
              onTap: () => downloadInvoice(ctx, InvoiceType.order, asInt(order['id']))),
          ]),
        ))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: VPod(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(asStr(order['order_number'], '#${order['id']}'), style: p(12.5, color: Colors.white.withValues(alpha: 0.65))),
                const Spacer(),
                Text(_orderDate(order), style: p(12.5, color: Colors.white.withValues(alpha: 0.65))),
              ]),
              const SizedBox(height: 8),
              Text(cancelled ? 'Order ${status.replaceAll('_', ' ')}' : (stage == 3 ? 'Delivered' : 'On its way to you'),
                style: vx(26, w: FontWeight.w600, color: Colors.white, ls: -0.5)),
              const SizedBox(height: 4),
              Text('₹${asDouble(order['total_amount']).toStringAsFixed(0)}  ·  ${asStr(order['payment_method'], 'COD').toUpperCase()}',
                style: p(13, color: V.lime, w: FontWeight.w600)),
              if (!cancelled) ...[
                const SizedBox(height: 18),
                Row(children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle,
                      color: i <= stage ? V.lime : Colors.transparent,
                      border: Border.all(color: i <= stage ? V.lime : Colors.white.withValues(alpha: 0.3), width: 1.5))),
                    if (i < _steps.length - 1)
                      Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: i < stage ? V.lime : Colors.white.withValues(alpha: 0.18))),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  for (var i = 0; i < _steps.length; i++)
                    Expanded(child: Text(_steps[i],
                      textAlign: i == 0 ? TextAlign.left : i == _steps.length - 1 ? TextAlign.right : TextAlign.center,
                      style: p(10.5, w: i == stage ? FontWeight.w600 : FontWeight.w400,
                        color: i <= stage ? Colors.white : Colors.white.withValues(alpha: 0.45)))),
                ]),
              ],
            ]),
          ).animate().fadeIn(duration: 350.ms),
        )),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(ctx).padding.bottom + 32),
          sliver: SliverList(delegate: SliverChildListDelegate([
            GSec('Items'),
            const SizedBox(height: 12),
            GCard(padding: const EdgeInsets.fromLTRB(14, 6, 14, 6), child: Column(children: [
              for (var k = 0; k < items.length; k++) ...[
                if (k > 0) Container(height: 1, color: V.ink.withValues(alpha: 0.06)),
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
                  _Thumb(url: _itemImage(items[k]), size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(asStr(asMap(items[k]['product'])['name'] ?? items[k]['product_name']), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: p(13.5, w: FontWeight.w600, color: V.ink, h: 1.3)),
                    const SizedBox(height: 2),
                    Text('${asInt(items[k]['quantity'])} × ₹${asDouble(items[k]['price']).toStringAsFixed(0)}', style: p(12, color: V.fog)),
                  ])),
                  Text('₹${(asDouble(items[k]['price']) * asInt(items[k]['quantity'])).toStringAsFixed(0)}', style: vx(16, w: FontWeight.w600, color: V.ink)),
                ])),
              ],
            ])),
            const SizedBox(height: 22),
            GSec('Bill'),
            const SizedBox(height: 12),
            GCard(padding: const EdgeInsets.fromLTRB(18, 18, 18, 10), child: Column(children: [
              billRow('Items', '₹${subtotal.toStringAsFixed(0)}'),
              if (applyGst && gstAmt > 0) ...[
                if (isUP) ...[
                  billRow('SGST', '₹${(gstAmt / 2).toStringAsFixed(2)}'),
                  billRow('CGST', '₹${(gstAmt / 2).toStringAsFixed(2)}'),
                ] else
                  billRow('IGST', '₹${gstAmt.toStringAsFixed(2)}'),
              ],
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: CustomPaint(size: const Size(double.infinity, 1), painter: _HDash())),
              const SizedBox(height: 6),
              billRow('Total', '₹${asDouble(order['total_amount']).toStringAsFixed(0)}', strong: true),
            ])),
            const SizedBox(height: 22),
            GSec('Delivery address'),
            const SizedBox(height: 12),
            GCard(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const VOrb(icon: Icons.location_on_outlined, size: 40, dark: false),
              const SizedBox(width: 12),
              Expanded(child: Text(_orderAddr(asStr(order['shipping_address'] ?? order['delivery_address'], '—')),
                style: p(13, color: V.ink, h: 1.45))),
            ])),
          ])),
        ),
      ]),
    );
  }
}

class _HDash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = V.ink.withValues(alpha: 0.18)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) { canvas.drawLine(Offset(x, 0), Offset(x + 3.5, 0), paint); }
  }
  @override
  bool shouldRepaint(_HDash old) => false;
}
