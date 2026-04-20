import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override State<ComplaintsScreen> createState() => _ComplaintsState();
}

class _ComplaintsState extends State<ComplaintsScreen> {
  final _api = Api();
  List<dynamic> _complaints = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getMyComplaints();
      if (mounted) setState(() { _complaints = asList(r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showNewComplaint() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NewComplaintSheet(api: _api, onDone: _load),
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
              Text('Support & Complaints', style: p(18, w: FontWeight.w800, color: Colors.white)),
              Text('We\'re here to help', style: p(11, color: Colors.white60)),
            ])),
            GestureDetector(
              onTap: _showNewComplaint,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.gold, C.goldDk]),
                  borderRadius: BorderRadius.circular(99)),
                child: Text('+ Raise Issue', style: p(12, w: FontWeight.w700, color: const Color(0xFF1A0F00))))),
          ]))),
      ],
      body: RefreshIndicator(
        color: C.forest, onRefresh: _load,
        child: _loading
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: 4,
              itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: GSkelCard()))
          : _complaints.isEmpty
            ? ListView(children: [GEmpty(
                title: 'No complaints',
                sub: 'If you have an issue with a booking or service, raise it here and we\'ll resolve it quickly',
                icon: Icons.support_agent_rounded,
                action: GBtn(label: 'Raise an Issue', icon: Icons.add_rounded, onTap: _showNewComplaint, w: 180, h: 44))])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _complaints.length,
                itemBuilder: (_, i) => _ComplaintCard(c: _complaints[i])
                  .animate().fadeIn(delay: Duration(milliseconds: i * 40))
                  .slideY(begin: 0.06, end: 0, delay: Duration(milliseconds: i * 40))),
      ),
    ),
  );
}

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> c;
  const _ComplaintCard({required this.c});

  static Color _priorityColor(String p) => switch (p) {
    'high'   => C.red,
    'medium' => C.amber,
    _        => C.t4,
  };

  @override
  Widget build(BuildContext ctx) {
    final status = asStr(c['status'], 'open');
    final type = asStr(c['type']);
    final priority = asStr(c['priority'], 'medium');
    final resolved = status == 'resolved' || status == 'closed';

    return GCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: (resolved ? C.green : C.amber).withOpacity(0.10),
                borderRadius: BorderRadius.circular(11)),
              child: Icon(resolved ? Icons.check_circle_rounded : Icons.support_agent_rounded,
                size: 20, color: resolved ? C.green : C.amber)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.replaceAll('_', ' ').toUpperCase(),
                style: p(10, w: FontWeight.w700, color: C.t4, ls: 0.5)),
              Text(asStr(c['id'] != null ? '#${c['id']}' : 'Complaint'), style: p(13, w: FontWeight.w700, color: C.t1)),
            ])),
            GBadge(status),
          ]),
          const SizedBox(height: 12),
          Text(asStr(c['description']), style: p(13, color: C.t2, h: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _priorityColor(priority).withOpacity(0.10),
                borderRadius: BorderRadius.circular(99)),
              child: Text(priority.toUpperCase(),
                style: p(9, w: FontWeight.w700, color: _priorityColor(priority), ls: 0.5))),
            const Spacer(),
            Text(asStr(c['created_at']).length >= 10 ? asStr(c['created_at']).substring(0, 10) : '—',
              style: p(10, color: C.t4)),
          ]),
          if (c['booking_id'] != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.link_rounded, size: 13, color: C.t4),
              const SizedBox(width: 5),
              Text('Booking #${c['booking_id']}', style: p(11, color: C.t3)),
            ]),
          ],
          if (resolved && (c['resolution'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.green.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.green.withOpacity(0.20))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: C.green),
                const SizedBox(width: 8),
                Expanded(child: Text(asStr(c['resolution']), style: p(12, color: C.green, h: 1.4))),
              ])),
          ],
        ])),
      ]),
    );
  }
}

// ─── New Complaint Sheet ──────────────────────────────────────────────────────
class _NewComplaintSheet extends StatefulWidget {
  final Api api; final VoidCallback onDone;
  const _NewComplaintSheet({required this.api, required this.onDone});
  @override State<_NewComplaintSheet> createState() => _NewComplaintSheetState();
}

class _NewComplaintSheetState extends State<_NewComplaintSheet> {
  final _descCtrl = TextEditingController();
  final _bookingCtrl = TextEditingController();
  String _type = 'service_quality';
  String _priority = 'medium';
  bool _submitting = false;

  static const _types = [
    ('service_quality', 'Service Quality'),
    ('gardener_behavior', 'Gardener Behavior'),
    ('payment_issue', 'Payment Issue'),
    ('app_issue', 'App Issue'),
    ('other', 'Other'),
  ];

  @override
  void dispose() { _descCtrl.dispose(); _bookingCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) { showMsg(context, 'Please describe your issue', err: true); return; }
    setState(() => _submitting = true);
    try {
      final bookingId = int.tryParse(_bookingCtrl.text.trim());
      await widget.api.createComplaint(
        type: _type,
        description: _descCtrl.text.trim(),
        priority: _priority,
        bookingId: bookingId,
      );
      if (mounted) {
        showMsg(context, 'Complaint raised! We\'ll respond within 24 hours.', ok: true);
        Navigator.pop(context);
        widget.onDone();
      }
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(99)))),
      const SizedBox(height: 16),
      Text('Raise an Issue', style: p(18, w: FontWeight.w800, color: C.t1)),
      const SizedBox(height: 4),
      Text('We\'ll get back to you within 24 hours', style: p(12, color: C.t3)),
      const SizedBox(height: 20),

      GSec('Issue Type'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) {
        final sel = t.$1 == _type;
        return GestureDetector(
          onTap: () => setState(() => _type = t.$1),
          child: AnimatedContainer(duration: 160.ms,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? C.forest : C.subtle,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: sel ? C.forest : C.border)),
            child: Text(t.$2, style: p(12, w: FontWeight.w600, color: sel ? Colors.white : C.t3))));
      }).toList()),
      const SizedBox(height: 18),

      GSec('Priority'),
      const SizedBox(height: 10),
      Row(children: [
        for (final prio in [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')]) ...[
          GestureDetector(
            onTap: () => setState(() => _priority = prio.$1),
            child: AnimatedContainer(duration: 160.ms,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _priority == prio.$1 ? (prio.$1 == 'high' ? C.red : prio.$1 == 'medium' ? C.amber : C.green) : C.subtle,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _priority == prio.$1 ? Colors.transparent : C.border)),
              child: Text(prio.$2, style: p(12, w: FontWeight.w600, color: _priority == prio.$1 ? Colors.white : C.t3)))),
        ]
      ]),
      const SizedBox(height: 18),

      GSec('Booking ID (optional)'),
      const SizedBox(height: 10),
      TextField(controller: _bookingCtrl, keyboardType: TextInputType.number,
        style: p(14, color: C.t2),
        decoration: const InputDecoration(hintText: 'Enter booking ID if related to a booking')),
      const SizedBox(height: 18),

      GSec('Describe Your Issue'),
      const SizedBox(height: 10),
      TextField(controller: _descCtrl, maxLines: 4, style: p(14, color: C.t2),
        decoration: const InputDecoration(hintText: 'Please describe what happened in detail...')),
      const SizedBox(height: 24),

      GBtn(label: 'Submit Complaint', loading: _submitting, onTap: _submit),
    ])),
  );
}
