import 'package:flutter/material.dart';
import '../../../data/services/api.dart';
import '../../../data/services/invoice_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override State<SubscriptionsScreen> createState() => _SubsState();
}

class _SubsState extends State<SubscriptionsScreen> {
  final _api = Api();
  List<dynamic> _subs = [];
  bool _loading = true, _acting = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getMySubscriptions();
      if (mounted) setState(() { _subs = asList(r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pause(int id) async {
    setState(() => _acting = true);
    try {
      await _api.pauseSubscription(id);
      await _load();
      if (mounted) showMsg(context, 'Subscription paused.', ok: true);
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _acting = false); }
  }

  Future<void> _resume(int id) async {
    setState(() => _acting = true);
    try {
      await _api.resumeSubscription(id);
      await _load();
      if (mounted) showMsg(context, 'Subscription resumed!', ok: true);
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _acting = false); }
  }

  Future<void> _cancel(int id) async {
    final ok = await showGlassConfirm(context, title: 'Cancel subscription?', message: 'All future visits will be cancelled. This cannot be undone.', confirmLabel: 'Yes, cancel', cancelLabel: 'Keep plan', destructive: true);
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await _api.cancelSubscription(id);
      await _load();
      if (mounted) showMsg(context, 'Subscription cancelled.', ok: true);
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _acting = false); }
  }

  void _showSchedule(Map<String, dynamic> sub) {
    showGlassSheet(context, builder: (_) => _ScheduleSheet(sub: sub, api: _api, onDone: _load),
    );
  }

  void _showDetails(Map<String, dynamic> sub) {
    showGlassSheet(context, builder: (_) => _DetailsSheet(sub: sub),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).padding.bottom + 32;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: V.leaf, onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: VPageHeader(
            title: 'My plans',
            subtitle: 'Your garden care subscriptions and upcoming visits.',
            trailing: VPillAction(label: 'New plan', onTap: () => Navigator.pushNamed(ctx, '/plans')),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (_loading)
            SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 3)))
          else if (_subs.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: GEmpty(
              title: 'No plans yet',
              sub: 'Pick a monthly care plan and a gardener will look after your plants on a regular schedule.',
              icon: Icons.event_repeat_outlined,
              action: GBtn(label: 'Browse plans', onTap: () => Navigator.pushNamed(ctx, '/plans'), w: 200, h: 48)))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SubCard(
                  sub: asMap(_subs[i]),
                  acting: _acting,
                  onPause: () => _pause(asInt(_subs[i]['id'])),
                  onResume: () => _resume(asInt(_subs[i]['id'])),
                  onCancel: () => _cancel(asInt(_subs[i]['id'])),
                  onSchedule: () => _showSchedule(asMap(_subs[i])),
                  onDetails: () => _showDetails(asMap(_subs[i])),
                  onInvoice: () => downloadInvoice(context, InvoiceType.subscription, asInt(_subs[i]['id'])),
                ),
              ),
              childCount: _subs.length)),
            ),
        ]),
      ),
    );
  }
}

