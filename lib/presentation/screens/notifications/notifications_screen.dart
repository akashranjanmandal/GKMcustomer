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
    'booking_assigned' || 'booking_update' => Icons.calendar_month_outlined,
    'booking_completed'                    => Icons.task_alt_outlined,
    'booking_cancelled'                    => Icons.event_busy_outlined,
    'payment'                              => Icons.receipt_long_outlined,
    'subscription'                         => Icons.event_repeat_outlined,
    'alert'                                => Icons.error_outline_rounded,
    _                                      => Icons.notifications_none_outlined,
  };

  bool _isToday(String s) {
    final d = DateTime.tryParse(s)?.toLocal();
    final now = DateTime.now();
    return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).padding.bottom + 32;
    final unreadCount = _items.where((n) => n['read_at'] == null).length;
    final today = <int>[], earlier = <int>[];
    for (var i = 0; i < _items.length; i++) {
      (_isToday(asStr(_items[i]['created_at'])) ? today : earlier).add(i);
    }

    Widget group(String title, List<int> idx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text(title, style: vx(19, w: FontWeight.w600, color: V.ink))),
      GCard(
        padding: EdgeInsets.zero,
        radius: BorderRadius.circular(24),
        child: Column(children: [
          for (var k = 0; k < idx.length; k++) ...[
            if (k > 0) Container(height: 1, margin: const EdgeInsets.only(left: 70), color: V.ink.withValues(alpha: 0.06)),
            _row(idx[k]),
          ],
        ]),
      ),
      const SizedBox(height: 22),
    ]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: V.leaf, onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: VPageHeader(
            title: 'Alerts',
            subtitle: unreadCount > 0 ? '$unreadCount unread' : 'You\'re all caught up.',
            trailing: unreadCount > 0
              ? GestureDetector(
                  onTap: _markAllRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white)),
                    child: Text('Mark all read', style: p(12.5, w: FontWeight.w600, color: V.ink)),
                  ))
              : null,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (_loading)
            SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const GSkelCard(), childCount: 5)))
          else if (_items.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: GEmpty(
              title: 'No alerts', sub: 'Booking updates, payments and plan reminders will show up here.', icon: Icons.notifications_none_outlined))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (today.isNotEmpty) group('Today', today),
                if (earlier.isNotEmpty) group(today.isEmpty ? 'Recent' : 'Earlier', earlier),
              ]).animate().fadeIn(duration: 300.ms)),
            ),
        ]),
      ),
    );
  }

  Widget _row(int i) {
    final n = _items[i];
    final id = asInt(n['id']);
    final unread = n['read_at'] == null;
    final type = asStr(n['type']);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _markRead(id, i),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          VOrb(icon: _icon(type), size: 40, dark: unread),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(asStr(n['title'], 'Notification'),
                style: p(13.5, w: unread ? FontWeight.w700 : FontWeight.w500, color: V.ink, h: 1.3))),
              const SizedBox(width: 8),
              Text(_timeAgo(asStr(n['created_at'])), style: p(11, color: V.fog)),
            ]),
            if (asStr(n['body'] ?? n['message']).isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(asStr(n['body'] ?? n['message']), maxLines: 3, overflow: TextOverflow.ellipsis,
                style: p(12.5, color: unread ? V.ink.withValues(alpha: 0.75) : V.fog, h: 1.4)),
            ],
          ])),
        ]),
      ),
    );
  }

  // Relative time computed in IST (see timeAgoIST in api.dart).
  String _timeAgo(String s) => timeAgoIST(s);
}
