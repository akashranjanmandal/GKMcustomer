import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotifState();
}

class _NotifState extends State<NotificationsScreen> {
  final _api = Api();
  List<dynamic> _items = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getNotifications();
      if (mounted) setState(() { _items = asList(r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      await _load();
    } catch (_) {}
  }

  Future<void> _markRead(int id, int i) async {
    if (_items[i]['read_at'] != null) return;
    try {
      await _api.markNotificationRead(id);
      if (mounted) setState(() => _items[i]['read_at'] = DateTime.now().toIso8601String());
    } catch (_) {}
  }

  static IconData _icon(String type) => switch (type) {
    'booking_assigned' || 'booking_update' => Icons.calendar_month_rounded,
    'booking_completed'                    => Icons.check_circle_rounded,
    'booking_cancelled'                    => Icons.cancel_rounded,
    'payment'                              => Icons.receipt_rounded,
    'subscription'                         => Icons.card_membership_rounded,
    'alert'                                => Icons.warning_rounded,
    _                                      => Icons.notifications_rounded,
  };

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
            Expanded(child: Text('Notifications', style: p(18, w: FontWeight.w800, color: Colors.white))),
            if (_items.any((n) => n['read_at'] == null))
              GestureDetector(
                onTap: _markAllRead,
                child: Text('Mark all read', style: p(12, w: FontWeight.w700, color: C.gold))),
          ]))),
      ],
      body: RefreshIndicator(
        color: C.forest, onRefresh: _load,
        child: _loading
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: 6,
              itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 10), child: GSkelCard()))
          : _items.isEmpty
            ? const GEmpty(title: 'No notifications', sub: 'You\'re all caught up! Updates will appear here', icon: Icons.notifications_none_rounded)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final n = _items[i];
                  final id = asInt(n['id']);
                  final unread = n['read_at'] == null;
                  final type = asStr(n['type']);
                  return GestureDetector(
                    onTap: () => _markRead(id, i),
                    child: AnimatedContainer(duration: 200.ms,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: unread ? C.forest.withOpacity(0.04) : C.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: unread ? C.forest.withOpacity(0.18) : C.border),
                        boxShadow: s1()),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: (unread ? C.forest : C.t4).withOpacity(0.09),
                            borderRadius: BorderRadius.circular(12)),
                          child: Stack(children: [
                            Center(child: Icon(_icon(type), size: 20, color: unread ? C.forest : C.t4)),
                            if (unread) Positioned(top: 6, right: 6,
                              child: Container(width: 7, height: 7,
                                decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle))),
                          ])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(asStr(n['title'], 'Notification'), style: p(13, w: FontWeight.w700, color: unread ? C.t1 : C.t2)),
                          const SizedBox(height: 3),
                          Text(asStr(n['body'] ?? n['message']), style: p(12, color: C.t3, h: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(_timeAgo(asStr(n['created_at'])), style: p(10, color: C.t4)),
                        ])),
                      ])).animate().fadeIn(delay: Duration(milliseconds: i * 30)));
                }),
      ),
    ),
  );

  String _timeAgo(String s) {
    if (s.isEmpty) return '';
    try {
      final d = DateTime.parse(s).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1)  return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return s.length >= 10 ? s.substring(0, 10) : s; }
  }
}
