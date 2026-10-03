import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/services/api.dart';
import '../../../data/services/invoice_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// ─── Bookings List ────────────────────────────────────────────────────────────
// Layout: serif page title + "Book a visit", filter chips, a "Next visit"
// panel with a live progress tracker for the soonest upcoming booking, then
// ticket-style cards (date stub | details) for everything else.
class BookingsScreen extends StatefulWidget {
  // Back arrow action. In the bottom-nav shell this returns to the Home tab;
  // when pushed as a route it falls back to popping.
  final VoidCallback? onBack;
  static bool needsReload = false;
  const BookingsScreen({super.key, this.onBack});
  @override State<BookingsScreen> createState() => _BkListState();
}
class _BkListState extends State<BookingsScreen> {
  final _api = Api();
  static const _labels  = ['All', 'Pending', 'Active', 'Done', 'Cancelled'];
  static const _filters = ['all', 'pending', 'in_progress', 'completed', 'cancelled'];
  int _f = 0;
  // Client-side ordering of the loaded bookings.
  String _sort = 'upcoming';
  static const _sortLabels = {'upcoming': 'Upcoming first', 'newest': 'Newest first', 'oldest': 'Oldest first'};
  static const _statusIcons = [Icons.apps_rounded, Icons.hourglass_empty_rounded, Icons.directions_walk_rounded, Icons.task_alt_rounded, Icons.event_busy_outlined];

  Future<void> _openFilters() async {
    final res = await showFilterSheet(context,
      title: 'Filter bookings',
      sections: [
        VFilterSection(title: 'Status', defaultValue: '0', options: [
          for (var i = 0; i < _labels.length; i++) VFilterOption('$i', _labels[i], icon: _statusIcons[i]),
        ]),
        VFilterSection(title: 'Sort by', defaultValue: 'upcoming', tiles: false, options: [
          for (final e in _sortLabels.entries) VFilterOption(e.key, e.value),
        ]),
      ],
      current: ['$_f', _sort],
    );
    if (res == null || !mounted) return;
    setState(() => _sort = res[1]);
    _setFilter(int.parse(res[0]));
  }

  List<dynamic> _sorted(List<dynamic> l) {
    if (_sort == 'upcoming') return l;
    DateTime at(dynamic b) => DateTime.tryParse(asStr(asMap(b)['scheduled_date'])) ?? DateTime(2000);
    final out = [...l]..sort((a, b) => at(a).compareTo(at(b)));
    return _sort == 'newest' ? out.reversed.toList() : out;
  }
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (BookingsScreen.needsReload) BookingsScreen.needsReload = false;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final f = _filters[_f];
      final r = await _api.getMyBookings(status: f == 'all' ? null : f, limit: 20);
      final data = asMap(r);
      if (mounted) setState(() { _items = asList(data['bookings'] ?? r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _setFilter(int i) {
    if (i == _f) return;
    setState(() { _f = i; _items = []; });
    _load();
  }

  static const _upcoming = ['pending', 'assigned', 'en_route', 'arrived', 'in_progress'];

  @override
  Widget build(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).padding.bottom + 24;
    // Soonest upcoming booking gets the hero tracker panel.
    Map<String, dynamic>? next;
    final rest = <Map<String, dynamic>>[];
    for (final e in _sorted(_items)) {
      final b = asMap(e);
      if (next == null && _upcoming.contains(asStr(b['status']))) { next = b; } else { rest.add(b); }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: V.leaf, onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
            child: Row(children: [
              _CircleBtn(icon: Icons.arrow_back_rounded, onTap: () => widget.onBack != null ? widget.onBack!() : Navigator.maybePop(ctx)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(ctx, '/book'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
                  decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, size: 18, color: V.lime),
                    const SizedBox(width: 6),
                    Text('Book a visit', style: p(13, w: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ))),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: Row(children: [
              Expanded(child: Text('Bookings', style: vx(34, w: FontWeight.w600, color: V.ink, ls: -0.8))),
              VFilterButton(active: _f != 0 || _sort != 'upcoming', onTap: _openFilters),
            ]),
          )),
          if (_f != 0 || _sort != 'upcoming') SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (_f != 0) VActiveFilter(label: _labels[_f], onClear: () => _setFilter(0)),
              if (_sort != 'upcoming') VActiveFilter(label: _sortLabels[_sort]!, onClear: () => setState(() => _sort = 'upcoming')),
            ]),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          if (_loading)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 4)),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: GEmpty(
              title: 'No bookings here', sub: 'Book your first garden visit', icon: Icons.calendar_month_outlined,
              action: GBtn(label: 'Book a visit', onTap: () => Navigator.pushNamed(ctx, '/book'), w: 200, h: 48)))
          else ...[
            if (next != null)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: _NextVisit(b: next),
              )),
            if (rest.isNotEmpty) SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(next != null ? 'All bookings' : '${rest.length} booking${rest.length == 1 ? '' : 's'}',
                style: vx(19, w: FontWeight.w600, color: V.ink)),
            )),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _BkCard(b: rest[i])
                  ,
                childCount: rest.length,
              )),
            ),
          ],
        ]),
      ),
    );
  }
}

