import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/services/api.dart';
import '../../data/services/cart_provider.dart';
import '../theme/theme.dart';
import 'widgets.dart';

// ─── Green glass product card palette ────────────────────────────────────────
const kCardTop = Color(0xFF2E7D4F);
const kCardBottom = Color(0xFF14532D);
const kCardCream = Color(0xFFF1E7B6);

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

// Lays product cards out [columns] per row. Each row is as tall as its
// tallest card, so every card can show the product's full name.
class GProductGridRow extends StatelessWidget {
  final List<Widget> cards;
  final int columns;
  final double gap;
  const GProductGridRow({super.key, required this.cards, this.columns = 2, this.gap = 12});
  @override
  Widget build(BuildContext ctx) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: i < cards.length ? cards[i] : const SizedBox.shrink()),
          ],
        ]),
      );
}

// The one product card used everywhere (home "Featured Products" rail and the
// shop grid): green frosted-glass card, photo in a glass frame, full product
// name, price, and an add / − qty + control so items can be removed from the
// cart right here. Must be given a bounded height (see GProductGridRow).
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

    const radius = BorderRadius.all(Radius.circular(24));

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [BoxShadow(color: kCardBottom.withValues(alpha: 0.22), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: radius,
            // No live BackdropFilter here — one per card in a scrolling list
            // overheats phones; the translucent gradient reads as glass.
            child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kCardTop.withValues(alpha: 0.92), kCardBottom.withValues(alpha: 0.96)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
                ),
                child: Stack(children: [
                  // Glass sheen across the top of the card
                  Positioned(
                    top: 0, left: 0, right: 0, height: 90,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Photo in a glass frame ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withValues(alpha: 0.95),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedNetworkImage(fadeInDuration: const Duration(milliseconds: 120), fadeOutDuration: Duration.zero, placeholderFadeInDuration: Duration.zero, memCacheWidth: 540, 
                                imageUrl: productImageUrl(pData),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const ColoredBox(color: Color(0xFFF1F5F1)),
                                errorWidget: (_, __, ___) => ColoredBox(
                                  color: const Color(0xFFF1F5F1),
                                  child: Icon(Icons.eco_rounded, color: C.green.withValues(alpha: 0.4), size: 36),
                                ),
                              ),
                            ),
                          ),
                          if (discount > 0)
                            Positioned(
                              top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(8)),
                                child: Text('$discount% OFF', style: p(9, w: FontWeight.w800, color: C.forest)),
                              ),
                            ),
                          if (outOfStock)
                            Positioned(
                              left: 8, right: 8, bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: Text('Out of stock', style: p(10, w: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                        ]),
                      ),
                    ),

                    // ── Full name, price, cart control ──────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Text(asStr(pData['name']),
                          style: p(13, w: FontWeight.w600, color: Colors.white, h: 1.3)),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
                        Text('₹${price.toStringAsFixed(0)}', style: p(15, w: FontWeight.w800, color: kCardCream)),
                        if (mrp > price)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text('₹${mrp.toStringAsFixed(0)}',
                                style: p(11, color: Colors.white.withValues(alpha: 0.85), decoration: TextDecoration.lineThrough)),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: GCartStepper(qty: qty, onAdd: add, onRemove: remove, disabled: outOfStock),
                    ),
                  ]),
                ]),
              ),
          ),
        ),
      ),
    );
  }
}

// "Add" pill that turns into − qty + once the item is in the cart. Used on the
// product cards, the product viewer and the detail sheet.
class GCartStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd, onRemove;
  final bool disabled;
  final double height;
  // light = on a green surface (glass pill); otherwise solid forest on white.
  final bool light;
  const GCartStepper({
    super.key,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    this.disabled = false,
    this.height = 36,
    this.light = true,
  });

  @override
  Widget build(BuildContext ctx) {
    const fg = Colors.white;
    final bg = light ? Colors.white.withValues(alpha: 0.16) : C.forest;
    final inCartBg = light ? kCardCream : C.forest;
    final inCartFg = light ? C.forest : Colors.white;
    final radius = BorderRadius.circular(99);
    final Color? disabledFg = !disabled ? null : (light ? Colors.white54 : C.t3);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: c)),
      child: qty > 0
          ? Container(
              key: const ValueKey('stepper'),
              height: height,
              decoration: BoxDecoration(color: inCartBg, borderRadius: radius),
              child: Row(children: [
                _tap(Icons.remove_rounded, inCartFg, onRemove),
                Expanded(
                  child: Center(
                    child: Text('$qty', style: p(14, w: FontWeight.w800, color: inCartFg)),
                  ),
                ),
                _tap(Icons.add_rounded, inCartFg, disabled ? null : onAdd),
              ]),
            )
          : GestureDetector(
              key: const ValueKey('add'),
              onTap: disabled ? null : onAdd,
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: disabled ? (light ? bg.withValues(alpha: 0.08) : C.t4.withValues(alpha: 0.25)) : bg,
                  borderRadius: radius,
                  border: light ? Border.all(color: Colors.white.withValues(alpha: 0.45)) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_shopping_cart_rounded, size: height > 40 ? 18 : 15, color: disabledFg ?? fg),
                  const SizedBox(width: 6),
                  Text(disabled ? 'Out of stock' : 'Add to cart',
                      style: p(height > 40 ? 14 : 12, w: FontWeight.w700, color: disabledFg ?? fg)),
                ]),
              ),
            ),
    );
  }

  Widget _tap(IconData icon, Color c, VoidCallback? onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: height + 4, height: height,
          child: Icon(icon, size: 18, color: onTap == null ? c.withValues(alpha: 0.35) : c),
        ),
      );
}
