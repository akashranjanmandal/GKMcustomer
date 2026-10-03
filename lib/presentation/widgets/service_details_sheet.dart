import 'package:flutter/material.dart';
import '../../data/services/api.dart';
import '../theme/theme.dart';
import 'verdant.dart';

// ─── Session cache ────────────────────────────────────────────────────────────
// Service-details content is static per app session — fetch once, keep in
// memory. `bySlug` is also warmed by `all()` so the booking flow reuses the
// list fetched by the Services screen (and vice versa).
class ServiceDetailsCache {
  ServiceDetailsCache._();
  static List<Map<String, dynamic>>? _all;
  static final Map<String, Map<String, dynamic>> _bySlug = {};

  static Future<List<Map<String, dynamic>>> all() async {
    final cached = _all;
    if (cached != null) return cached;
    final list = asList(await Api().getServiceDetails()).map(asMap).toList();
    if (list.isNotEmpty) {
      _all = list;
      for (final s in list) {
        final slug = asStr(s['slug']);
        if (slug.isNotEmpty) _bySlug[slug] = s;
      }
    }
    return list;
  }

  static Future<Map<String, dynamic>> bySlug(String slug) async {
    final hit = _bySlug[slug];
    if (hit != null) return hit;
    final m = asMap(await Api().getServiceDetails(slug));
    if (m.isNotEmpty) _bySlug[slug] = m;
    return m;
  }
}

// Icon per service slug (loose contains-matching so backend slugs map even if
// they differ slightly from the ones we know about).
IconData serviceIconFor(String slug) {
  final s = slug.toLowerCase();
  if (s.contains('one-time'))                          return Icons.bolt_rounded;
  if (s.contains('monthly'))                           return Icons.event_repeat_rounded;
  if (s.contains('balcony'))                           return Icons.balcony_rounded;
  if (s.contains('terrace') || s.contains('roof'))     return Icons.roofing_rounded;
  if (s.contains('vertical'))                          return Icons.park_rounded;
  if (s.contains('lawn'))                              return Icons.grass_rounded;
  if (s.contains('pest') || s.contains('disease'))     return Icons.pest_control_rounded;
  if (s.contains('makeover') || s.contains('landscap'))return Icons.auto_awesome_rounded;
  if (s.contains('kitchen') || s.contains('vegetable'))return Icons.restaurant_rounded;
  if (s.contains('soil') || s.contains('compost'))     return Icons.eco_rounded;
  if (s.contains('repot') || s.contains('pot'))        return Icons.yard_rounded;
  if (s.contains('doctor') || s.contains('health'))    return Icons.medical_services_rounded;
  if (s.contains('consult'))                           return Icons.support_agent_rounded;
  if (s.contains('corporate') || s.contains('office')) return Icons.business_rounded;
  return Icons.spa_rounded;
}

// ─── Sheet entry point ────────────────────────────────────────────────────────
// Opens a scrollable rounded-top bottom sheet rendering one service's
// overview, includes/excludes, steps and FAQs. `service` is a raw map from
// GET /service-details.
void showServiceDetailsSheet(BuildContext context, Map service) {
  showGlassSheet(context, builder: (_) => _ServiceDetailsSheet(service: asMap(service)));
}

