import 'dart:math' as math;
import 'dart:ui';
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

const _kRailVisible = 5; // products visible in the left rail at once

// Full-screen product viewer on the frosted white page: a green glass rail of
// product thumbnails on the left with a notch cut where the selected product
// sits, and a vertical pager on the right — swiping up/down moves to the
// next/previous product while the notch and rail track the scroll position
// continuously.
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
          pageBuilder: (_, __, ___) => GGlassBg(
            child: ProductViewScreen(
              products: products.map((e) => asMap(e)).toList(),
              initialIndex: index,
            ),
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
    final railW = math.min(mq.size.width * 0.32, 150.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(children: [
          SizedBox(height: mq.padding.top),
          _TopBar(onBack: () => Navigator.pop(ctx), onSearch: () => Navigator.pop(ctx, 'search')),
          Expanded(
            child: LayoutBuilder(builder: (_, box) {
              final h = box.maxHeight;
              return Stack(children: [
                // Product pages — content is laid out to the right of the rail.
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
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.t1),
              const SizedBox(width: 8),
              Text('Back', style: p(15, w: FontWeight.w600, color: C.t1)),
            ]),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded, color: C.t1, size: 24),
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
            GGlass(
              radius: BorderRadius.circular(99),
              child: const SizedBox(
                width: 48, height: 48,
                child: Icon(Icons.shopping_bag_outlined, color: C.forest, size: 22),
              ),
            ),
            if (cart.count > 0)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(99)),
                  child: Text('${cart.count}', style: p(10, w: FontWeight.w800, color: Colors.white)),
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

    return Stack(children: [
      // Green glass panel with the notch cut out, so the frosted page shows
      // through behind the selected product.
      Positioned.fill(
        child: ClipPath(
          clipper: _RailClipper(notchTop: notchTop, notchH: cellH),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kCardTop.withValues(alpha: 0.88), kCardBottom.withValues(alpha: 0.94)],
                ),
              ),
            ),
          ),
        ),
      ),
      Column(children: [
        SizedBox(
          height: listH,
          child: ClipRect(
            child: Stack(children: [
              for (var i = 0; i < n; i++)
                if ((i * cellH - scroll) > -cellH && (i * cellH - scroll) < listH)
                  Positioned(
                    left: _RailClipper.inset, right: 0,
                    top: i * cellH - scroll, height: cellH,
                    child: _RailThumb(
                      url: productImageUrl(products[i]),
                      // 0 → far, 1 → selected; drives scale smoothly mid-swipe
                      focus: (1 - (page - i).abs()).clamp(0.0, 1.0),
                      size: math.min(cellH, width - _RailClipper.inset) * 0.68,
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
              opacity: atEnd ? 0.3 : 1,
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white),
            ),
          ),
        ),
        SizedBox(height: bottomInset),
      ]),
    ]);
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
            scale: 0.9 + 0.16 * focus,
            child: Container(
              width: size, height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6 + 0.4 * focus), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: C.forest.withValues(alpha: 0.12 + 0.16 * focus),
                    blurRadius: 10 + 8 * focus,
                    offset: Offset(0, 4 + 4 * focus),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.26),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(color: Color(0xFFF1F5F1)),
                  errorWidget: (_, __, ___) => ColoredBox(
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

// Rail outline: full-height panel (rounded on the right) minus a rounded
// notch where the selected product sits. The segments above/below the notch
// get rounded corners where they meet it, and the notch has concave corners
// against the thin strip kept on the left.
class _RailClipper extends CustomClipper<Path> {
  static const inset = 12.0; // panel strip kept on the left of the notch
  static const r = 24.0; // notch + panel corner radius
  final double notchTop, notchH;
  _RailClipper({required this.notchTop, required this.notchH});

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final top = notchTop.clamp(0.0, h);
    final bot = (notchTop + notchH).clamp(0.0, h);
    Radius rr(double avail) => Radius.circular(math.max(0, math.min(r, avail / 2)));

    final panel = Path();
    if (top > 0) {
      panel.addRRect(RRect.fromLTRBAndCorners(0, 0, w, top, topRight: rr(top), bottomRight: rr(top)));
    }
    if (bot < h) {
      panel.addRRect(RRect.fromLTRBAndCorners(0, bot, w, h, topRight: rr(h - bot), bottomRight: rr(h - bot)));
    }
    if (bot <= top) return panel;
    panel.addRect(Rect.fromLTRB(0, top, inset + r, bot));
    final notch = Path()
      ..addRRect(RRect.fromLTRBAndCorners(inset, notchTop, w + r, notchTop + notchH,
          topLeft: rr(notchH), bottomLeft: rr(notchH)));
    return Path.combine(PathOperation.difference, panel, notch);
  }

  @override
  bool shouldReclip(_RailClipper old) => old.notchTop != notchTop || old.notchH != notchH;
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
    final left = railW + 18;
    const right = 18.0;
    final contentW = screenW - left - right;
    // Image stays fully inside the page column.
    final imgSize = math.min(contentW, height * 0.34);
    final d = delta.clamp(-1.0, 1.0);
    final fade = (1 - d.abs() * 1.6).clamp(0.0, 1.0);

    final id = asInt(data['id']);
    final qty = ctx.select<CartProvider, int>((c) => c.qty(id));
    final price = asDouble(data['price']);
    final mrp = asDouble(data['mrp']);
    final discount = mrp > price ? ((mrp - price) / mrp * 100).round() : 0;
    final stock = data['stock_quantity'] == null ? null : asInt(data['stock_quantity']);
    final outOfStock = stock != null && stock <= 0;
    final category = asStr(asMap(data['category'])['name']);
    final longDesc = asStr(data['long_description']);
    final desc = longDesc.isNotEmpty
        ? longDesc
        : asStr(data['description'], 'A premium pick from the Ghar Ka Mali shop, chosen to keep your garden healthy and thriving.');

    return ClipRect(
      child: SizedBox(
        height: height,
        child: Stack(children: [
          // Big product image — parallax: drifts slower than the page and
          // shrinks slightly as it leaves.
          Positioned(
            top: 4, left: left + (contentW - imgSize) / 2,
            width: imgSize, height: imgSize,
            child: Transform.translate(
              offset: Offset(0, d * height * 0.3),
              child: Transform.scale(
                scale: 1 - d.abs() * 0.14,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: C.forest.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 14))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: CachedNetworkImage(
                      imageUrl: productImageUrl(data),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(color: Color(0xFFF1F5F1)),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: const Color(0xFFF1F5F1),
                        child: Icon(Icons.eco_rounded, size: 64, color: C.green.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Details column
          Positioned(
            left: left, right: right,
            top: imgSize + 20, bottom: bottomInset + 16,
            child: Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(0, d * 60),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (category.isNotEmpty) ...[
                    Text(category.toUpperCase(), style: p(10, w: FontWeight.w700, color: C.t3, ls: 0.8)),
                    const SizedBox(height: 4),
                  ],
                  // Full product name — never truncated
                  Text(asStr(data['name']), style: p(20, w: FontWeight.w700, color: C.forest, h: 1.25)),
                  const SizedBox(height: 10),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, runSpacing: 4, children: [
                    Text('₹${price.toStringAsFixed(0)}', style: p(20, w: FontWeight.w800, color: C.t1)),
                    if (mrp > price)
                      Text('₹${mrp.toStringAsFixed(0)}',
                          style: p(13, color: C.t4, decoration: TextDecoration.lineThrough)),
                    if (discount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(8)),
                        child: Text('$discount% OFF', style: p(10, w: FontWeight.w800, color: C.forest)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(desc,
                        overflow: TextOverflow.fade,
                        style: p(13, color: C.t3, h: 1.55)),
                  ),
                  GestureDetector(
                    onTap: () => showProductDetailSheet(ctx, data),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('View full details',
                          style: p(12.5, w: FontWeight.w700, color: C.forest, decoration: TextDecoration.underline)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GCartStepper(
                    qty: qty,
                    height: 48,
                    light: false,
                    disabled: outOfStock,
                    onAdd: () {
                      HapticFeedback.lightImpact();
                      ctx.read<CartProvider>().add(data);
                    },
                    onRemove: () {
                      HapticFeedback.lightImpact();
                      ctx.read<CartProvider>().remove(id);
                    },
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