// ─── Subscription card — membership-card style ───────────────────────────────
class _SubCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final bool acting;
  final VoidCallback onPause, onResume, onCancel, onSchedule, onDetails, onInvoice;
  const _SubCard({required this.sub, required this.acting, required this.onPause,
    required this.onResume, required this.onCancel, required this.onSchedule, required this.onDetails,
    required this.onInvoice});

  static String _fmt(String s) {
    final d = DateTime.tryParse(s);
    if (d == null) return s.isEmpty ? '—' : s;
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  @override
  Widget build(BuildContext ctx) {
    final status = asStr(sub['status'], 'pending');
    final isActive = status == 'active';
    final isPaused = status == 'paused';
    final plan = asMap(sub['plan']);
    final visitsPerMonth = asInt(plan['visits_per_month']);
    final scheduled = asInt(sub['scheduled_visits_count']);
    final canSchedule = isActive && scheduled < visitsPerMonth;
    final nextVisit = asStr(sub['next_visit_date']);
    final dark = isActive;
    final fg = dark ? Colors.white : V.ink;
    final muted = dark ? Colors.white.withValues(alpha: 0.85) : V.fog;
    final progress = visitsPerMonth > 0 ? (scheduled / visitsPerMonth).clamp(0.0, 1.0) : 0.0;

    Widget action(IconData icon, String label, VoidCallback? onTap, {bool primary = false}) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Column(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary ? V.lime : (dark ? Colors.white.withValues(alpha: 0.1) : V.mint),
              ),
              child: Icon(icon, size: 20, color: primary ? V.ink : (dark ? Colors.white : V.deep)),
            ),
            const SizedBox(height: 6),
            Text(label, style: p(11, w: FontWeight.w500, color: fg)),
          ]),
        ),
      ),
    );

    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asStr(plan['name'], 'Garden plan'), style: vx(22, w: FontWeight.w600, color: fg, ls: -0.3)),
          const SizedBox(height: 2),
          Text('${sub['plant_count'] ?? '—'} plants  ·  ₹${asDouble(plan['price']).toStringAsFixed(0)} / month', style: p(12.5, color: muted)),
        ])),
        GBadge(status, small: true),
      ]),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Next visit', style: p(11.5, color: muted)),
          const SizedBox(height: 2),
          Text(nextVisit.isNotEmpty ? _fmt(nextVisit) : (canSchedule ? 'Not scheduled' : '—'),
            style: vx(24, w: FontWeight.w600, color: fg, h: 1.05)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Valid till', style: p(11.5, color: muted)),
          const SizedBox(height: 2),
          Text(_fmt(asStr(sub['end_date'])), style: p(14, w: FontWeight.w600, color: fg)),
        ]),
      ]),
      if (visitsPerMonth > 0) ...[
        const SizedBox(height: 16),
        Row(children: [
          Text('Visits this month', style: p(11.5, color: muted)),
          const Spacer(),
          Text('$scheduled of $visitsPerMonth scheduled', style: p(11.5, w: FontWeight.w600, color: fg)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress, minHeight: 6,
            backgroundColor: dark ? Colors.white.withValues(alpha: 0.12) : V.ink.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(dark ? V.lime : V.leaf),
          ),
        ),
      ],
      const SizedBox(height: 18),
      Row(children: [
        if (isActive) action(Icons.calendar_month_outlined, 'Schedule', acting || !canSchedule ? null : onSchedule, primary: canSchedule),
        if (isActive) action(Icons.pause_rounded, 'Pause', acting ? null : onPause),
        if (isPaused) action(Icons.play_arrow_rounded, 'Resume', acting ? null : onResume, primary: true),
        action(Icons.list_alt_outlined, 'Visits', onDetails),
        if (!['cancelled', 'failed'].contains(status)) action(Icons.receipt_long_outlined, 'Invoice', onInvoice),
      ]),
      if (isActive || isPaused) ...[
        const SizedBox(height: 12),
        Center(child: GestureDetector(
          onTap: acting ? null : onCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text('Cancel plan', style: p(12, w: FontWeight.w500, color: dark ? Colors.white.withValues(alpha: 0.55) : C.red)),
          ),
        )),
      ],
    ]);

    const pad = EdgeInsets.fromLTRB(20, 20, 20, 12);
    return dark
        ? VPod(radius: 28, padding: pad, child: body)
        : GCard(padding: pad, radius: BorderRadius.circular(28), child: body);
  }
}

// ─── Schedule Sheet ───────────────────────────────────────────────────────────
class _ScheduleSheet extends StatefulWidget {
  final Map<String, dynamic> sub;
  final Api api;
  final VoidCallback onDone;
  const _ScheduleSheet({required this.sub, required this.api, required this.onDone});
  @override State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  final Set<String> _selectedDates = {};
  bool _submitting = false;
  DateTime _currentMonth = DateTime.now();

  int get _remaining {
    final plan = asMap(widget.sub['plan']);
    final visitsPerMonth = asInt(plan['visits_per_month']);
    return visitsPerMonth - asInt(widget.sub['scheduled_visits_count']);
  }

