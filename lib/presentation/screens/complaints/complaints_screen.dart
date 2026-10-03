import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
import '../../../utils/validators.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import 'complaint_detail_screen.dart';

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
    showGlassSheet(context, builder: (_) => _NewComplaintSheet(api: _api, onDone: _load),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).padding.bottom + 32;
    final open = _complaints.where((c) => !['resolved', 'closed'].contains(asStr(asMap(c)['status']))).length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: V.leaf, onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          const SliverToBoxAdapter(child: VPageHeader(title: 'Support', subtitle: "Something not right? We'll sort it out.")),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
            child: VPod(
              radius: 26,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How can we help?', style: vx(22, w: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Tell us about a booking, a gardener visit, an order or a payment. Most issues are resolved within a day.',
                  style: p(12.5, color: Colors.white.withValues(alpha: 0.85), h: 1.45)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _showNewComplaint,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                    decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_outlined, size: 17, color: V.ink),
                      const SizedBox(width: 8),
                      Text('Raise an issue', style: p(13.5, w: FontWeight.w600, color: V.ink)),
                    ]),
                  ),
                ),
              ]),
            ),
          )),
          if (!_loading && _complaints.isNotEmpty) SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text('Your tickets', style: vx(20, w: FontWeight.w600, color: V.ink))),
              if (open > 0) Text('$open open', style: p(12.5, w: FontWeight.w600, color: C.amber)),
            ]),
          )),
          if (_loading)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 3)),
            )
          else if (_complaints.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: GEmpty(
              title: 'No tickets yet',
              sub: "Issues you raise will show up here, along with our replies.",
              icon: Icons.headset_mic_outlined,
              action: GBtn(label: 'Raise an issue', onTap: _showNewComplaint, w: 200, h: 48)))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                final c = asMap(_complaints[i]);
                final cid = asInt(c['id']);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaintId: cid)));
                    _load();
                  },
                  child: _ComplaintCard(c: c)
                    ,
                );
              }, childCount: _complaints.length)),
            ),
        ]),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> c;
  const _ComplaintCard({required this.c});

  @override
  Widget build(BuildContext ctx) {
    final status = asStr(c['status'], 'open');
    final type = asStr(c['type']).replaceAll('_', ' ');
    final resolved = status == 'resolved' || status == 'closed';
    final accent = resolved ? C.green : (asStr(c['priority']) == 'high' ? C.red : C.amber);
    final date = asStr(c['created_at'] ?? c['createdAt']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GCard(
        padding: EdgeInsets.zero,
        radius: BorderRadius.circular(22),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (type.isNotEmpty) Text(type[0].toUpperCase() + type.substring(1), style: p(11.5, color: V.fog)),
                  Text(asStr(c['subject'], asStr(c['ticket_number'], 'Ticket #${c['id']}')), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: vx(17, w: FontWeight.w600, color: V.ink, h: 1.2)),
                ])),
                const SizedBox(width: 8),
                GBadge(status, small: true),
              ]),
              if (asStr(c['description']).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(asStr(c['description']), maxLines: 2, overflow: TextOverflow.ellipsis, style: p(12.5, color: V.ink.withValues(alpha: 0.75), h: 1.45)),
              ],
              if (resolved && asStr(c['resolution']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 15, color: C.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(asStr(c['resolution']), style: p(12, color: const Color(0xFF166534), h: 1.4))),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Text(date.length >= 10 ? date.substring(0, 10) : '', style: p(11, color: V.fog)),
                if (c['booking_id'] != null) ...[
                  Text('  ·  ', style: p(11, color: V.fog)),
                  Text('Booking #${c['booking_id']}', style: p(11, color: V.fog)),
                ],
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: V.fog),
              ]),
            ]),
          )),
        ])),
      ),
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
    final err = Validators.firstError([
      Validators.integer(_bookingCtrl.text, field: 'Order ID', min: 1),
      Validators.text(_descCtrl.text, field: 'Description', min: 5, max: 2000),
    ]);
    if (err != null) { showMsg(context, err, err: true); return; }
    final bookingId = int.parse(_bookingCtrl.text.trim());
    setState(() => _submitting = true);
    try {
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

      GSec('Order ID *'),
      const SizedBox(height: 10),
      TextField(controller: _bookingCtrl, keyboardType: TextInputType.number,
        style: p(14, color: C.t2),
        decoration: const InputDecoration(hintText: 'Enter your booking / order ID (required)')),
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
