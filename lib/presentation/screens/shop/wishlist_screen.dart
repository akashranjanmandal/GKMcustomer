import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/cart_provider.dart';
import '../../../data/services/wishlist_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import 'product_view_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});
  @override State<WishlistScreen> createState() => _WishlistState();
}

class _WishlistState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh from the backend every time the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WishlistProvider>().load();
    });
  }

  String _imageUrl(Map<String, dynamic> prod) {
    if (prod['images'] is List && (prod['images'] as List).isNotEmpty) {
      final url = (prod['images'] as List).first.toString();
      if (url.isNotEmpty && url != 'null') return url;
    }
    final img = prod['image']?.toString();
    if (img != null && img.isNotEmpty && img != 'null') return img;
    return '';
  }

  void _addToCart(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    context.read<CartProvider>().add(product);
    showMsg(context, '${asStr(product['name'])} added to cart', ok: true);
  }

  void _remove(int productId, String name) {
    HapticFeedback.lightImpact();
    context.read<WishlistProvider>().toggle(productId);
    showMsg(context, '$name removed from wishlist');
  }

  @override
  Widget build(BuildContext ctx) {
    final wl = ctx.watch<WishlistProvider>();
    final items = wl.items;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: GHeader(pb: 16, child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(ctx),
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white))),
          const SizedBox(width: 14),
          Text('My Wishlist', style: p(17, w: FontWeight.w700, color: Colors.white)),
        ]))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: wl.loading && !wl.loaded
            ? SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 4))
            : items.isEmpty
              ? const SliverFillRemaining(hasScrollBody: false, child: GEmpty(
                  title: 'Your wishlist is empty',
                  sub: 'Tap the heart on any product to save it here for later',
                  icon: Icons.favorite_border_rounded))
              : SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                  final row = asMap(items[i]);
                  final product = asMap(row['product']);
                  final productId = asInt(row['product_id'], asInt(product['id']));
                  final name = asStr(product['name']);
                  final price = asDouble(product['price']);
                  final mrp = asDouble(product['mrp']);
                  final catName = asStr(asMap(product['category'])['name']);
                  final img = _imageUrl(product);
                  final stock = product['stock_quantity'] == null ? null : asInt(product['stock_quantity']);
                  final outOfStock = stock != null && stock <= 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => ProductViewScreen.open(ctx, items.map((r) => asMap(asMap(r)['product'])).toList(), i),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: img.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: img, width: 62, height: 62, fit: BoxFit.cover,
                                placeholder: (_, __) => Container(width: 62, height: 62, color: C.subtle),
                                errorWidget: (_, __, ___) => Container(width: 62, height: 62, color: C.subtle, child: Icon(Icons.eco_rounded, color: C.green.withValues(alpha: 0.5), size: 26)))
                            : Container(width: 62, height: 62, color: C.subtle, child: Icon(Icons.eco_rounded, color: C.green.withValues(alpha: 0.5), size: 26)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (catName.isNotEmpty)
                            Text(catName, style: p(10, w: FontWeight.w600, color: C.forest.withValues(alpha: 0.65))),
                          Text(name, style: p(13.5, w: FontWeight.w700, color: C.t1), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Row(children: [
                            Text('₹${price.toStringAsFixed(0)}', style: p(14, w: FontWeight.w800, color: C.green)),
                            if (mrp > price) ...[
                              const SizedBox(width: 5),
                              Text('₹${mrp.toStringAsFixed(0)}', style: p(11, w: FontWeight.w600, color: C.t4, decoration: TextDecoration.lineThrough)),
                            ],
                            if (outOfStock) ...[
                              const SizedBox(width: 8),
                              Text('Out of stock', style: p(10.5, w: FontWeight.w700, color: C.red)),
                            ],
                          ]),
                        ])),
                        const SizedBox(width: 8),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          GestureDetector(
                            onTap: () => _remove(productId, name),
                            child: Container(
                              width: 32, height: 32, alignment: Alignment.center,
                              decoration: BoxDecoration(color: C.red.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.favorite_rounded, size: 17, color: C.red),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: outOfStock ? null : () => _addToCart(product),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: outOfStock ? null : const LinearGradient(colors: [C.green, C.forest], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                color: outOfStock ? C.border : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_shopping_cart_rounded, size: 13, color: outOfStock ? C.t3 : Colors.white),
                                const SizedBox(width: 5),
                                Text('Add', style: p(11.5, w: FontWeight.w800, color: outOfStock ? C.t3 : Colors.white)),
                              ]),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: i * 40));
                }, childCount: items.length)),
        ),
      ]),
    );
  }
}
