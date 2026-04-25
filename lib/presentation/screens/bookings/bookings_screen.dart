import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// ─── Bookings List ────────────────────────────────────────────────────────────
class BookingsScreen extends StatefulWidget {
  static bool needsReload = false;
  const BookingsScreen({super.key});
  @override State<BookingsScreen> createState() => _BkListState();
}
class _BkListState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  final _api = Api();
  late final TabController _tab;
  static const _labels  = ['All', 'Pending', 'Active', 'Done', 'Cancelled'];
  static const _filters = ['all', 'pending', 'in_progress', 'completed', 'cancelled'];
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _labels.length, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) {
          setState(() { _items = []; });
          _load();
        }
      });
    
    if (BookingsScreen.needsReload) {
      BookingsScreen.needsReload = false;
    }
    _load();
  }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final f = _filters[_tab.index];
      final r = await _api.getMyBookings(status: f == 'all' ? null : f, limit: 20);
      final data = asMap(r);
      if (mounted) setState(() { _items = asList(data['bookings'] ?? r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    primary: false,
    backgroundColor: C.bg,
    body: NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(child: GHeader(pb: 16,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('My Bookings', style: p(22, w: FontWeight.w800, color: Colors.white))),
              GestureDetector(
                onTap: () => Navigator.pushNamed(ctx, '/book'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.gold, C.goldDk]),
                    borderRadius: BorderRadius.circular(99)),
                  child: Text('+ Book', style: p(13, w: FontWeight.w700, color: const Color(0xFF1A0F00))))),
            ]),
          ]))),
        SliverToBoxAdapter(child: Container(
          color: C.bg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: C.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.border), boxShadow: s1()),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
              labelColor: Colors.white, unselectedLabelColor: C.t4, dividerColor: Colors.transparent,
              isScrollable: true, tabAlignment: TabAlignment.start,
              tabs: _labels.map((l) => Tab(text: l, height: 32)).toList())))),
        ],
      body: RefreshIndicator(
        color: C.forest, onRefresh: _load,
        child: _loading
          ? ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), itemCount: 5, itemBuilder: (_, __) => const GSkelCard())
          : _items.isEmpty
            ? ListView(children: [GEmpty(title: 'No bookings here', sub: 'Book your first garden visit', icon: Icons.calendar_month_outlined,
                action: GBtn(label: 'Book Now', onTap: () => Navigator.pushNamed(ctx, '/book'), w: 160, h: 44))])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: _items.length,
                itemBuilder: (_, i) => _BkCard(b: _items[i])
                  .animate().fadeIn(delay: Duration(milliseconds: i * 45)).slideY(begin: 0.08, end: 0, delay: Duration(milliseconds: i * 45))),
      ),
    ),
  );
}

