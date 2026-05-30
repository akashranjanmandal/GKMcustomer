import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/cart_provider.dart';
import '../../../data/services/location_provider.dart';
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
  String _selectedCat = 'All';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.getShopCategories().catchError((_) => []),
        _api.getShopProducts().catchError((_) => []),
      ]);
      if (mounted) setState(() { 
        _categories = ['All', ...asList(r[0]).map((e) => asStr(asMap(e)['name']))];
        _products = asList(r[1]); 
        _loading = false; 
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _filter() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getShopProducts(
        category: _selectedCat == 'All' ? null : _selectedCat,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );
      if (mounted) setState(() { _products = asList(r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

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
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      crossAxisSpacing: 10, 
                      mainAxisSpacing: 10, 
                      childAspectRatio: 0.65, // Increased height ratio for small screens
                    ),
                    itemCount: _products.length,
                    itemBuilder: (_, i) => _ProductTile(
                      pData: asMap(_products[i]),
                      qty: cart.qty(asInt(_products[i]['id'])),
                      onAdd: () => _addToCart(asMap(_products[i])),
                      onRemove: () => _removeFromCart(asInt(_products[i]['id'])),
                      onTap: () => _showDetail(asMap(_products[i])),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 30)).slideY(begin: 0.05, end: 0),
                  ),
          )),
        ]),
        if (cart.count > 0) _buildCartBar(ctx, cart.count, cart.total),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> pData) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _ProductDetails(pData: pData, onAdd: () => _addToCart(pData)));
  }

  Widget _buildHeader(BuildContext ctx) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(color: C.forest),
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(ctx).padding.top + 8, 20, 24),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Plant Store', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
        Text('Premium seeds, tools & care', style: p(12, color: Colors.white.withOpacity(0.7))),
      ])),
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

  Widget _buildCartBar(BuildContext ctx, int count, double total) => Positioned(left: 16, right: 16, bottom: 20 + MediaQuery.of(ctx).padding.bottom,
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

class _ProductDetails extends StatelessWidget {
  final Map<String, dynamic> pData; final VoidCallback onAdd;
  const _ProductDetails({required this.pData, required this.onAdd});

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
  Widget build(BuildContext ctx) => Container(
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Product image — full width, no broken Material wrapper ──────────
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: CachedNetworkImage(
          imageUrl: _getImageUrl(pData),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 260,
          placeholder: (_, __) => Container(height: 260, color: const Color(0xFFF1F5F1), child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)))),
          errorWidget: (_, __, ___) => Container(
            height: 200,
            color: const Color(0xFFF1F5F1),
            child: Center(child: Icon(Icons.eco_rounded, size: 64, color: C.green.withOpacity(0.4))),
          ),
        ),
      ),

      // ── Info ─────────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name + price row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asStr(pData['name']), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: C.t1)),
              const SizedBox(height: 2),
              Text(asStr(asMap(pData['category'])['name'], 'Garden Care'), style: p(13, w: FontWeight.w600, color: C.forest.withOpacity(0.65))),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${asDouble(pData['price']).toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: C.green)),
              if (asDouble(pData['mrp']) > asDouble(pData['price']))
                Text('₹${asDouble(pData['mrp']).toStringAsFixed(0)}', style: const TextStyle(decoration: TextDecoration.lineThrough, decorationColor: Color(0xFF9AAA94), color: Color(0xFF9AAA94), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEF4EA)),
          const SizedBox(height: 16),

          // Description
          Text('Product Details', style: p(14, w: FontWeight.w800, color: C.t1)),
          const SizedBox(height: 6),
          Text(
            asStr(pData['description'], 'This premium gardening product is designed to keep your garden healthy and vibrant.'),
            style: p(13, color: C.t3, h: 1.6),
          ),
          if (pData['specifications'] != null) ...[
            const SizedBox(height: 14),
            Text('Specifications', style: p(14, w: FontWeight.w800, color: C.t1)),
            const SizedBox(height: 6),
            Text(asStr(pData['specifications']), style: p(13, color: C.t3)),
          ],
          const SizedBox(height: 24),
          GBtn(label: 'Add to Cart', onTap: () { onAdd(); Navigator.pop(ctx); }, bg: C.forest),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ]),
      ),
    ]),
  );
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

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final res = await _api.getAvailableCoupons();
      if (res is List && mounted) setState(() => _availableCoupons = res);
    } catch (_) {/* non-critical */}
  }

  double get _subtotal => widget.cart.fold<double>(0.0, (s, e) => s + asDouble(asMap(e['product'])['price']) * asInt(e['qty']));

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

  @override void dispose() { _gstinCtrl.dispose(); _bizCtrl.dispose(); _couponCtrl.dispose(); super.dispose(); }

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
    final totalValue = widget.cart.fold<double>(0.0, (s, e) => s + asDouble(asMap(e['product'])['price']) * asInt(e['qty']));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.arrow_back, color: Colors.black)), title: Text('Checkout', style: p(18, w: FontWeight.w800, color: Colors.black))),
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
         ...widget.cart.map((e) {
            final prod = asMap(e['product']); final q = asInt(e['qty']);
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
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
                 Text('$q x ₹${asDouble(prod['price']).toStringAsFixed(0)}', style: p(12, color: Colors.black45)),
               ])),
               Text('₹${(asDouble(prod['price']) * q).toStringAsFixed(0)}', style: p(14, w: FontWeight.w800)),
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
      if (_availableCoupons.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('AVAILABLE COUPONS', style: p(11, w: FontWeight.w800, color: C.t3)),
        const SizedBox(height: 8),
        ..._availableCoupons.map((c) => _availableCouponCard(asMap(c))),
      ],
    ]);
  }

  Widget _availableCouponCard(Map<String, dynamic> c) {
    final type = asStr(c['discount_type']);
    final val = asDouble(c['discount_value']);
    final maxDisc = c['max_discount'] == null ? null : asDouble(c['max_discount']);
    final min = asDouble(c['min_order_amount']);
    final eligible = _subtotal >= min;
    final code = asStr(c['code']);
    final desc = asStr(c['description']);
    final label = type == 'percentage'
        ? '${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}% OFF${maxDisc != null && maxDisc > 0 ? ' up to ₹${maxDisc.toStringAsFixed(0)}' : ''}'
        : '₹${val.toStringAsFixed(0)} OFF';
    final shortfall = min - _subtotal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: eligible ? C.green.withValues(alpha: 0.05) : const Color(0xFFF3F7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(code, style: p(13, w: FontWeight.w800, color: C.forest), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(label, style: p(11, w: FontWeight.w800, color: C.green)),
          ]),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(desc, style: p(11, color: C.t3))),
          if (!eligible) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Add ₹${shortfall.toStringAsFixed(0)} more to apply', style: p(11, w: FontWeight.w600, color: Colors.orange.shade800))),
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
    final loc = context.read<LocationProvider>();
    setState(() => _busy = true);
    try {
      final items = widget.cart.map((e) => {'product_id': asInt(asMap(e['product'])['id']), 'quantity': asInt(e['qty'])}).toList();
      await _api.createShopOrder(
        items: items,
        shippingAddress: loc.fullAddress,
        city: loc.city,
        pincode: loc.pincode,
        lat: loc.lat, lng: loc.lng,
        zoneId: loc.zoneId,
        applyGst: _applyGst,
        shippingState: _applyGst ? _gstState : null,
        billingGstin: _applyGst ? _gstinCtrl.text.trim() : null,
        billingBusinessName: _applyGst ? _bizCtrl.text.trim() : null,
        couponCode: _appliedCode,
      );
      widget.onOrdered();
      if (mounted) {
        showMsg(context, 'Order placed successfully!', ok: true);
        Navigator.pop(context);
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

  void _showBill(BuildContext ctx) {
    final items = asList(order['items']);
    final gstAmt = asDouble(order['gst_amount']);
    final total = asDouble(order['total_amount']);
    // Real product subtotal from line items — NOT total - gstAmt (services break that).
    double productSubtotal = 0;
    for (final i in items) {
      final m = asMap(i);
      productSubtotal += asDouble(m['price']) * asInt(m['quantity']);
    }
    // Anything left (total - products - GST) belongs to service bookings on the order.
    final serviceTotal = (total - productSubtotal - gstAmt).clamp(0, double.infinity).toDouble();
    final applyGst = order['apply_gst'] == true || order['apply_gst'] == 1;
    final state = asStr(order['shipping_state'], '');
    final isUP = state.toLowerCase().contains('uttar') || state.toLowerCase() == 'up';

    // Effective GST rate: prefer recomputing from gstAmt/productSubtotal so mixed-rate
    // carts still render a sensible value. Fall back to first product's gst_rate.
    int gstRate = 0;
    if (gstAmt > 0 && productSubtotal > 0) {
      gstRate = ((gstAmt / productSubtotal) * 100).round();
    } else if (items.isNotEmpty) {
      gstRate = asInt(asMap(asMap(items.first)['product'])['gst_rate']);
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BillSheet(
        order: order,
        items: items,
        subtotal: productSubtotal,
        serviceTotal: serviceTotal,
        gstAmt: gstAmt,
        total: total,
        applyGst: applyGst,
        isUP: isUP,
        gstRate: gstRate,
        cleanAddr: _cleanAddr,
      ),
    );
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
              onTap: () => _showBill(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Bill', style: p(12, w: FontWeight.w700, color: Colors.white)),
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

class _BillSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<dynamic> items;
  final double subtotal, serviceTotal, gstAmt, total;
  final bool applyGst, isUP;
  final int gstRate;
  final String Function(String) cleanAddr;

  const _BillSheet({
    required this.order, required this.items,
    required this.subtotal, required this.serviceTotal,
    required this.gstAmt, required this.total,
    required this.applyGst, required this.isUP, required this.gstRate,
    required this.cleanAddr,
  });

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: p(13, w: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? C.t2)),
      Text(value, style: p(13, w: bold ? FontWeight.w900 : FontWeight.w600, color: color ?? C.t1)),
    ]),
  );

  @override
  Widget build(BuildContext ctx) {
    final dateStr = asStr(order['createdAt'] ?? order['created_at'], '');
    final gstin = asStr(order['billing_gstin'], '');
    final bizName = asStr(order['billing_business_name'], '');

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.forest.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_rounded, color: C.forest, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tax Invoice', style: p(16, w: FontWeight.w900, color: C.t1)),
            Text('GharKaMali — GSTIN: 09AAAAA0000A1Z5', style: p(10, color: C.t3)),
          ])),
        ]),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // Customer / order meta
        if (bizName.isNotEmpty) Text(bizName, style: p(14, w: FontWeight.w800, color: C.t1)),
        if (gstin.isNotEmpty) Text('GSTIN: $gstin', style: p(12, color: C.t3)),
        const SizedBox(height: 4),
        Text('Order: ${asStr(order['order_number'], '#${order['id']}')}', style: p(12, color: C.t3)),
        Text('Date: ${dateStr.length >= 10 ? dateStr.substring(0, 10) : '—'}', style: p(12, color: C.t3)),
        Text('Supply to: ${isUP ? 'Uttar Pradesh (Intra-state)' : 'Inter-state'}', style: p(12, color: C.t3)),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Items
        ...items.map((i) {
          final item = asMap(i);
          final product = asMap(item['product']);
          final lineTotal = asDouble(item['price']) * asInt(item['quantity']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asStr(product['name'] ?? item['product_name']), style: p(13, w: FontWeight.w700, color: C.t1)),
                Text('${item['quantity']} x ₹${asDouble(item['price']).toStringAsFixed(2)}', style: p(11, color: C.t3)),
              ])),
              Text('₹${lineTotal.toStringAsFixed(2)}', style: p(13, w: FontWeight.w700)),
            ]),
          );
        }),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Totals
        _row('Products subtotal', '₹${subtotal.toStringAsFixed(2)}'),
        if (serviceTotal > 0) _row('Services / Mali booking', '₹${serviceTotal.toStringAsFixed(2)}'),
        if (applyGst && gstAmt > 0) ...[
          if (isUP) ...[
            _row('SGST${gstRate > 0 ? ' @ ${(gstRate / 2).toStringAsFixed(gstRate.isOdd ? 1 : 0)}%' : ''}', '₹${(gstAmt / 2).toStringAsFixed(2)}', color: C.forest),
            _row('CGST${gstRate > 0 ? ' @ ${(gstRate / 2).toStringAsFixed(gstRate.isOdd ? 1 : 0)}%' : ''}', '₹${(gstAmt / 2).toStringAsFixed(2)}', color: C.forest),
          ] else
            _row('IGST${gstRate > 0 ? ' @ $gstRate%' : ''}', '₹${gstAmt.toStringAsFixed(2)}', color: C.forest),
        ],
        const Divider(height: 24),
        _row('Total', '₹${total.toStringAsFixed(2)}', bold: true, color: C.green),

        if (!applyGst || gstAmt == 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text('GST was not claimed for this order. To get a GST invoice, enable the GST option at checkout.', style: p(11, color: Colors.orange.shade800)),
          ),
        ],

        const SizedBox(height: 20),
        // Footer note
        Center(child: Text('This is a computer-generated invoice.\nCIN: U01500UP2024PTC000001', style: p(10, color: C.t4), textAlign: TextAlign.center)),
      ]),
    );
  }
}