class _ServiceDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> service;
  const _ServiceDetailsSheet({required this.service});

  @override
  Widget build(BuildContext ctx) {
    final name     = asStr(service['name'], 'Service');
    final overview = asStr(service['overview']);
    final includes = asList(service['includes']).map((e) => asStr(e)).where((s) => s.trim().isNotEmpty).toList();
    final excludes = asList(service['excludes']).map((e) => asStr(e)).where((s) => s.trim().isNotEmpty).toList();
    final steps    = asList(service['steps']).map((e) => asStr(e)).where((s) => s.trim().isNotEmpty).toList();
    final faqs     = asList(service['faqs']).map(asMap).where((f) => asStr(f['q']).trim().isNotEmpty).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: EdgeInsets.zero,
        children: [
          // ── Photo header ──────────────────────────────────────────────
          SizedBox(
            height: 210,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(serviceImageFor('${asStr(service['slug'])} $name', 0), fit: BoxFit.cover, cacheWidth: 900),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Colors.transparent, Color(0xE60B1F14)], stops: [0, 0.35, 1]))),
              Positioned(top: 12, left: 0, right: 0, child: Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(99))))),
              Positioned(top: 18, right: 16, child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 18, color: V.ink)))),
              Positioned(left: 20, right: 20, bottom: 18,
                child: Text(name, style: vx(26, w: FontWeight.w600, color: Colors.white, h: 1.1))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (overview.isNotEmpty) ...[
                Text(overview, style: p(14, color: V.ink.withValues(alpha: 0.75), h: 1.6)),
                const SizedBox(height: 24),
              ],
              if (includes.isNotEmpty) ...[
                _sec("What's included"),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white)),
                  child: Column(children: includes.map((s) => _bulletRow(s, icon: Icons.check_rounded, iconColor: V.leaf,
                    style: p(13.5, color: V.ink, h: 1.45))).toList()),
                ),
                const SizedBox(height: 24),
              ],
              if (excludes.isNotEmpty) ...[
                _sec('Not included'),
                ...excludes.map((s) => _bulletRow(s, icon: Icons.remove_rounded, iconColor: V.fog,
                  style: p(13, color: V.fog, h: 1.45))),
                const SizedBox(height: 18),
              ],
              if (steps.isNotEmpty) ...[
                _sec("How it's done"),
                ...List.generate(steps.length, (i) => _stepRow(i + 1, steps[i], last: i == steps.length - 1)),
                const SizedBox(height: 18),
              ],
              if (faqs.isNotEmpty) ...[
                _sec('Questions'),
                ...faqs.map((f) => _FaqTile(q: asStr(f['q']), a: asStr(f['a']))),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sec(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(s, style: vx(19, w: FontWeight.w600, color: V.ink)),
  );

  Widget _bulletRow(String raw, {required IconData icon, required Color iconColor, required TextStyle style}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 10),
        Expanded(child: _lineText(raw, style)),
      ]),
    );

  // Numbered timeline: number disc + connecting line.
  Widget _stepRow(int n, String raw, {required bool last}) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Column(children: [
        Container(width: 28, height: 28,
          decoration: const BoxDecoration(color: V.ink, shape: BoxShape.circle),
          child: Center(child: Text('$n', style: p(12, w: FontWeight.w600, color: Colors.white)))),
        if (!last) Expanded(child: Container(width: 1.5, color: V.ink.withValues(alpha: 0.15))),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 16),
        child: _lineText(raw, p(13.5, color: V.ink, h: 1.45)),
      )),
    ]),
  );

  // Renders a content line; a "NEW:" prefix becomes a small chip.
  Widget _lineText(String raw, TextStyle style) {
    var text = raw.trim();
    final isNew = text.toUpperCase().startsWith('NEW:');
    if (!isNew) return Text(text, style: style);
    text = text.substring(4).trim();
    return Text.rich(TextSpan(children: [
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
        child: Text('New', style: p(9.5, w: FontWeight.w600, color: V.ink)))),
      TextSpan(text: text),
    ]), style: style);
  }
}

// ─── Expandable FAQ row ───────────────────────────────────────────────────────
class _FaqTile extends StatefulWidget {
  final String q, a;
  const _FaqTile({required this.q, required this.a});
  @override State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => setState(() => _open = !_open),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _open ? V.mint : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.q, style: p(13.5, w: FontWeight.w600, color: V.ink, h: 1.4))),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add_rounded, size: 20, color: V.deep)),
        ]),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.a, style: p(13, color: V.ink.withValues(alpha: 0.7), h: 1.55))),
        ),
      ]),
    ),
  );
}