class _BkCard extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BkCard({required this.b});
  @override
  Widget build(BuildContext ctx) {
    final status = asStr(b['status'], 'pending');
    final active = ['en_route','arrived','in_progress'].contains(status);
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: GCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(ctx, _slide(BookingDetailScreen(id: asInt(b['id'])))),
        child: Column(children: [
          if (active) Container(
            height: 34, width: double.infinity,
            decoration: BoxDecoration(
              color: C.amber.withOpacity(0.10),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.amber)),
              const SizedBox(width: 7),
              Text('GARDENER EN ROUTE', style: p(9.5, w: FontWeight.w800, color: C.amber, ls: 0.8)),
            ])),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: active ? C.amber.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                )),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asStr(b['booking_number'], '#${b['id']}'), style: p(13, w: FontWeight.w700, color: C.t1)),
                Text(cleanAddr(asStr(b['gardener']?['name'], asStr(b['service_address']))), style: p(11, color: C.t3), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('₹${(asDouble(b['total_amount']) > 0 ? asDouble(b['total_amount']) : (asDouble(b['base_amount']) + asList(b['addons']).fold(0.0, (sum, a) => sum + asDouble(asMap(a)['price'])))).toStringAsFixed(0)}', style: p(15, w: FontWeight.w800, color: C.forest)),
              ])),
              GBadge(status),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 13, color: C.t4),
              const SizedBox(width: 4),
              Expanded(child: Text(cleanAddr(asStr(b['service_address'], '—')), style: p(11, color: C.t3), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.calendar_today_rounded, size: 12, color: C.t4),
              const SizedBox(width: 4),
              Text(asStr(b['scheduled_date'], '—').length >= 10 ? asStr(b['scheduled_date']).substring(0,10) : '—', style: p(11, color: C.t3)),
            ]),
            if (_cardAddons(b).isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _cardAddons(b).take(3).map((a) {
                final name = asStr(a['name'] ?? a['addon_name'] ?? asMap(a['addon'])['name'], 'Add-on');
                final price = asDouble(a['price'] ?? a['amount'] ?? asMap(a['addon'])['price']);
                return Text('+ $name${price > 0 ? " (₹${price.toStringAsFixed(0)})" : ""}', style: p(10, w: FontWeight.w600, color: C.t4));
              }).toList()),
            ],
          ])),
        ]),
      ));
  }
}

