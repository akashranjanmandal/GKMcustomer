import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/cart_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/widgets.dart';
import 'shop_screen.dart';

const _kBg = Color(0xFF5B8A61); // sage green page
const _kCream = Color(0xFFF1E7B6); // title / price
const _kRailVisible = 5; // products visible in the left rail at once

// Full-screen product viewer: a white rail of product thumbnails on the left
// with a notch that follows the selected product, and a vertical pager on the
// right — swiping up/down moves to the next/previous product while the notch
// and rail track the scroll position continuously.
//
// Pops with 'search' when the search icon is tapped so the caller can focus
// its search field.
class ProductViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final int initialIndex;
  const ProductViewScreen({super.key, required this.products, this.initialIndex = 0});

  static Future<String?> open(BuildContext ctx, List<dynamic> products, int index) =>
      Navigator.push<String>(
        ctx,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => ProductViewScreen(
            products: products.map((e) => asMap(e)).toList(),
            initialIndex: index,
          ),
          transitionsBuilder: (_, a, __, child) {
            final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: c,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
                child: child,
              ),
            );
          },
        ),
      );

  @override
  State<ProductViewScreen> createState() => _ProductViewState();
}

class _ProductViewState extends State<ProductViewScreen> {
  final _api = Api();
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  final Map<int, Map<String, dynamic>> _full = {};
  final Set<int> _fetching = {};
  Drag? _railDrag;

  int get _n => widget.products.length;

  double get _page =>
      _pc.hasClients && _pc.position.haveDimensions ? (_pc.page ?? widget.initialIndex.toDouble()) : widget.initialIndex.toDouble();

