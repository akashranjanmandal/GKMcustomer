import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// ─── Our Services ─────────────────────────────────────────────────────────────
// Full catalogue from GET /service-details (cached for the session). Tapping a
// service opens the shared details bottom sheet (includes/excludes/steps/FAQs).
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override State<ServicesScreen> createState() => _ServicesState();
}

class _ServicesState extends State<ServicesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ServiceDetailsCache.all();
      if (!mounted) return;
      setState(() { _services = list; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load services. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: C.bg,
    body: Column(children: [
      GHeader(pb: 20, child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(ctx),
          child: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Our Services', style: p(18, w: FontWeight.w800, color: Colors.white)),
          Text("What's included, how it works & FAQs", style: p(11, color: Colors.white60)),
        ])),
      ])),
      Expanded(child: _body(ctx)),
    ]),
  );

  Widget _body(BuildContext ctx) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: 5,
        itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 14), child: GSkelCard()));
    }
    if (_error != null) {
      return GEmpty(
        title: 'Couldn\'t load services',
        sub: _error!,
        icon: Icons.wifi_off_rounded,
        action: GBtn(label: 'Retry', onTap: _load, w: 160, h: 44));
    }
    if (_services.isEmpty) {
      return const GEmpty(
        title: 'No services yet',
        sub: 'Our service catalogue will appear here soon.',
        icon: Icons.spa_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _services.length,
      itemBuilder: (_, i) {
        final svc = _services[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GCard(
            onTap: () => showServiceDetailsSheet(ctx, svc),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.forest3, C.forest],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14)),
                child: Icon(serviceIconFor(asStr(svc['slug'])), size: 21, color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asStr(svc['name'], 'Service'), style: p(14, w: FontWeight.w700, color: C.t1)),
                const SizedBox(height: 3),
                Text(asStr(svc['overview']), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: p(12, color: C.t3, h: 1.45)),
              ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: C.t4),
            ]),
          ).animate().fadeIn(delay: Duration(milliseconds: (i * 40).clamp(0, 400)))
            .slideY(begin: 0.05, end: 0, delay: Duration(milliseconds: (i * 40).clamp(0, 400))),
        );
      });
  }
}