  String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _submit() async {
    if (_selectedDates.length != _remaining) {
      showMsg(context, 'Please select exactly $_remaining date(s)', err: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.api.selectSubscriptionDates(asInt(widget.sub['id']), _selectedDates.toList()..sort());
      if (mounted) {
        showMsg(context, 'Visit dates scheduled!', ok: true);
        Navigator.pop(context);
        widget.onDone();
      }
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext ctx) {
    final startDate = DateTime.tryParse(asStr(widget.sub['start_date'])) ?? DateTime.now();
    final endDate = DateTime.tryParse(asStr(widget.sub['end_date'])) ?? DateTime.now().add(const Duration(days: 30));
    final today = DateTime.now();

    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0=Sun

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 16),
        Text('Schedule Visit Dates', style: p(18, w: FontWeight.w800, color: C.t1)),
        const SizedBox(height: 6),
        Text('Select $_remaining date(s) for your visits. Avoid weekends to skip surge pricing!',
          textAlign: TextAlign.center, style: p(12, color: C.t3, h: 1.5)),
        const SizedBox(height: 20),

        // Calendar
        GCard(padding: const EdgeInsets.all(16), child: Column(children: [
          // Month nav
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () { setState(() => _currentMonth = DateTime(year, month - 1)); },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                child: const Icon(Icons.chevron_left_rounded, size: 20, color: C.forest))),
            Text('${_monthName(month)} $year', style: p(15, w: FontWeight.w800, color: C.t1)),
            GestureDetector(
              onTap: () { setState(() => _currentMonth = DateTime(year, month + 1)); },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                child: const Icon(Icons.chevron_right_rounded, size: 20, color: C.forest))),
          ]),
          const SizedBox(height: 12),
          // Day headers
          Row(children: ['Su','Mo','Tu','We','Th','Fr','Sa'].map((d) =>
            Expanded(child: Center(child: Text(d, style: p(10, w: FontWeight.w700, color: C.t4))))).toList()),
          const SizedBox(height: 8),
          // Calendar grid
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7, childAspectRatio: 1.0,
            children: [
              ...List.generate(firstWeekday, (_) => const SizedBox()),
              ...List.generate(daysInMonth, (i) {
                final day = i + 1;
                final date = DateTime(year, month, day);
                final dateStr = _fmt(date);
                final isWeekend = date.weekday == 6 || date.weekday == 7;
                final isPast = date.isBefore(today);
                final isOutside = date.isBefore(startDate) || date.isAfter(endDate);
                final isDisabled = isPast || isOutside;
                final isSelected = _selectedDates.contains(dateStr);

                return GestureDetector(
                  onTap: isDisabled ? null : () {
                    setState(() {
                      if (isSelected) {
                        _selectedDates.remove(dateStr);
                      } else if (_selectedDates.length < _remaining) {
                        _selectedDates.add(dateStr);
                      } else {
                        showMsg(context, 'You can only select $_remaining date(s)', err: true);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? C.forest
                           : isDisabled ? Colors.transparent
                           : isWeekend ? C.red.withOpacity(0.08)
                           : Colors.transparent),
                    child: Center(child: Text('$day',
                      style: p(12, w: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? Colors.white
                             : isDisabled ? C.t4
                             : isWeekend ? C.red : C.t1)))),
                );
              }),
            ]),
        ])),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Selected: ${_selectedDates.length}/$_remaining', style: p(13, w: FontWeight.w600, color: C.t2)),
          if (_selectedDates.isNotEmpty)
            GestureDetector(onTap: () => setState(() => _selectedDates.clear()),
              child: Text('Clear all', style: p(12, w: FontWeight.w600, color: C.earth))),
        ]),
        const SizedBox(height: 16),
        GBtn(label: 'Confirm Dates', loading: _submitting,
          onTap: _selectedDates.length == _remaining ? _submit : null),
      ])),
    );
  }

  String _monthName(int m) => const ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];
}

// ─── Details Sheet ────────────────────────────────────────────────────────────
class _DetailsSheet extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _DetailsSheet({required this.sub});

  @override
  Widget build(BuildContext ctx) {
    final bookings = asList(sub['bookings']);
    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 16),
          Text('Scheduled Visits', style: p(18, w: FontWeight.w800, color: C.t1)),
          const SizedBox(height: 4),
          Text(asStr(asMap(sub['plan'])['name'], 'Garden Plan'), style: p(12, color: C.t3)),
          const SizedBox(height: 20),
          Expanded(child: bookings.isEmpty
            ? const GEmpty(title: 'No visits scheduled', sub: 'Tap "Schedule Dates" on your subscription card to pick dates', icon: Icons.calendar_month_outlined)
            : ListView.builder(
                controller: ctrl,
                itemCount: bookings.length,
                itemBuilder: (_, i) {
                  final b = asMap(bookings[i]);
                  final status = asStr(b['status'], 'pending');
                  final dateStr = asStr(b['scheduled_date']);
                  DateTime? date;
                  try { date = DateTime.parse(dateStr); } catch (_) {}
                  return Padding(padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      if (date != null) Container(
                        width: 52, padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: C.forest.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                        child: Column(children: [
                          Text(const ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.month],
                            style: p(9, w: FontWeight.w700, color: C.forest, ls: 0.3)),
                          Text('${date.day}', style: p(18, w: FontWeight.w900, color: C.forest)),
                        ]))
                      else const SizedBox(width: 52),
                      const SizedBox(width: 12),
                      Expanded(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border), boxShadow: s1()),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(asStr(b['booking_number'], '#${b['id']}'), style: p(12, w: FontWeight.w700, color: C.t1)),
                            if (b['gardener'] != null)
                              Text('Gardener: ${asStr(asMap(b['gardener'])['name'])}', style: p(10, color: C.t3))
                            else
                              Text('Pending assignment', style: p(10, color: C.t4).copyWith(fontStyle: FontStyle.italic)),
                          ])),
                          GBadge(status),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
