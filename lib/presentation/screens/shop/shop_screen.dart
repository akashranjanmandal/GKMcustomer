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

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
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
  @override void dispose() { _searchCtrl.dispose(); _scrollCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

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

  void _addToCart(Map<String, dynamic> data) {
    HapticFeedback.lightImpact();
    context.read<CartProvider>().add(data);
  }

  void _removeFromCart(int id) {
    HapticFeedback.lightImpact();
    context.read<CartProvider>().remove(id);
  }

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(children: [
        Column(children: [
          _buildHeader(ctx),
          _buildSearchSection(),
          Expanded(child: RefreshIndicator(
            onRefresh: _load, color: C.forest,
            child: _loading
              ? GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75), itemCount: 6, itemBuilder: (_,__) => const GSkelCard())
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
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.65,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _ProductTile(
                              pData: asMap(_products[i]),
                              qty: cart.qty(asInt(_products[i]['id'])),
                              onAdd: () => _addToCart(asMap(_products[i])),
                              onRemove: () => _removeFromCart(asInt(_products[i]['id'])),
                              onTap: () => _showDetail(asMap(_products[i])),
                            ).animate().fadeIn(delay: Duration(milliseconds: (i % 24) * 30)).slideY(begin: 0.05, end: 0),
                            childCount: _products.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
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
    );
  }

  void _showDetail(Map<String, dynamic> pData) => showProductDetailSheet(context, pData);

  Widget _buildHeader(BuildContext ctx) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(color: C.forest),
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(ctx).padding.top + 8, 20, 24),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Plant Shop', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
        Text('Premium seeds, tools & care', style: p(12, color: Colors.white.withOpacity(0.7))),
      ])),
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, '/wishlist'),
        child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22)),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, '/shop/orders'),
        child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.history_rounded, color: Colors.white, size: 22)),
      ),
    ]),
  );

  Widget _buildSearchSection() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Search: single container, stripped TextField ──────────────────
      Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7F0),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: C.border, width: 1.2),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: C.t4, size: 20),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _searchCtrl,
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
        ]),
      ),
      const SizedBox(height: 12),
      // ── Category pills ────────────────────────────────────────────────
      SizedBox(height: 36, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final sel = _categories[i] == _selectedCat;
          return GestureDetector(
            onTap: () { setState(() => _selectedCat = _categories[i]); _filter(); },
            child: AnimatedContainer(
              duration: 200.ms,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(colors: [C.green, C.forest], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                color: sel ? null : const Color(0xFFF3F7F0),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: sel ? Colors.transparent : C.border, width: 1.2),
              ),
              child: Center(child: Text(
                _categories[i],
                style: p(12, w: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : C.t2),
              )),
            ),
          );
        },
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

// Opens the product detail sheet from anywhere (shop grid, wishlist screen).
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

class _ProductTile extends StatefulWidget {
  final Map<String, dynamic> pData; final int qty; final VoidCallback onAdd, onRemove, onTap;
  const _ProductTile({required this.pData, required this.qty, required this.onAdd, required this.onRemove, required this.onTap});
  @override State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _pressed = false;