// Small round glass button (back etc.)
class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), shape: BoxShape.circle, border: Border.all(color: Colors.white)),
      child: Icon(icon, size: 21, color: V.ink),
    ),
  );
}

DateTime? _visitDate(Map<String, dynamic> b) => DateTime.tryParse(asStr(b['scheduled_date']));
const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

String _bkAmount(Map<String, dynamic> b) {
  final t = asDouble(b['total_amount']) > 0
      ? asDouble(b['total_amount'])
      : asDouble(b['base_amount']) + asList(b['addons']).fold(0.0, (sum, a) => sum + asDouble(asMap(a)['price']));
  return '₹${t.toStringAsFixed(0)}';
}

String _bkTitle(Map<String, dynamic> b) {
  final plan = asStr(asMap(b['plan'])['name']);
  return plan.isNotEmpty ? plan : 'Garden visit';
}

// ─── Next visit — dark panel with a step tracker ─────────────────────────────
class _NextVisit extends StatelessWidget {
  final Map<String, dynamic> b;
  const _NextVisit({required this.b});

  @override
  Widget build(BuildContext ctx) {
    final d = _visitDate(b);
    final time = asStr(b['scheduled_time']);
    final gardener = asStr(asMap(b['gardener'])['name']);
    return GestureDetector(
      onTap: () => Navigator.push(ctx, _slide(BookingDetailScreen(id: asInt(b['id'])))),
      child: VPod(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Next visit', style: p(12.5, color: Colors.white.withValues(alpha: 0.85))),
            const Spacer(),
            Text(asStr(b['booking_number'], '#${b['id']}'), style: p(11.5, color: Colors.white.withValues(alpha: 0.85))),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(d != null ? '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}' : 'Date to be set',
              style: vx(26, w: FontWeight.w600, color: Colors.white, ls: -0.5)),
            if (time.isNotEmpty) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(bottom: 3),
                child: Text(time.length >= 5 ? time.substring(0, 5) : time, style: p(14, w: FontWeight.w600, color: V.lime))),
            ],
          ]),
          const SizedBox(height: 4),
          Text(gardener.isNotEmpty ? 'Gardener: $gardener' : _bkTitle(b), style: p(13, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 18),
          _Tracker(status: asStr(b['status'])),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 15, color: Colors.white54),
            const SizedBox(width: 6),
            Expanded(child: Text(cleanAddr(asStr(b['service_address'], '—')), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: p(12, color: Colors.white.withValues(alpha: 0.85)))),
            const SizedBox(width: 8),
            Text(_bkAmount(b), style: vx(17, w: FontWeight.w600, color: Colors.white)),
          ]),
        ]),
      ),
    );
  }
}

// ─── Ticket card: date stub | perforation | details ─────────────────────────
class _BkCard extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BkCard({required this.b});
  @override
  Widget build(BuildContext ctx) {
    final status = asStr(b['status'], 'pending');
    final d = _visitDate(b);
    final addons = _cardAddons(b);
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: GCard(
        padding: EdgeInsets.zero,
        radius: BorderRadius.circular(22),
        onTap: () => Navigator.push(ctx, _slide(BookingDetailScreen(id: asInt(b['id'])))),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Date stub
          Container(
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(d != null ? _months[d.month - 1].toUpperCase() : '—', style: p(10.5, w: FontWeight.w600, color: V.fog, ls: 1)),
              Text(d != null ? '${d.day}' : '–', style: vx(30, w: FontWeight.w600, color: V.ink, h: 1.1)),
              Text(d != null ? _days[d.weekday - 1] : '', style: p(11, color: V.fog)),
            ]),
          ),
          // Perforation
          SizedBox(width: 1, child: CustomPaint(painter: _DashPainter())),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_bkTitle(b), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: vx(16.5, w: FontWeight.w600, color: V.ink))),
                const SizedBox(width: 8),
                GBadge(status, small: true),
              ]),
              const SizedBox(height: 4),
              Text(cleanAddr(asStr(b['service_address'], '—')), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: p(12, color: V.fog)),
              if (addons.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('+ ${addons.take(2).map((a) => asStr(a['name'] ?? a['addon_name'] ?? asMap(a['addon'])['name'], 'Add-on')).join(', ')}${addons.length > 2 ? ' +${addons.length - 2}' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: p(11, color: V.leaf)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Text(asStr(b['booking_number'], '#${b['id']}'), style: p(11, color: V.fog)),
                const Spacer(),
                Text(_bkAmount(b), style: vx(17, w: FontWeight.w600, color: V.ink)),
              ]),
            ]),
          )),
        ])),
      ));
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = V.ink.withValues(alpha: 0.15)..strokeWidth = 1;
    for (double y = 10; y < size.height - 10; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 3.5), paint);
    }
  }
  @override
  bool shouldRepaint(_DashPainter old) => false;
}

