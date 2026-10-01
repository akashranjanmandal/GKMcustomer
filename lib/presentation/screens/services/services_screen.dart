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
    backgroundColor: Colors.transparent,
    body: CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: VPageHeader(
        title: 'Services',
        subtitle: "What's included, how it's done, and answers to common questions.",
      )),
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ..._body(ctx),
    ]),
  );

  List<Widget> _body(BuildContext ctx) {
    if (_loading) {
      return [SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const Padding(padding: EdgeInsets.only(bottom: 14), child: GSkelCard()), childCount: 4)),
      )];
    }
    if (_error != null) {
      return [SliverFillRemaining(hasScrollBody: false, child: GEmpty(
        title: 'Couldn\'t load services',
        sub: _error!,
        icon: Icons.wifi_off_rounded,
        action: GBtn(label: 'Try again', onTap: _load, w: 180, h: 48)))];
    }
    if (_services.isEmpty) {
      return [const SliverFillRemaining(hasScrollBody: false, child: GEmpty(
        title: 'No services yet',
        sub: 'Our service catalogue will appear here soon.',
        icon: Icons.spa_outlined))];
    }
    return [SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).padding.bottom + 32),
      sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
        final svc = _services[i];
        final name = asStr(svc['name'], 'Service');
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => showServiceDetailsSheet(ctx, svc),
            child: Container(
              height: 196,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(serviceImageFor('${asStr(svc['slug'])} $name', i), fit: BoxFit.cover, cacheWidth: 900),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE60B1F14)], stops: [0.25, 1]))),
                Positioned(left: 18, right: 18, bottom: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: vx(22, w: FontWeight.w600, color: Colors.white, h: 1.15)),
                  const SizedBox(height: 4),
                  Text(asStr(svc['overview']), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: p(12.5, color: Colors.white.withValues(alpha: 0.8), h: 1.4)),
                ])),
                Positioned(top: 14, right: 14, child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_outward_rounded, size: 18, color: V.ink),
                )),
              ]),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: (i * 50).clamp(0, 400)))
          .slideY(begin: 0.05, end: 0, delay: Duration(milliseconds: (i * 50).clamp(0, 400)));
      }, childCount: _services.length)),
    )];
  }
}