  @override
  void initState() {
    super.initState();
    _prefetch(widget.initialIndex);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  // List rows only carry summary fields — pull the full record (long
  // description etc.) for the visible product and its neighbours.
  void _prefetch(int i) {
    for (final j in [i, i + 1, i - 1]) {
      if (j < 0 || j >= _n) continue;
      final id = asInt(widget.products[j]['id']);
      if (id == 0 || _full.containsKey(id) || _fetching.contains(id)) continue;
      _fetching.add(id);
      _api.getShopProduct(id).then((full) {
        if (mounted && full is Map) setState(() => _full[id] = Map<String, dynamic>.from(full));
      }).catchError((_) {}).whenComplete(() => _fetching.remove(id));
    }
  }

  Map<String, dynamic> _data(int i) {
    final base = widget.products[i];
    final full = _full[asInt(base['id'])];
    return full == null ? base : {...base, ...full};
  }

  void _goTo(int i) {
    if (i < 0 || i >= _n) return;
    HapticFeedback.selectionClick();
    _pc.animateToPage(i, duration: const Duration(milliseconds: 520), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final railW = math.min(mq.size.width * 0.36, 168.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(children: [
          SizedBox(height: mq.padding.top),
          _TopBar(onBack: () => Navigator.pop(ctx), onSearch: () => Navigator.pop(ctx, 'search')),
          Expanded(
            child: LayoutBuilder(builder: (_, box) {
              final h = box.maxHeight;
              return Stack(children: [
                // Product pages — full width so the big image can sit to the
                // right of the rail; content is padded past the rail.
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pc,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _n,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      _prefetch(i);
                    },
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _pc,
                      builder: (_, __) => _ProductPage(
                        data: _data(i),
                        delta: _page - i,
                        railW: railW,
                        height: h,
                        bottomInset: mq.padding.bottom,
                      ),
                    ),
                  ),
                ),
                // Left rail — vertical drags on it drive the same pager.
                Positioned(
                  left: 0, top: 0, bottom: 0, width: railW,
                  child: GestureDetector(
                    onVerticalDragStart: (d) => _railDrag = _pc.position.drag(d, () => _railDrag = null),
                    onVerticalDragUpdate: (d) => _railDrag?.update(d),
                    onVerticalDragEnd: (d) => _railDrag?.end(d),
                    onVerticalDragCancel: () => _railDrag?.cancel(),
                    child: AnimatedBuilder(
                      animation: _pc,
                      builder: (_, __) => _Rail(
                        products: widget.products,
                        page: _page,
                        width: railW,
                        height: h,
                        bottomInset: mq.padding.bottom,
                        onSelect: _goTo,
                        onNext: () => _goTo(_page.round() + 1),
                      ),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        ]),
      ),
    );
  }
}

// ─── Top bar: "< Back" · search · bag ─────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack, onSearch;
  const _TopBar({required this.onBack, required this.onSearch});

  @override
  Widget build(BuildContext ctx) {
    final cart = ctx.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
      child: Row(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(children: [
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('Back', style: p(15, w: FontWeight.w500, color: Colors.white)),
            ]),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            if (cart.count == 0) return showMsg(ctx, 'Your cart is empty');
            Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => CheckoutPage(cart: cart.items, onOrdered: () => cart.clear()),
            ));
          },
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 23),
            ),
            if (cart.count > 0)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(99)),
                  child: Text('${cart.count}', style: p(10, w: FontWeight.w800, color: C.forest)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Left rail ────────────────────────────────────────────────────────────────
class _Rail extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final double page, width, height, bottomInset;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;
  const _Rail({
    required this.products,
    required this.page,
    required this.width,
    required this.height,
    required this.bottomInset,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext ctx) {
    const chevronH = 56.0;
    final listH = height - chevronH - bottomInset;
    final cellH = listH / _kRailVisible;
    final n = products.length;
    // Keep the selected product in the middle slot once there's room to scroll.
    final maxScroll = math.max(0.0, n * cellH - listH);
    final scroll = (page * cellH - cellH * (_kRailVisible ~/ 2)).clamp(0.0, maxScroll);
    final notchTop = page * cellH - scroll;
    final atEnd = page.round() >= n - 1;

    return CustomPaint(
      painter: _RailPainter(notchTop: notchTop, notchH: cellH, bg: _kBg),
      child: Column(children: [
        SizedBox(
          height: listH,
          child: ClipRect(
            child: Stack(children: [
              for (var i = 0; i < n; i++)
                if ((i * cellH - scroll) > -cellH && (i * cellH - scroll) < listH)
                  Positioned(
                    left: _RailPainter.inset, right: 0,
                    top: i * cellH - scroll, height: cellH,
                    child: _RailThumb(
                      url: productImageUrl(products[i]),
                      // 0 → far, 1 → selected; drives scale smoothly mid-swipe
                      focus: (1 - (page - i).abs()).clamp(0.0, 1.0),
                      size: math.min(cellH, width - _RailPainter.inset) * 0.66,
                      onTap: () => onSelect(i),
                    ),
                  ),
            ]),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: atEnd ? null : onNext,
          child: SizedBox(
            height: chevronH,
            width: double.infinity,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: atEnd ? 0.25 : 1,
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: C.t1),
            ),
          ),
        ),
        SizedBox(height: bottomInset),
      ]),
    );
  }
}

class _RailThumb extends StatelessWidget {
  final String url;
  final double focus, size;
  final VoidCallback onTap;
  const _RailThumb({required this.url, required this.focus, required this.size, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Transform.scale(
            scale: 0.92 + 0.14 * focus,
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10 + 0.18 * focus),
                    blurRadius: 10 + 8 * focus,
                    offset: Offset(0, 4 + 4 * focus),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.24),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFFF1F5F1)),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFF1F5F1),
                    child: Icon(Icons.eco_rounded, color: C.green.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// White panel with a rounded notch cut where the selected product sits, so the
// selected thumbnail appears to sit on the green page background.
class _RailPainter extends CustomPainter {
  static const inset = 14.0; // white strip kept on the left of the notch
  static const r = 24.0; // notch + panel corner radius
  final double notchTop, notchH;
  final Color bg;
  _RailPainter({required this.notchTop, required this.notchH, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final white = Paint()..color = Colors.white;
    final top = notchTop.clamp(0.0, h);
    final bot = (notchTop + notchH).clamp(0.0, h);

    Radius rr(double avail) => Radius.circular(math.max(0, math.min(r, avail / 2)));

    // Segment above the notch: rounded top-right (panel) + bottom-right (notch)
    if (top > 0) {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(0, 0, w, top, topRight: rr(top), bottomRight: rr(top)),
        white,
      );
    }
    // Segment below the notch
    if (bot < h) {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(0, bot, w, h, topRight: rr(h - bot), bottomRight: rr(h - bot)),
        white,
      );
    }
    // Left strip beside the notch, then the notch itself painted in the page
    // colour — leaves concave white corners on its left edge.
    if (bot > top) {
      canvas.drawRect(Rect.fromLTRB(0, top, inset + r, bot), white);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(inset, notchTop, w + 0.5, notchTop + notchH,
            topLeft: rr(notchH), bottomLeft: rr(notchH)),
        Paint()..color = bg,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.notchTop != notchTop || old.notchH != notchH || old.bg != bg;
}

// ─── One product page ─────────────────────────────────────────────────────────
class _ProductPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final double delta; // page offset from this product (−1…1 while swiping)
  final double railW, height, bottomInset;
  const _ProductPage({
    required this.data,
    required this.delta,
    required this.railW,
    required this.height,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext ctx) {
    final screenW = MediaQuery.of(ctx).size.width;
    final contentW = screenW - railW - 20 - 18;
    final imgSize = math.min(contentW + 30, height * 0.36);
    final d = delta.clamp(-1.0, 1.0);
    final fade = (1 - d.abs() * 1.6).clamp(0.0, 1.0);

    final id = asInt(data['id']);
    final qty = ctx.select<CartProvider, int>((c) => c.qty(id));
    final price = asDouble(data['price']);
    final mrp = asDouble(data['mrp']);
    final rating = asDouble(data['rating']);
    final stock = data['stock_quantity'] == null ? null : asInt(data['stock_quantity']);
    final outOfStock = stock != null && stock <= 0;
    final longDesc = asStr(data['long_description']);
    final desc = longDesc.isNotEmpty
        ? longDesc
        : asStr(data['description'], 'A premium pick from the Ghar Ka Mali shop, chosen to keep your garden healthy and thriving.');

    void add() {
      if (outOfStock) return;
      HapticFeedback.lightImpact();
      ctx.read<CartProvider>().add(data);
    }

    return SizedBox(
      height: height,
      child: Stack(clipBehavior: Clip.none, children: [
        // Big product image — parallax: drifts slower than the page and
        // shrinks slightly as it leaves.
        Positioned(
          top: 4, right: -14,
          width: imgSize, height: imgSize,
          child: Transform.translate(
            offset: Offset(0, d * height * 0.32),
            child: Transform.scale(
              scale: 1 - d.abs() * 0.14,
              child: Transform.rotate(
                angle: d * 0.12,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(imgSize * 0.16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 14))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imgSize * 0.16),
                    child: CachedNetworkImage(
                      imageUrl: productImageUrl(data),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.08)),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white.withValues(alpha: 0.08),
                        child: Icon(Icons.eco_rounded, size: 64, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Details column
        Positioned(
          left: railW + 20, right: 18,
          top: imgSize + 22, bottom: bottomInset + 16,
          child: Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(0, d * 60),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asStr(data['name']),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: p(25, w: FontWeight.w700, color: _kCream, h: 1.18)),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${price.toStringAsFixed(2)}', style: p(17, w: FontWeight.w600, color: _kCream)),
                  if (mrp > price) ...[
                    const SizedBox(width: 6),
                    Flexible(child: Text('₹${mrp.toStringAsFixed(0)}',
                        overflow: TextOverflow.ellipsis,
                        style: p(12, color: Colors.white54, decoration: TextDecoration.lineThrough))),
                  ],
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _IconBox(child: GWishHeart(product: data, size: 26, bg: Colors.transparent, fg: Colors.white)),
                  const SizedBox(width: 10),
                  _IconBox(
                    child: rating > 0
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.star_outline_rounded, size: 15, color: Colors.white),
                            Text(rating.toStringAsFixed(1), style: p(8.5, w: FontWeight.w700, color: Colors.white)),
                          ])
                        : const Icon(Icons.eco_outlined, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  _IconBox(
                    child: Icon(
                      outOfStock ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
                      size: 17, color: Colors.white,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: Text(desc,
                      overflow: TextOverflow.fade,
                      style: p(13.5, color: Colors.white.withValues(alpha: 0.88), h: 1.55)),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => showProductDetailSheet(ctx, data),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('View full details',
                        style: p(12.5, w: FontWeight.w600, color: _kCream, decoration: TextDecoration.underline)),
                  ),
                ),
                const SizedBox(height: 8),
                if (qty > 0)
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _kCream.withValues(alpha: 0.7), width: 1.3),
                    ),
                    child: Row(children: [
                      _PillBtn(icon: Icons.remove_rounded, onTap: () {
                        HapticFeedback.lightImpact();
                        ctx.read<CartProvider>().remove(id);
                      }),
                      Expanded(child: Center(child: Text('$qty in cart', style: p(13.5, w: FontWeight.w700, color: _kCream)))),
                      _PillBtn(icon: Icons.add_rounded, onTap: add),
                    ]),
                  )
                else
                  SizedBox(
                    width: double.infinity, height: 46,
                    child: ElevatedButton(
                      onPressed: outOfStock ? null : add,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kCream,
                        foregroundColor: C.forest,
                        disabledBackgroundColor: Colors.white24,
                        disabledForegroundColor: Colors.white70,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      ),
                      child: Text(outOfStock ? 'Out of stock' : 'Add to Cart',
                          style: p(14, w: FontWeight.w700, color: outOfStock ? Colors.white70 : C.forest)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _IconBox extends StatelessWidget {
  final Widget child;
  const _IconBox({required this.child});
  @override
  Widget build(BuildContext ctx) => Container(
        width: 38, height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.1),
        ),
        child: child,
      );
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PillBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: 48, height: 46, child: Icon(icon, size: 20, color: _kCream)),
      );
}