// ─── Booking Detail ───────────────────────────────────────────────────────────
class BookingDetailScreen extends StatefulWidget {
  final int id;
  const BookingDetailScreen({super.key, required this.id});
  @override State<BookingDetailScreen> createState() => _BkDetailState();
}
class _BkDetailState extends State<BookingDetailScreen> {
  final _api = Api();
  Map<String, dynamic>? _bk;
  List<dynamic> _addons = [];
  bool _loading = true, _cancelling = false, _rating = false;
  Timer? _timer;
  int _stars = 5;
  final _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState(); _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(quiet: true));
  }
  @override void dispose() { _timer?.cancel(); _reviewCtrl.dispose(); super.dispose(); }

  // Extract addon list from booking map, trying all known response shapes
  List<dynamic> _extractAddons(Map<String, dynamic> bk) {
    // Try all possible keys the backend might use
    for (final key in ['addons', 'booking_addons', 'add_ons', 'items']) {
      final v = bk[key];
      final list = asList(v);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  // Normalize a single addon entry to {name, price}
  Map<String, dynamic> _normalizeAddon(dynamic raw) {
    final a = asMap(raw);
    // Shape 1: {addon: {id, name, price, ...}, quantity, price}
    if (a.containsKey('addon') && a['addon'] is Map) {
      final inner = asMap(a['addon']);
      final name = asStr(inner['name'] ?? inner['addon_name'] ?? inner['title'], 'Add-on');
      // prefer top-level price (may reflect negotiated price), fallback to inner
      final price = asDouble(a['price'] ?? a['amount'] ?? inner['price'] ?? inner['amount']);
      return {'name': name, 'price': price};
    }
    // Shape 2: flat {name/addon_name/title, price/amount}
    final name = asStr(a['name'] ?? a['addon_name'] ?? a['title'] ?? a['addon_title'], 'Add-on');
    final price = asDouble(a['price'] ?? a['amount'] ?? a['addon_price']);
    return {'name': name, 'price': price};
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getBooking(widget.id),
        _api.getBookingAddons(widget.id).catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      final bk = asMap(results[0]);
      // Merge addons: prefer dedicated endpoint, fallback to embedded
      List<dynamic> addons = asList(results[1]);
      if (addons.isEmpty) addons = _extractAddons(bk);
      setState(() { _bk = bk; _addons = addons; _loading = false; });
    } catch (_) { if (mounted && !quiet) setState(() => _loading = false); }
  }

  String get _status => asStr(_bk?['status'], 'pending');

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Cancel Booking?', style: p(17, w: FontWeight.w700, color: C.t1)),
      content: Text('This cannot be undone.', style: p(14, color: C.t3)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep', style: p(14, color: C.t3))),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: Text('Cancel Booking', style: p(14, w: FontWeight.w700, color: C.red))),
      ]));
    if (ok != true) return;
    setState(() => _cancelling = true);
    try {
      await _api.cancelBooking(widget.id);
      await _load(quiet: true);
      if (mounted) showMsg(context, 'Booking cancelled', ok: true);
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _cancelling = false); }
  }

  Future<void> _submitRating() async {
    setState(() => _rating = true);
    try {
      await _api.rateBooking(widget.id, _stars, review: _reviewCtrl.text.trim().isNotEmpty ? _reviewCtrl.text.trim() : null);
      await _load(quiet: true);
      if (mounted) { showMsg(context, 'Thank you for your review!', ok: true); Navigator.pop(context); }
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _rating = false); }
  }

  void _showRating() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx2, ss) => Padding(
        padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.of(ctx2).viewInsets.bottom + 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 18),
          Text('Rate Your Visit', style: p(18, w: FontWeight.w800, color: C.t1)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => ss(() => _stars = i + 1),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(i < _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40, color: i < _stars ? C.gold : C.t4))))),
          const SizedBox(height: 16),
          TextField(controller: _reviewCtrl, maxLines: 3, style: p(14, color: C.t2),
            decoration: const InputDecoration(hintText: 'Share your experience (optional)')),
          const SizedBox(height: 20),
          GBtn(label: 'Submit Review', gold: true, loading: _rating, onTap: _submitRating),
        ]))));
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return Scaffold(backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.forest, leading: const BackButton()),
      body: const Center(child: CircularProgressIndicator(color: C.forest)));
    if (_bk == null) return Scaffold(backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.forest), body: const GEmpty(title: 'Booking not found', sub: 'It may have been removed or cancelled'));

    final gardener  = asMap(_bk!['gardener']);
    final canCancel = ['pending', 'assigned'].contains(_status);
    final canRate   = _status == 'completed' && _bk!['rating'] == null;
    final hasRating = _bk!['rating'] != null;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: GHeader(pb: 52, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () => Navigator.pop(ctx),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white70),
              const SizedBox(width: 4),
              Text('My Bookings', style: p(13, color: Colors.white70)),
            ])),
          const SizedBox(height: 16),
          Text(asStr(_bk!['booking_number'], '#${_bk!['id']}'), style: p(20, w: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          GBadge(_status),
        ]))),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Booking info
            GCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(99))),
                const SizedBox(width: 8),
                Text('BOOKING DETAILS', style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.8)),
              ]),
              const SizedBox(height: 16),
              GDetailRow(icon: Icons.location_on_rounded, label: 'ADDRESS', value: cleanAddr(asStr(_bk!['service_address'], '—'))),
              GDetailRow(icon: Icons.calendar_month_rounded, label: 'DATE', value: asStr(_bk!['scheduled_date'], '—').length >= 10 ? asStr(_bk!['scheduled_date']).substring(0,10) : '—'),
              GDetailRow(icon: Icons.access_time_rounded, label: 'TIME', value: asStr(_bk!['scheduled_time'], 'Flexible')),
              GDetailRow(icon: Icons.local_florist_rounded, label: 'PLANTS', value: '${_bk!['plant_count'] ?? '—'} plants'),
              if (asDouble(_bk!['total_amount']) > 0)
                GDetailRow(icon: Icons.receipt_rounded, label: 'TOTAL', value: '₹${asDouble(_bk!['total_amount']).toStringAsFixed(0)}'),
              
              // Add-ons Section
              if (_addons.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),
                Text('INCLUDED ADD-ONS', style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.8)),
                const SizedBox(height: 8),
                ..._addons.map((a) {
                  final addon = _normalizeAddon(a);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: C.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(addon['name'] as String, style: p(13, w: FontWeight.w600, color: C.t2))),
                      Text('₹${(addon['price'] as double).toStringAsFixed(0)}', style: p(13, w: FontWeight.w700, color: C.t1)),
                    ]),
                  );
                }),
              ],

              if ((_bk!['customer_notes'] as String?)?.isNotEmpty == true)
                GDetailRow(icon: Icons.sticky_note_2_outlined, label: 'NOTES', value: asStr(_bk!['customer_notes'])),
            ])).animate().fadeIn(),

            // Visit OTP
            if (_status == 'assigned') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [C.forest.withOpacity(0.08), C.forest.withOpacity(0.02)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.forest.withOpacity(0.15))),
                child: Row(children: [
                  const Icon(Icons.lock_rounded, color: C.forest, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Visit OTP', style: p(14, w: FontWeight.w700, color: C.t1)),
                    Text('Share with gardener when they arrive', style: p(11, color: C.t3)),
                    const SizedBox(height: 8),
                    Text(asStr(_bk!['otp'], '—'), style: p(28, w: FontWeight.w900, color: C.forest, ls: 3, h: 1)),
                  ])),
                ])).animate().fadeIn(delay: 60.ms),
            ],

            // Gardener card
            if (gardener.isNotEmpty) ...[
              const SizedBox(height: 12),
              GCard(padding: const EdgeInsets.all(16), child: Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.forest, C.forest2]), shape: BoxShape.circle),
                  child: Center(child: Text(
                    asStr(gardener['name'], 'G').isNotEmpty ? asStr(gardener['name'])[0].toUpperCase() : 'G',
                    style: p(20, w: FontWeight.w800, color: Colors.white)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your Gardener', style: p(10, w: FontWeight.w600, color: C.t4, ls: 0.5)),
                  Text(asStr(gardener['name'], '—'), style: p(15, w: FontWeight.w700, color: C.t1)),
                ])),
                if (gardener['avg_rating'] != null) Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: C.gold),
                  const SizedBox(width: 4),
                  Text(asDouble(gardener['avg_rating']).toStringAsFixed(1), style: p(14, w: FontWeight.w700, color: C.t1)),
                ]),
              ])).animate().fadeIn(delay: 80.ms),
            ],

            // Rating display
            if (hasRating) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [C.gold.withOpacity(0.14), C.gold.withOpacity(0.04)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.gold.withOpacity(0.28))),
                child: Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < asInt(_bk!['rating']) ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18, color: C.gold)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    (_bk!['review'] as String?)?.isNotEmpty == true ? asStr(_bk!['review']) : 'Review submitted',
                    style: p(13, color: C.t2, h: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ])).animate().fadeIn(delay: 100.ms),
            ],

            const SizedBox(height: 20),
            if (canRate)   GBtn(label: 'Rate Your Visit', icon: Icons.star_rounded, gold: true, onTap: _showRating).animate().fadeIn(),
            if (canCancel) ...[
              if (canRate) const SizedBox(height: 10),
              GBtn(label: 'Cancel Booking', danger: true, outline: true, loading: _cancelling, onTap: _cancel).animate().fadeIn(),
            ],
          ])),
        ),
      ]),
    );
  }
}

String cleanAddr(String s) {
  final reg = RegExp(r'-?\d{1,3}\.\d{4,}');
  if (reg.allMatches(s).length >= 2) return 'Service Location';
  return s.isEmpty ? '—' : s;
}

List<dynamic> _cardAddons(Map<String, dynamic> b) {
  for (final key in ['addons', 'booking_addons', 'add_ons']) {
    final list = asList(b[key]);
    if (list.isNotEmpty) return list;
  }
  return [];
}

Route<dynamic> _slide(Widget page) => PageRouteBuilder(
  transitionDuration: 340.ms, reverseTransitionDuration: 280.ms,
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(c),
      child: FadeTransition(opacity: Tween<double>(begin: 0.35, end: 1).animate(c), child: child));
  });