  String _getImageUrl(Map<String, dynamic> pData) {
    if (pData['images'] is List && (pData['images'] as List).isNotEmpty) {
      final url = (pData['images'] as List).first.toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    if (pData['image'] != null) {
      final url = pData['image'].toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    return 'https://gkm.gobt.in/uploads/shop/placeholder.jpg';
  }

  @override
  Widget build(BuildContext ctx) {
    final pData = widget.pData;
    final price = asDouble(pData['price']);
    final mrp   = asDouble(pData['mrp']);
    final discount = mrp > price ? ((mrp - price) / mrp * 100).round() : 0;
    final catName = asStr(asMap(pData['category'])['name'], '');

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Image area ──────────────────────────────────────────────
            Stack(children: [
              Container(
                height: 148, width: double.infinity,
                decoration: const BoxDecoration(color: Color(0xFFF1F5F1), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: CachedNetworkImage(
                    imageUrl: _getImageUrl(pData),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 148,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50))),
                    errorWidget: (_, __, ___) => Center(child: Icon(Icons.eco_rounded, color: C.green.withOpacity(0.4), size: 48)),
                  ),
                ),
              ),
              // Wishlist heart
              Positioned(top: 10, left: 10, child: GWishHeart(product: pData, size: 30)),
              // Discount badge
              if (discount > 0)
                Positioned(top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(8)),
                    child: Text('$discount% OFF', style: p(9, w: FontWeight.w900, color: Colors.white)),
                  )),
              // Cart qty counter / add button
              Positioned(bottom: 10, right: 10,
                child: widget.qty > 0
                  ? Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _QtyBtn(icon: Icons.remove_rounded, onTap: widget.onRemove, small: true),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('${widget.qty}', style: p(13, w: FontWeight.w900, color: C.forest))),
                        _QtyBtn(icon: Icons.add_rounded, onTap: widget.onAdd, small: true),
                      ]),
                    )
                  : GestureDetector(
                      onTap: widget.onAdd,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [C.green, C.forest], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: C.green.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                    ),
              ),
            ]),

            // ── Info area ────────────────────────────────────────────────
            Expanded(
              child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (catName.isNotEmpty)
                  Text(catName, style: p(9, w: FontWeight.w600, color: C.forest.withOpacity(0.65))),
                const SizedBox(height: 2),
                Text(asStr(pData['name']), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w900, color: C.green)),
                  if (mrp > price) ...[
                    const SizedBox(width: 4),
                    Flexible(child: Text('₹${mrp.toStringAsFixed(0)}', style: const TextStyle(decoration: TextDecoration.lineThrough, decorationColor: Color(0xFF9AAA94), color: Color(0xFF9AAA94), fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ])),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool small;
  const _QtyBtn({required this.icon, required this.onTap, this.small = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: small ? 26 : 32, height: small ? 26 : 32,
      decoration: BoxDecoration(color: C.forest.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: small ? 14 : 16, color: C.forest),
    ),
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
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
                  Positioned(top: 8, right: 12, child: GWishHeart(product: _data, size: 38)),
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
                  Text(
                    longDesc.isNotEmpty ? longDesc : asStr(_data['description'], 'This premium gardening product is designed to keep your garden healthy and vibrant.'),
                    style: p(13, color: C.t3, h: 1.6),
                  ),

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
          child: GBtn(label: outOfStock ? 'Out of Stock' : 'Add to Cart', onTap: outOfStock ? null : () { widget.onAdd(); Navigator.pop(ctx); }, bg: C.forest),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.arrow_back, color: Colors.black)),
        title: Text('Checkout', style: p(18, w: FontWeight.w800, color: Colors.black)),
        actions: [
          if (visibleCart.isNotEmpty)
            TextButton(onPressed: _clearCart, child: Text('Clear cart', style: p(13, w: FontWeight.w700, color: C.red))),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         GSec('Service Address'),
         const SizedBox(height: 12),
         GestureDetector(
           onTap: () async {
             final picked = await showLocationPicker(context);
             if (picked != null) loc.save(picked);
           },
           child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05))), child: Row(children: [
             const Icon(Icons.location_on_rounded, color: C.green), const SizedBox(width: 14),
             Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(loc.hasLocation ? loc.label : 'Select Service Address', style: p(14, w: FontWeight.w700)),
               if (loc.hasLocation) Text(loc.fullAddress, style: p(12, color: Colors.black45), maxLines: 2),
             ])),
             const Icon(Icons.chevron_right_rounded, color: Colors.black26),
           ])),
         ),
         const SizedBox(height: 32),
         GSec('Order Summary'),
         const SizedBox(height: 12),
         ...visibleCart.map((e) {
            final prod = asMap(e['product']);
            final prodId = asInt(prod['id']);
            final q = _qtyMap[prodId] ?? asInt(e['qty']);
            final price = asDouble(prod['price']);
            final stock = _stockFor(prodId);
            final atMax = stock != null && q >= stock;
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
               ClipRRect(
                 borderRadius: BorderRadius.circular(8),
                 child: CachedNetworkImage(
                   imageUrl: _getImageUrl(prod),
                   width: 48, height: 48, fit: BoxFit.cover,
                   placeholder: (_, __) => Container(color: Colors.grey[100]),
                   errorWidget: (_, __, ___) => Container(color: Colors.grey[100], child: const Icon(Icons.eco)),
                 )
               ),
               const SizedBox(width: 12),
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(asStr(prod['name']), style: p(14, w: FontWeight.w700), maxLines: 1),
                 Text('₹${price.toStringAsFixed(0)}', style: p(12, color: Colors.black45)),
                 if (atMax) Text('Max stock reached', style: p(10, w: FontWeight.w600, color: Colors.orange.shade800)),
               ])),
               // Quantity control — increment disables once stock (if known) is reached
               Container(
                 decoration: BoxDecoration(color: const Color(0xFFF3F7F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                 child: Row(mainAxisSize: MainAxisSize.min, children: [
                   GestureDetector(
                     onTap: () => _decrementQty(prodId),
                     child: Container(
                       width: 28, height: 28,
                       alignment: Alignment.center,
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                       child: Icon(Icons.remove_rounded, size: 16, color: C.forest),
                     ),
                   ),
                   Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('$q', style: p(13, w: FontWeight.w900, color: C.forest))),
                   GestureDetector(
                     onTap: atMax ? null : () => _incrementQty(prodId),
                     child: Container(
                       width: 28, height: 28,
                       alignment: Alignment.center,
                       decoration: BoxDecoration(color: Colors.white.withOpacity(atMax ? 0.2 : 0.5), borderRadius: BorderRadius.circular(8)),
                       child: Icon(Icons.add_rounded, size: 16, color: atMax ? C.t4 : C.forest),
                     ),
                   ),
                 ]),
               ),
               const SizedBox(width: 10),
               Text('₹${(price * q).toStringAsFixed(0)}', style: p(14, w: FontWeight.w800)),
               const SizedBox(width: 8),
               // Remove this line entirely, regardless of quantity
               GestureDetector(
                 onTap: () => _removeLine(prodId, asStr(prod['name'])),
                 child: Container(
                   width: 28, height: 28,
                   alignment: Alignment.center,
                   decoration: BoxDecoration(color: C.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                   child: const Icon(Icons.close_rounded, size: 16, color: C.red),
                 ),
               ),
            ]));
         }),
         const Divider(height: 48),

         // ── Coupon ───────────────────────────────────────────────────────
         _couponSection(),
         const SizedBox(height: 20),

         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Text('Subtotal', style: p(13, color: C.t2)),
           Text('₹${totalValue.toStringAsFixed(0)}', style: p(13, w: FontWeight.w700, color: C.t1)),
         ]),
         if (_discount > 0) ...[
           const SizedBox(height: 8),
           Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             Text('Discount (${_appliedCode ?? ''})', style: p(13, color: C.green, w: FontWeight.w700)),
             Text('− ₹${_discount.toStringAsFixed(0)}', style: p(13, w: FontWeight.w800, color: C.green)),
           ]),
         ],
         const SizedBox(height: 12),
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Text('Order Total', style: p(18, w: FontWeight.w900)),
           Text('₹${(totalValue - _discount).clamp(0, double.infinity).toStringAsFixed(0)}', style: p(24, w: FontWeight.w900, color: C.green)),
         ]),
         const SizedBox(height: 24),

         // ── GST section ──────────────────────────────────────────────────
         Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: const Color(0xFFF3F7F0),
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: C.border, width: 1.2),
           ),
           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Row(children: [
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text('Claim GST Invoice', style: p(14, w: FontWeight.w800, color: C.t1)),
                 Text('For business purchases only', style: p(11, color: C.t3)),
               ])),
               GestureDetector(
                 onTap: () => setState(() => _applyGst = !_applyGst),
                 child: AnimatedContainer(
                   duration: const Duration(milliseconds: 200),
                   width: 46, height: 26,
                   padding: const EdgeInsets.all(3),
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(13),
                     color: _applyGst ? C.forest : Colors.black26,
                   ),
                   child: AnimatedAlign(
                     duration: const Duration(milliseconds: 200),
                     alignment: _applyGst ? Alignment.centerRight : Alignment.centerLeft,
                     child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                   ),
                 ),
               ),
             ]),
             if (_applyGst) ...[
               const SizedBox(height: 16),
               Text('State of Supply', style: p(12, w: FontWeight.w700, color: C.t2)),
               const SizedBox(height: 6),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12),
                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                 child: DropdownButtonHideUnderline(
                   child: DropdownButton<String>(
                     value: _gstState,
                     isExpanded: true,
                     style: p(13, color: C.t1),
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
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(color: _gstState == 'Uttar Pradesh' ? C.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                 child: Text(
                   _gstState == 'Uttar Pradesh' ? 'SGST + CGST will be applied (intra-state)' : 'IGST will be applied (inter-state)',
                   style: p(11, w: FontWeight.w600, color: _gstState == 'Uttar Pradesh' ? C.forest : Colors.orange.shade800),
                 ),
               ),
               const SizedBox(height: 12),
               _buildGstField(label: 'GSTIN', ctrl: _gstinCtrl, hint: 'e.g. 09AAAAA0000A1Z5'),
               const SizedBox(height: 8),
               _buildGstField(label: 'Business Name', ctrl: _bizCtrl, hint: 'Registered business name'),
             ],
           ]),
         ),

         const SizedBox(height: 32),
         GBtn(label: 'Confirm Order', loading: _busy, onTap: (loc.hasLocation && !_busy) ? _place : null, bg: C.forest),
         if (!loc.hasLocation) Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: Text('Please select an address first', style: p(12, color: Colors.red[400], w: FontWeight.w600)))),
      ])),
    );
  }

  Widget _buildGstField({required String label, required TextEditingController ctrl, required String hint}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: p(12, w: FontWeight.w700, color: C.t2)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: p(13, color: C.t1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: C.t4, fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.forest)),
        ),
      ),
    ],
  );

  Widget _couponSection() {
    if (_appliedCode != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.green.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.local_offer_rounded, color: C.green, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('$_appliedCode applied', style: p(14, w: FontWeight.w800, color: C.green))),
          GestureDetector(onTap: _removeCoupon, child: Text('REMOVE', style: p(12, w: FontWeight.w800, color: C.t3))),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(
          controller: _couponCtrl,
          textCapitalization: TextCapitalization.characters,
          style: p(14, w: FontWeight.w700, color: C.t1),
          decoration: InputDecoration(
            hintText: 'COUPON CODE',
            hintStyle: TextStyle(color: C.t4, fontSize: 13, letterSpacing: 1),
            filled: true, fillColor: const Color(0xFFF9F9F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.forest)),
          ),
          onChanged: (_) { if (_couponMsg != null) setState(() => _couponMsg = null); },
        )),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _couponBusy ? null : () => _applyCoupon(),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(12)),
            child: _couponBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Apply', style: p(14, w: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
      if (_couponMsg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_couponMsg!, style: p(12, w: FontWeight.w600, color: Colors.red[400]))),
      if (_couponsLoaded) ..._couponGroups(),
    ]);
  }

  // Eligible coupons first (tap = apply), then "not eligible yet" rows greyed
  // out with the server's reason. Eligibility and savings come from the
  // server response — no client-side min-order guesswork.
  List<Widget> _couponGroups() {
    final rows = _availableCoupons.map((c) => asMap(c)).toList();
    if (rows.isEmpty) return const [];
    final eligible = rows.where((c) => c['eligible'] == true).toList();
    final ineligible = rows.where((c) => c['eligible'] != true).toList();
    return [
      const SizedBox(height: 16),
      if (eligible.isNotEmpty) ...[
        Text('ELIGIBLE COUPONS', style: p(11, w: FontWeight.w800, color: C.green)),
        const SizedBox(height: 8),
        ...eligible.map(_availableCouponCard),
      ] else
        Text('No coupons eligible yet', style: p(12, w: FontWeight.w600, color: C.t3)),
      if (ineligible.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('NOT ELIGIBLE YET', style: p(11, w: FontWeight.w800, color: C.t3)),
        const SizedBox(height: 8),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: eligible ? C.green.withValues(alpha: 0.06) : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: eligible ? C.green.withValues(alpha: 0.45) : C.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(code, style: p(13, w: FontWeight.w800, color: eligible ? C.forest : C.t3), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (eligible) ...[
              const SizedBox(width: 8),
              Text('Save ₹${saving.toStringAsFixed(0)}', style: p(11, w: FontWeight.w800, color: C.green)),
            ],
          ]),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(desc, style: p(11, color: C.t3))),
          if (!eligible) Padding(padding: const EdgeInsets.only(top: 2), child: Text(reason.isNotEmpty ? reason : 'Not eligible yet', style: p(10, w: FontWeight.w600, color: C.t3))),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: (eligible && !_couponBusy) ? () => _applyCoupon(code) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: eligible ? C.forest : C.border, borderRadius: BorderRadius.circular(8)),
            child: Text('APPLY', style: p(11, w: FontWeight.w800, color: eligible ? Colors.white : C.t3)),
          ),
        ),
      ]),
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
  String _cleanAddr(String s) {
    final reg = RegExp(r'-?\d{1,3}\.\d{4,}');
    if (reg.allMatches(s).length >= 2) return 'Service Location';
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: C.bg, 
    body: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: GHeader(pb: 16, child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(ctx), 
          child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), 
          child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white))), 
        const SizedBox(width: 14), 
        Text('My Orders', style: p(17, w: FontWeight.w700, color: Colors.white))
      ]))), 
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), 
        sliver: _loading 
          ? SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 4)) 
          : _orders.isEmpty 
            ? const SliverFillRemaining(child: GEmpty(title: 'No orders yet', sub: 'Your shop orders will appear here', icon: Icons.shopping_bag_outlined)) 
            : SliverList(delegate: SliverChildBuilderDelegate((_, i) { 
                final o = asMap(_orders[i]); 
                final status = asStr(o['status'], 'pending'); 
                final dateStr = asStr(o['createdAt'] ?? o['created_at'], '');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12), 
                  child: GCard(
                    padding: const EdgeInsets.all(16), 
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(asStr(o['order_number'], '#${o['id']}'), style: p(14, w: FontWeight.w700, color: C.t1))), 
                        GBadge(status)
                      ]), 
                      const SizedBox(height: 8), 
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('₹${asDouble(o['total_amount']).toStringAsFixed(0)}', style: p(16, w: FontWeight.w800, color: C.green)), 
                        Text(dateStr.length >= 10 ? dateStr.substring(0,10) : '—', style: p(11, color: C.t4)),
                      ]),
                      const SizedBox(height: 6), 
                      Text(_cleanAddr(asStr(o['shipping_address'] ?? o['delivery_address'], '—')), style: p(11, color: C.t3), maxLines: 1, overflow: TextOverflow.ellipsis)
                    ])
                  )
                ).animate().fadeIn(delay: Duration(milliseconds: i * 40)); 
              }, childCount: _orders.length)
            )
      )
    ]));
}

