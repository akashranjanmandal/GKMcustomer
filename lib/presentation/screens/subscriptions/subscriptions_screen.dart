import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
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
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Cancel Subscription?', style: p(17, w: FontWeight.w700, color: C.t1)),
      content: Text('All future visits will be permanently cancelled. This cannot be undone.', style: p(14, color: C.t3)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep Plan', style: p(14, color: C.t3))),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: Text('Yes, Cancel', style: p(14, w: FontWeight.w700, color: C.red))),
      ]));
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ScheduleSheet(sub: sub, api: _api, onDone: _load),
    );
  }

  void _showDetails(Map<String, dynamic> sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DetailsSheet(sub: sub),
    );
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: C.bg,
    body: NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(child: GHeader(pb: 16,
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(ctx),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Subscriptions', style: p(18, w: FontWeight.w800, color: Colors.white)),
              Text('Manage your garden plans', style: p(11, color: Colors.white60)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pushNamed(ctx, '/book'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.gold, C.goldDk]),
                  borderRadius: BorderRadius.circular(99)),
                child: Text('+ New Plan', style: p(12, w: FontWeight.w700, color: const Color(0xFF1A0F00))))),
          ]))),
      ],
      body: RefreshIndicator(
        color: C.forest, onRefresh: _load,
        child: _loading
          ? ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: 3,
              itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 16), child: GSkelCard()))
          : _subs.isEmpty
            ? ListView(children: [GEmpty(
                title: 'No subscriptions yet',
                sub: 'Subscribe to a monthly garden care plan and never worry about your plants again',
                icon: Icons.card_membership_outlined,
                action: GBtn(label: 'Browse Plans', onTap: () => Navigator.pushNamed(ctx, '/book'), w: 180, h: 44))])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _subs.length,
                itemBuilder: (_, i) => _SubCard(
                  sub: _subs[i],
                  acting: _acting,
                  onPause: () => _pause(asInt(_subs[i]['id'])),
                  onResume: () => _resume(asInt(_subs[i]['id'])),
                  onCancel: () => _cancel(asInt(_subs[i]['id'])),
                  onSchedule: () => _showSchedule(asMap(_subs[i])),
                  onDetails: () => _showDetails(asMap(_subs[i])),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 60))
                  .slideY(begin: 0.06, end: 0, delay: Duration(milliseconds: i * 60)),
              ),
      ),
    ),
  );
}

// ─── Subscription Card ────────────────────────────────────────────────────────
class _SubCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final bool acting;
  final VoidCallback onPause, onResume, onCancel, onSchedule, onDetails;
  const _SubCard({required this.sub, required this.acting, required this.onPause,
    required this.onResume, required this.onCancel, required this.onSchedule, required this.onDetails});

  @override
  Widget build(BuildContext ctx) {
    final status = asStr(sub['status'], 'pending');
    final isActive = status == 'active';
    final isPaused = status == 'paused';
    final plan = asMap(sub['plan']);
    final visitsPerMonth = asInt(plan['visits_per_month']);
    final scheduledCount = asInt(sub['scheduled_visits_count']);
    final canSchedule = isActive && scheduledCount < visitsPerMonth;

    final nextVisit = asStr(sub['next_visit_date']);

    return GCard(
      padding: EdgeInsets.zero,
      bordered: true,
      shadows: isActive ? [BoxShadow(color: C.forest.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))] : s1(),
      child: Column(children: [
        // Status bar for active
        if (isActive) Container(
          height: 34, width: double.infinity,
          decoration: BoxDecoration(
            color: C.green.withOpacity(0.08),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.green)),
            const SizedBox(width: 7),
            Text('ACTIVE SUBSCRIPTION', style: p(9.5, w: FontWeight.w800, color: C.green, ls: 0.8)),
          ])),
        if (isPaused) Container(
          height: 34, width: double.infinity,
          decoration: BoxDecoration(
            color: C.amber.withOpacity(0.08),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.amber)),
            const SizedBox(width: 7),
            Text('PAUSED', style: p(9.5, w: FontWeight.w800, color: C.amber, ls: 0.8)),
          ])),

        Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: isActive ? C.forest.withOpacity(0.08) : C.subtle,
                borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.card_membership_rounded, size: 22, color: isActive ? C.forest : C.t4)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asStr(plan['name'], 'Garden Plan'), style: p(15, w: FontWeight.w800, color: C.t1)),
              Text('${sub['plant_count'] ?? '—'} plants · $scheduledCount/$visitsPerMonth visits', style: p(11, color: C.t3)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${asDouble(plan['price']).toStringAsFixed(0)}',
                style: p(18, w: FontWeight.w900, color: C.forest, ls: -0.5)),
              Text('/month', style: p(10, color: C.t4)),
            ]),
          ]),

          const SizedBox(height: 14),

          // Details row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Row(children: [
                Expanded(child: _InfoCol(label: 'Start Date', value: _fmt(asStr(sub['start_date'])))),
                Expanded(child: _InfoCol(label: 'End Date', value: _fmt(asStr(sub['end_date'])))),
                if (nextVisit.isNotEmpty) Expanded(child: _InfoCol(label: 'Next Visit', value: _fmt(nextVisit))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _InfoCol(label: 'Address', value: asStr(sub['service_address'], '—'))),
              ]),
            ]),
          ),

          // Action buttons
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (isActive && canSchedule)
              _ActionBtn(label: 'Schedule Dates', icon: Icons.calendar_month_rounded, primary: true, onTap: acting ? null : onSchedule),
            if (isActive)
              _ActionBtn(label: 'Pause', icon: Icons.pause_rounded, onTap: acting ? null : onPause),
            if (isPaused)
              _ActionBtn(label: 'Resume', icon: Icons.play_arrow_rounded, primary: true, onTap: acting ? null : onResume),
            _ActionBtn(label: 'View Visits', icon: Icons.list_alt_rounded, onTap: onDetails),
            if (isActive || isPaused)
              _ActionBtn(label: 'Cancel', icon: Icons.close_rounded, danger: true, onTap: acting ? null : onCancel),
          ]),
        ])),
      ]),
    );
  }

  String _fmt(String s) {
    if (s.length >= 10) return s.substring(0, 10);
    return s.isEmpty ? '—' : s;
  }
}

class _InfoCol extends StatelessWidget {
  final String label, value;
  const _InfoCol({required this.label, required this.value});
  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: p(9, w: FontWeight.w700, color: C.t4, ls: 0.5)),
    const SizedBox(height: 2),
    Text(value, style: p(11, w: FontWeight.w600, color: C.t2), maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon;
  final bool primary, danger; final VoidCallback? onTap;
  const _ActionBtn({required this.label, required this.icon, required this.onTap, this.primary = false, this.danger = false});
  @override
  Widget build(BuildContext ctx) {
    final col = danger ? C.red : primary ? C.forest : C.t3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? C.forest : danger ? C.red.withOpacity(0.08) : C.subtle,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: primary ? C.forest : danger ? C.red.withOpacity(0.3) : C.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: primary ? Colors.white : col),
          const SizedBox(width: 6),
          Text(label, style: p(11, w: FontWeight.w700, color: primary ? Colors.white : col)),
        ]),
      ),
    );
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