// ─── Visit summary (booking detail hero) ─────────────────────────────────────
class _VisitSummary extends StatelessWidget {
  final Map<String, dynamic> b;
  const _VisitSummary({required this.b});
  @override
  Widget build(BuildContext ctx) {
    final d = _visitDate(b);
    final time = asStr(b['scheduled_time']);
    final status = asStr(b['status']);
    final upcoming = _BkListState._upcoming.contains(status);
    return GCard(
      radius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_bkTitle(b), style: p(13, w: FontWeight.w500, color: V.leaf)),
        const SizedBox(height: 6),
        Text(d != null ? '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}' : 'Date to be set',
          style: vx(26, w: FontWeight.w600, color: V.ink, ls: -0.5)),
        if (time.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 16, color: V.deep),
            const SizedBox(width: 6),
            Text(time.length >= 5 ? time.substring(0, 5) : time, style: p(15, w: FontWeight.w600, color: V.deep)),
          ]),
        ],
        if (upcoming) ...[
          const SizedBox(height: 18),
          _Tracker(status: status, light: true),
        ],
        const SizedBox(height: 16),
        Container(height: 1, color: V.ink.withValues(alpha: 0.08)),
        const SizedBox(height: 14),
        Row(children: [
          Text('Total', style: p(13, color: V.fog)),
          const Spacer(),
          Text(_bkAmount(b), style: vx(22, w: FontWeight.w600, color: V.ink)),
        ]),
      ]),
    );
  }
}

