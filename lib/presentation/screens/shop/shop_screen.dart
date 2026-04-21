import 'dart:async';
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.70),
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
                  child: Image.network(imgUrl(pData['images'] ?? pData['image']), fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Center(child: Icon(Icons.eco_rounded, color: C.green.withOpacity(0.4), size: 48))),
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
                        _QtyBtn(icon: Icons.remove_rounded, onTap: widget.onRemove),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${widget.qty}', style: p(14, w: FontWeight.w900, color: C.forest))),
                        _QtyBtn(icon: Icons.add_rounded, onTap: widget.onAdd),
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
            Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (catName.isNotEmpty)
                Text(catName, style: p(10, w: FontWeight.w600, color: C.forest.withOpacity(0.65))),
              const SizedBox(height: 2),
              Text(asStr(pData['name']), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: C.green)),
                if (mrp > price) ...[
                  const SizedBox(width: 6),
                  Text('₹${mrp.toStringAsFixed(0)}', style: const TextStyle(decoration: TextDecoration.lineThrough, decorationColor: Color(0xFF9AAA94), color: Color(0xFF9AAA94), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: C.forest.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 16, color: C.forest),
    ),
  );
}

class _ProductDetails extends StatelessWidget {
  final Map<String, dynamic> pData; final VoidCallback onAdd;
  const _ProductDetails({required this.pData, required this.onAdd});
  @override
  Widget build(BuildContext ctx) => Container(
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Product image — full width, no broken Material wrapper ──────────
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Image.network(
          imgUrl(pData['images'] ?? pData['image']),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 260,
          errorBuilder: (_,__,___) => Container(
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
               ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imgUrl(prod['image']), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[100], child: const Icon(Icons.eco)))),
               const SizedBox(width: 12),
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(asStr(prod['name']), style: p(14, w: FontWeight.w700), maxLines: 1),
                 Text('$q x ₹${asDouble(prod['price']).toStringAsFixed(0)}', style: p(12, color: Colors.black45)),
               ])),
               Text('₹${(asDouble(prod['price']) * q).toStringAsFixed(0)}', style: p(14, w: FontWeight.w800)),
            ]));
         }),
         const Divider(height: 48),
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Text('Order Total', style: p(18, w: FontWeight.w900)),
           Text('₹${totalValue.toStringAsFixed(0)}', style: p(24, w: FontWeight.w900, color: C.green)),
         ]),
         const SizedBox(height: 60),
         GBtn(label: 'Confirm Order', loading: _busy, onTap: (loc.hasLocation && !_busy) ? _place : null, bg: C.forest),
         if (!loc.hasLocation) Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: Text('Please select an address first', style: p(12, color: Colors.red[400], w: FontWeight.w600)))),
      ])),
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
  @override
  Widget build(BuildContext ctx) => Scaffold(backgroundColor: C.bg, body: CustomScrollView(slivers: [SliverToBoxAdapter(child: GHeader(pb: 16, child: Row(children: [GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white))), const SizedBox(width: 14), Text('My Orders', style: p(17, w: FontWeight.w700, color: Colors.white))]))), SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), sliver: _loading ? SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 4)) : _orders.isEmpty ? const SliverFillRemaining(child: GEmpty(title: 'No orders yet', sub: 'Your shop orders will appear here', icon: Icons.shopping_bag_outlined)) : SliverList(delegate: SliverChildBuilderDelegate((_, i) { final o = _orders[i]; final status = asStr(o['status'], 'pending'); return Padding(padding: const EdgeInsets.only(bottom: 12), child: GCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(asStr(o['order_number'], '#${o['id']}'), style: p(14, w: FontWeight.w700, color: C.t1))), GBadge(status)]), const SizedBox(height: 8), Text('₹${asDouble(o['total_amount']).toStringAsFixed(0)}', style: p(16, w: FontWeight.w800, color: C.green)), const SizedBox(height: 4), Text(asStr(o['shipping_address'] ?? o['delivery_address'], '—'), style: p(11, color: C.t3), maxLines: 1, overflow: TextOverflow.ellipsis)]))).animate().fadeIn(delay: Duration(milliseconds: i * 40)); }, childCount: _orders.length)))]));
}
