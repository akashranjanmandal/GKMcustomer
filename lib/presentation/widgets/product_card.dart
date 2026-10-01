import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/services/api.dart';
import '../../data/services/cart_provider.dart';
import '../theme/theme.dart';
import 'widgets.dart';

// ─── Product card palette (green glass cards on a white page) ────────────────
const kCardTop = Color(0xFF2F6A45);
const kCardBottom = Color(0xFF1D4A2E);
const kCardFrame = Color(0x26FFFFFF);
const kCardShelf = Color(0xFF1A3F27);
const kCardMint = Color(0xFF7FF0C8);

String productImageUrl(Map<String, dynamic> pData) {
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

// The one product card used everywhere (home "Featured Products" rail and the
// shop grid): deep-green rounded card, framed product photo standing on a
// shelf, name + price bottom-left, round action button bottom-right.
class GProductCard extends StatefulWidget {
  final Map<String, dynamic> pData;
  final VoidCallback onTap;
  const GProductCard({super.key, required this.pData, required this.onTap});
  @override
  State<GProductCard> createState() => _GProductCardState();
}

class _GProductCardState extends State<GProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext ctx) {
    final pData = widget.pData;
    final id = asInt(pData['id']);
    final qty = ctx.select<CartProvider, int>((c) => c.qty(id));
    final price = asDouble(pData['price']);
    final mrp = asDouble(pData['mrp']);
    final discount = mrp > price ? ((mrp - price) / mrp * 100).round() : 0;
    final stock = pData['stock_quantity'] == null ? null : asInt(pData['stock_quantity']);
    final outOfStock = stock != null && stock <= 0;

    void add() {
      if (outOfStock) return showMsg(ctx, 'This item is out of stock', err: true);
      HapticFeedback.lightImpact();
      ctx.read<CartProvider>().add(pData);
    }

    void remove() {
      HapticFeedback.lightImpact();
      ctx.read<CartProvider>().remove(id);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth;
          // Scale type + controls with the card so the 3-up shop grid and the
          // wider home rail both read correctly.
          final k = (w / 150).clamp(0.72, 1.2);
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kCardTop, kCardBottom],
              ),
              borderRadius: BorderRadius.circular(22 * k),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(color: kCardBottom.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            padding: EdgeInsets.all(8 * k),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Framed photo on a shelf ───────────────────────────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16 * k),
                    border: Border.all(color: kCardFrame),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                  padding: EdgeInsets.fromLTRB(10 * k, 12 * k, 10 * k, 0),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Column(children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12 * k),
                              child: CachedNetworkImage(
                                imageUrl: productImageUrl(pData),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.06)),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  child: Icon(Icons.eco_rounded, color: Colors.white.withValues(alpha: 0.4), size: 30 * k),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Shelf the product "stands" on
                      Container(
                        height: 7 * k,
                        margin: EdgeInsets.fromLTRB(2 * k, 3 * k, 2 * k, 0),
                        decoration: BoxDecoration(
                          color: kCardShelf,
                          borderRadius: BorderRadius.circular(3 * k),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3))],
                        ),
                      ),
                      SizedBox(height: 10 * k),
                    ]),
                    // Mint badge (wishlist) — top-left, like the reference
                    Positioned(top: -4 * k, left: -4 * k, child: _MintHeart(product: pData, size: 22 * k)),
                    if (discount > 0)
                      Positioned(
                        top: -4 * k, right: -4 * k,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 5 * k, vertical: 2 * k),
                          decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(6 * k)),
                          child: Text('$discount%', style: p(8.5 * k, w: FontWeight.w800, color: C.forest)),
                        ),
                      ),
                    // In-cart stepper floats over the bottom of the frame
                    if (qty > 0)
                      Positioned(
                        left: 0, right: 0, bottom: 14 * k,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: kCardShelf.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              _StepBtn(icon: Icons.remove_rounded, size: 22 * k, onTap: remove),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4 * k),
                                child: Text('$qty', style: p(11 * k, w: FontWeight.w800, color: Colors.white)),
                              ),
                              _StepBtn(icon: Icons.add_rounded, size: 22 * k, onTap: add),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),

              // ── Name / price + round action ───────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(4 * k, 9 * k, 0, 2 * k),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(asStr(pData['name']),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: p(12.5 * k, w: FontWeight.w600, color: Colors.white, h: 1.2)),
                    SizedBox(height: 3 * k),
                    Row(children: [
                      Text('₹${price.toStringAsFixed(0)}',
                          style: p(11.5 * k, w: FontWeight.w700, color: const Color(0xFFCDEBD5))),
                      if (mrp > price) ...[
                        SizedBox(width: 4 * k),
                        Flexible(child: Text('₹${mrp.toStringAsFixed(0)}',
                            overflow: TextOverflow.ellipsis,
                            style: p(9 * k, color: Colors.white38, decoration: TextDecoration.lineThrough))),
                      ],
                    ]),
                  ])),
                  SizedBox(width: 4 * k),
                  GestureDetector(
                    onTap: add,
                    child: Container(
                      width: 28 * k, height: 28 * k,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kCardShelf,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Icon(
                        qty > 0 ? Icons.shopping_bag_rounded : Icons.add_rounded,
                        size: 15 * k,
                        color: outOfStock ? Colors.white30 : Colors.white,
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.size, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.62, color: Colors.white)),
      );
}

// Small mint circle (matches the reference card's badge) that doubles as the
// wishlist toggle.
class _MintHeart extends StatelessWidget {
  final Map<String, dynamic> product;
  final double size;
  const _MintHeart({required this.product, required this.size});
  @override
  Widget build(BuildContext ctx) =>
      GWishHeart(product: product, size: size, bg: kCardMint, fg: C.forest);
}