// Booked → Assigned → On the way → In progress
class _Tracker extends StatelessWidget {
  final String status;
  final bool light; // on a light card (dark text) vs a dark panel
  const _Tracker({required this.status, this.light = false});
  static const _steps = ['Booked', 'Assigned', 'On the way', 'In progress'];
  int get _stage => switch (status) { 'assigned' => 1, 'en_route' => 2, 'arrived' || 'in_progress' => 3, _ => 0 };
  @override
  Widget build(BuildContext ctx) {
    final stage = _stage;
    final done = light ? V.leaf : V.lime;
    final idle = light ? V.ink.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.3);
    final on = light ? V.ink : Colors.white;
    final off = light ? V.fog : Colors.white.withValues(alpha: 0.7);
    return Column(children: [
      Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle,
            color: i <= stage ? done : Colors.transparent,
            border: Border.all(color: i <= stage ? done : idle, width: 1.5))),
          if (i < _steps.length - 1)
            Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4),
              color: i < stage ? done : idle)),
        ],
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (var i = 0; i < _steps.length; i++)
          Expanded(child: Text(_steps[i],
            textAlign: i == 0 ? TextAlign.left : i == _steps.length - 1 ? TextAlign.right : TextAlign.center,
            style: p(11, w: i == stage ? FontWeight.w700 : FontWeight.w500,
              color: i <= stage ? on : off))),
      ]),
    ]);
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
  Map<String, dynamic>? _timeAddonInfo;
  bool _loading = true, _cancelling = false, _rating = false, _addingTime = false;
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
      _maybeLoadTimeAddon();
    } catch (_) { if (mounted && !quiet) setState(() => _loading = false); }
  }

  bool get _timeAddonEligible {
    final bk = _bk;
    if (bk == null) return false;
    // Only after the customer has shared the OTP and the visit has started.
    return asStr(bk['booking_type'], '') == 'ondemand'
        && _status == 'in_progress'
        && bk['otp_verified'] == true;
  }

  Future<void> _maybeLoadTimeAddon() async {
    if (!_timeAddonEligible) {
      if (_timeAddonInfo != null) setState(() => _timeAddonInfo = null);
      return;
    }
    try {
      final res = await _api.getTimeAddons(widget.id);
      if (!mounted) return;
      setState(() => _timeAddonInfo = asMap(res));
    } catch (_) {}
  }

  Future<void> _addTime() async {
    final cfg = asMap(_timeAddonInfo?['config']);
    final mins = asInt(cfg['block_minutes']);
    final price = asDouble(cfg['block_price']);
    final ok = await showGlassConfirm(context, title: 'Add $mins minutes?', message: '₹${price.toStringAsFixed(0)} will be added to this visit. Your gardener will be notified.', confirmLabel: 'Add time', cancelLabel: 'Cancel', destructive: false);
    if (ok != true) return;
    setState(() => _addingTime = true);
    try {
      final res = asMap(await _api.requestTimeAddon(widget.id));
      if (mounted) showMsg(context, asStr(res['message'], 'Extra time added'), ok: true);
      await _load(quiet: true);
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _addingTime = false); }
  }

  String get _status => asStr(_bk?['status'], 'pending');

  Future<void> _cancel() async {
    final ok = await showGlassConfirm(context, title: 'Cancel this booking?', message: 'This cannot be undone.', confirmLabel: 'Cancel booking', cancelLabel: 'Keep it', destructive: true);
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
    showGlassSheet(context,
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
    if (_loading) return Scaffold(backgroundColor: Colors.transparent, body: Column(children: [
      const VPageHeader(title: 'Booking'),
      const Expanded(child: Center(child: CircularProgressIndicator(color: V.leaf))),
    ]));
    if (_bk == null) return Scaffold(backgroundColor: Colors.transparent, body: Column(children: [
      const VPageHeader(title: 'Booking'),
      Expanded(child: GEmpty(title: 'Booking not found', sub: 'It may have been removed or cancelled.', icon: Icons.event_busy_outlined,
        action: GBtn(label: 'Back to bookings', onTap: () => Navigator.pop(ctx), w: 220, h: 48))),
    ]));

    final gardener  = asMap(_bk!['gardener']);
    final canCancel = ['pending', 'assigned'].contains(_status);
    final canRate   = _status == 'completed' && _bk!['rating'] == null;
    final hasRating = _bk!['rating'] != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(children: [
            _CircleBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 12),
            Expanded(child: Text(asStr(_bk!['booking_number'], '#${_bk!['id']}'), style: p(13, color: V.fog))),
            GBadge(_status),
          ]),
        ))),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: _VisitSummary(b: _bk!),
        )),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Booking info
            GCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GSec('Visit details'),
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
                Text('Included add-ons', style: vx(15, w: FontWeight.w600, color: V.ink)),
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
            ])),

            // Visit OTP
            if (_status == 'assigned') ...[
              const SizedBox(height: 12),
              GCard(
                radius: BorderRadius.circular(24),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.lock_outline_rounded, color: V.deep, size: 18),
                    const SizedBox(width: 8),
                    Text('Visit OTP', style: vx(18, w: FontWeight.w600, color: V.ink)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Share this with your gardener when they arrive', style: p(12.5, color: V.fog)),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (final ch in asStr(_bk!['otp'], '—').split('')) Container(
                      width: 46, height: 54,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(14)),
                      child: Text(ch, style: vx(26, w: FontWeight.w600, color: V.ink)),
                    ),
                  ]),
                ]),
              ),
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
              ])),
            ],

            // Time-extension addon — only after customer has shared OTP & visit started
            if (_timeAddonEligible && _timeAddonInfo != null) ...[
              const SizedBox(height: 12),
              _TimeAddonCard(
                info: _timeAddonInfo!,
                loading: _addingTime,
                onAdd: _addTime,
              ),
            ],

            // Visit report (before/after photos + checklist)
            if (_status == 'completed') ...[
              const SizedBox(height: 12),
              _VisitReportCard(bk: _bk!),
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
                ])),
            ],

            const SizedBox(height: 20),
            if (canRate)   GBtn(label: 'Rate Your Visit', icon: Icons.star_rounded, gold: true, onTap: _showRating),
            if (!['cancelled', 'failed'].contains(_status)) ...[
              if (canRate) const SizedBox(height: 10),
              GBtn(label: 'Download Invoice', icon: Icons.receipt_long_rounded, outline: true,
                onTap: () => downloadInvoice(ctx, InvoiceType.booking, widget.id)),
            ],
            if (canCancel) ...[
              const SizedBox(height: 10),
              GBtn(label: 'Cancel Booking', danger: true, outline: true, loading: _cancelling, onTap: _cancel),
            ],
          ])),
        ),
      ]),
    );
  }
}