class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderDetailScreen({super.key, required this.order});

  String _cleanAddr(String s) {
    final reg = RegExp(r'-?\d{1,3}\.\d{4,}');
    if (reg.allMatches(s).length >= 2) return 'Service Location';
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext ctx) {
    final items = asList(order['items']);
    final status = asStr(order['status'], 'pending');
    final dateStr = asStr(order['createdAt'] ?? order['created_at'], '');
    final gstAmt = asDouble(order['gst_amount']);
    final applyGst = order['apply_gst'] == true || order['apply_gst'] == 1;
    final state = asStr(order['shipping_state'], '');
    final isUP = state.toLowerCase().contains('uttar') || state.toLowerCase() == 'up';

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: GHeader(pb: 52, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white70),
                const SizedBox(width: 4),
                Text('My Orders', style: p(13, color: Colors.white70)),
              ])),
            GestureDetector(
              onTap: () => downloadInvoice(ctx, InvoiceType.order, asInt(order['id'])),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Download Invoice', style: p(12, w: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(asStr(order['order_number'], '#${order['id']}'), style: p(20, w: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          GBadge(status),
        ]))),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Order Info
            GCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(99))),
                const SizedBox(width: 8),
                Text('ORDER DETAILS', style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.8)),
              ]),
              const SizedBox(height: 16),
              GDetailRow(icon: Icons.location_on_rounded, label: 'ADDRESS', value: _cleanAddr(asStr(order['shipping_address'] ?? order['delivery_address'], '—'))),
              GDetailRow(icon: Icons.calendar_today_rounded, label: 'DATE', value: dateStr.length >= 10 ? dateStr.substring(0,10) : '—'),
              GDetailRow(icon: Icons.payments_rounded, label: 'METHOD', value: asStr(order['payment_method'], 'COD').toUpperCase()),
              if (applyGst && gstAmt > 0) ...[
                GDetailRow(
                  icon: Icons.inventory_2_rounded, label: 'SUBTOTAL',
                  value: '₹${items.fold<double>(0, (acc, it) {
                    final m = asMap(it);
                    return acc + asDouble(m['price']) * asInt(m['quantity']);
                  }).toStringAsFixed(0)}',
                ),
                if (isUP) ...[
                  GDetailRow(icon: Icons.percent_rounded, label: 'SGST', value: '₹${(gstAmt / 2).toStringAsFixed(2)}'),
                  GDetailRow(icon: Icons.percent_rounded, label: 'CGST', value: '₹${(gstAmt / 2).toStringAsFixed(2)}'),
                ] else
                  GDetailRow(icon: Icons.percent_rounded, label: 'IGST', value: '₹${gstAmt.toStringAsFixed(2)}'),
              ],
              GDetailRow(icon: Icons.receipt_rounded, label: 'TOTAL', value: '₹${asDouble(order['total_amount']).toStringAsFixed(0)}'),
            ])),

            const SizedBox(height: 16),
            GSec('Order Items'),
            const SizedBox(height: 12),
            ...items.map((i) {
              final item = asMap(i);
              final product = asMap(item['product']);
              return Padding(padding: const EdgeInsets.only(bottom: 12),
                child: GCard(padding: const EdgeInsets.all(12), child: Row(children: [
                   Container(width: 44, height: 44, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.eco_rounded, color: C.green, size: 20)),
                   const SizedBox(width: 12),
                   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                     Text(asStr(product['name'] ?? item['product_name']), style: p(13, w: FontWeight.w700, color: C.t1)),
                     Text('${item['quantity']} x ₹${asDouble(item['price']).toStringAsFixed(0)}', style: p(11, color: C.t3)),
                   ])),
                   Text('₹${(asDouble(item['price']) * asInt(item['quantity'])).toStringAsFixed(0)}', style: p(14, w: FontWeight.w800, color: C.t1)),
                ])),
              );
            }),
          ])),
        ),
      ]),
    );
  }
}
