import 'package:flutter/material.dart';
import '../../data/services/api.dart';
import '../theme/theme.dart';

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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: C.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ServiceDetailsSheet(service: asMap(service)),
  );
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
      initialChildSize: 0.78, maxChildSize: 0.95, minChildSize: 0.45,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 16),
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [C.forest3, C.forest],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(serviceIconFor(asStr(service['slug'])), size: 21, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: p(16, w: FontWeight.w800, color: C.t1, h: 1.25))),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded, size: 17, color: C.t3))),
          ]),
        ),
        const SizedBox(height: 14),
        const Divider(),
        // ── Scrollable body ─────────────────────────────────────────────
        Expanded(child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (overview.isNotEmpty) ...[
              Text(overview, style: p(13.5, color: C.t3, h: 1.6)),
              const SizedBox(height: 22),
            ],
            if (includes.isNotEmpty) ...[
              _secLabel("WHAT'S INCLUDED"),
              const SizedBox(height: 12),
              ...includes.map((s) => _bulletRow(s,
                icon: Icons.check_circle_rounded, iconColor: C.green,
                style: p(13, w: FontWeight.w500, color: C.t2, h: 1.45))),
              const SizedBox(height: 14),
            ],
            if (excludes.isNotEmpty) ...[
              _secLabel('NOT INCLUDED'),
              const SizedBox(height: 12),
              ...excludes.map((s) => _bulletRow(s,
                icon: Icons.close_rounded, iconColor: C.t4,
                style: p(13, color: C.t3, h: 1.45))),
              const SizedBox(height: 14),
            ],
            if (steps.isNotEmpty) ...[
              _secLabel("HOW IT'S DONE"),
              const SizedBox(height: 12),
              ...List.generate(steps.length, (i) => _stepRow(i + 1, steps[i])),
              const SizedBox(height: 14),
            ],
            if (faqs.isNotEmpty) ...[
              _secLabel('FAQs'),
              const SizedBox(height: 12),
              ...faqs.map((f) => _FaqTile(q: asStr(f['q']), a: asStr(f['a']))),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _secLabel(String s) => Row(children: [
    Container(width: 3, height: 13,
      decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(99))),
    const SizedBox(width: 8),
    Text(s, style: p(11, w: FontWeight.w800, color: C.t3, ls: 1)),
  ]);

  Widget _bulletRow(String raw, {required IconData icon, required Color iconColor, required TextStyle style}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 10),
        Expanded(child: _lineText(raw, style)),
      ]),
    );

  Widget _stepRow(int n, String raw) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24,
        decoration: BoxDecoration(color: C.forest.withOpacity(0.08), shape: BoxShape.circle),
        child: Center(child: Text('$n', style: p(11, w: FontWeight.w800, color: C.forest)))),
      const SizedBox(width: 10),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 3),
        child: _lineText(raw, p(13, w: FontWeight.w500, color: C.t2, h: 1.45)))),
    ]),
  );

  // Renders a content line; a "NEW:" prefix becomes a small amber chip.
  Widget _lineText(String raw, TextStyle style) {
    var text = raw.trim();
    final isNew = text.toUpperCase().startsWith('NEW:');
    if (!isNew) return Text(text, style: style);
    text = text.substring(4).trim();
    return Text.rich(TextSpan(children: [
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: C.amber.withOpacity(0.13),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: C.amber.withOpacity(0.35))),
        child: Text('NEW', style: p(8.5, w: FontWeight.w800, color: C.amber, ls: 0.6)))),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _open ? C.subtle.withOpacity(0.6) : C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _open ? C.border : C.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.q,
            style: p(13, w: FontWeight.w600, color: C.t1, h: 1.4))),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: C.t3)),
        ]),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.a, style: p(12.5, color: C.t3, h: 1.55))),
        ),
      ]),
    ),
  );
}