// ─── Time-Extension Addon Card ────────────────────────────────────────────────
class _TimeAddonCard extends StatelessWidget {
  final Map<String, dynamic> info;
  final bool loading;
  final VoidCallback onAdd;
  const _TimeAddonCard({required this.info, required this.loading, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cfg = asMap(info['config']);
    final totals = asMap(info['totals']);
    final configured = cfg['configured'] == true;
    final mins = asInt(cfg['block_minutes']);
    final price = asDouble(cfg['block_price']);
    final extraMins = asInt(totals['extra_time_minutes']);
    final extraAmt = asDouble(totals['extra_time_amount']);

    if (!configured) {
      return GCard(padding: const EdgeInsets.all(16), child: Row(children: [
        const Icon(Icons.access_time_rounded, size: 18, color: C.t4),
        const SizedBox(width: 10),
        Expanded(child: Text('Time extensions are not available in this zone.',
            style: p(12, color: C.t3))),
      ]));
    }

    return GCard(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.access_time_rounded, size: 18, color: C.forest),
        const SizedBox(width: 8),
        Text('NEED MORE TIME?', style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.8)),
      ]),
      const SizedBox(height: 10),
      Text('Extend this visit in blocks of $mins min at ₹${price.toStringAsFixed(0)} per block.',
          style: p(13, color: C.t2, h: 1.4)),
      if (extraMins > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: C.forest.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.check_circle_outline_rounded, size: 14, color: C.forest),
            const SizedBox(width: 6),
            Text('Already added: $extraMins min  •  +₹${extraAmt.toStringAsFixed(0)}',
                style: p(12, w: FontWeight.w600, color: C.forest)),
          ])),
      ],
      const SizedBox(height: 14),
      GBtn(
        label: '+ Add $mins min  (₹${price.toStringAsFixed(0)})',
        icon: Icons.add_rounded,
        gold: true,
        loading: loading,
        onTap: onAdd),
    ]));
  }
}

// ─── Visit Report Card ────────────────────────────────────────────────────────
class _VisitReportCard extends StatelessWidget {
  final Map<String, dynamic> bk;
  const _VisitReportCard({required this.bk});

  @override
  Widget build(BuildContext context) {
    final beforeImg = bk['before_image'] as String?;
    final afterImg  = bk['after_image']  as String?;
    final hasPhotos = (beforeImg?.isNotEmpty == true) || (afterImg?.isNotEmpty == true);

    // Parse checklist from gardener_notes JSON
    List<String> tasks = [];
    String? notes;
    final raw = bk['gardener_notes'];
    if (raw != null && raw.toString().startsWith('{')) {
      try {
        final parsed = jsonDecode(raw.toString()) as Map<String, dynamic>;
        tasks = List<String>.from(parsed['tasks'] as List? ?? []);
        notes = parsed['notes'] as String?;
      } catch (_) {}
    } else if (raw != null && raw.toString().isNotEmpty) {
      notes = raw.toString();
    }

    if (!hasPhotos && tasks.isEmpty && (notes == null || notes.isEmpty)) {
      return const SizedBox.shrink();
    }

    return GCard(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 8),
        Text('VISIT REPORT', style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.8)),
      ]),

      // Before / After photos
      if (hasPhotos) ...[
        const SizedBox(height: 14),
        Row(children: [
          if (beforeImg != null && beforeImg.isNotEmpty)
            Expanded(child: _ReportPhoto(url: beforeImg, label: 'Before')),
          if (beforeImg != null && beforeImg.isNotEmpty && afterImg != null && afterImg.isNotEmpty)
            const SizedBox(width: 10),
          if (afterImg != null && afterImg.isNotEmpty)
            Expanded(child: _ReportPhoto(url: afterImg, label: 'After')),
        ]),
      ],

      // Checklist
      if (tasks.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Tasks Completed', style: p(12, w: FontWeight.w700, color: C.t1)),
        const SizedBox(height: 8),
        ...tasks.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, size: 15, color: C.green),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: p(13, color: C.t2))),
          ]),
        )),
      ],

      // Gardener notes
      if (notes != null && notes.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.sticky_note_2_outlined, size: 14, color: C.t4),
            const SizedBox(width: 8),
            Expanded(child: Text(notes, style: p(12, color: C.t3, h: 1.5))),
          ]),
        ),
      ],
    ]));
  }
}

class _ReportPhoto extends StatelessWidget {
  final String url;
  final String label;
  const _ReportPhoto({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.5)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url, cacheWidth: 900,
          height: 120, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(Icons.broken_image_rounded, color: C.t4, size: 28)),
          ),
          loadingBuilder: (_, child, progress) => progress == null ? child : Container(
            height: 120,
            decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.forest)),
          ),
        ),
      ),
    ]);
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

// Standard route: glass backdrop + iOS slide/swipe-back from the theme.
Route<dynamic> _slide(Widget page) => MaterialPageRoute(builder: (_) => page);
