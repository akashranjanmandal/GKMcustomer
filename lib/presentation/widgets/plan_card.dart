import 'package:flutter/material.dart';
import '../../data/services/api.dart';
import '../theme/theme.dart';
import 'widgets.dart';

// Care-plan card used on Home (compact, fixed height) and the Plans page
// (full, shows every feature). The best-value plan is set on a deep-green
// panel so it stands out; the rest are light glass.
class GPlanCard extends StatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onSelect;
  final bool compact;
  const GPlanCard({super.key, required this.plan, required this.onSelect, this.compact = false});
  @override
  State<GPlanCard> createState() => _GPlanCardState();
}

class _GPlanCardState extends State<GPlanCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext ctx) {
    final plan = widget.plan;
    final compact = widget.compact;
    final best = asBool(plan['is_best_value']);
    final isSub = asStr(plan['plan_type']) == 'subscription';
    final name = asStr(plan['name']);
    final tagline = asStr(plan['tagline']).isNotEmpty
        ? asStr(plan['tagline'])
        : asStr(plan['plan_summary'], isSub ? 'Regular care for your garden' : 'A single expert visit');
    final price = asDouble(plan['price']);
    final priceSub = asStr(plan['price_subtitle']).isNotEmpty ? asStr(plan['price_subtitle']) : (isSub ? 'per month' : 'per visit');
    final visits = asInt(plan['visits_per_month']);
    final plants = asInt(plan['max_plants']);
    final features = asList(plan['features']).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    final cta = asStr(plan['button_text']).isNotEmpty ? asStr(plan['button_text']) : 'Choose plan';

    const limit = 4;
    final shown = compact ? features.take(3).toList() : (_showAll ? features : features.take(limit).toList());
    final hidden = features.length - shown.length;

    final fg = best ? Colors.white : V.ink;
    final muted = best ? Colors.white.withValues(alpha: 0.85) : V.fog;
    final line = best ? Colors.white.withValues(alpha: 0.12) : V.ink.withValues(alpha: 0.08);

    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: vx(21, w: FontWeight.w600, color: fg, ls: -0.3))),
        if (best) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
            child: Text('Best value', style: vx(10.5, w: FontWeight.w600, color: V.ink)),
          ),
        ],
      ]),
      const SizedBox(height: 4),
      Text(tagline, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis,
          style: p(12.5, color: muted, h: 1.4)),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${_fmt(price)}', style: vx(34, w: FontWeight.w600, color: fg, ls: -1, h: 1)),
        const SizedBox(width: 6),
        Flexible(child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(priceSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(12, color: muted)),
        )),
      ]),
      if (visits > 0 || plants > 0) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (visits > 0) _stat(Icons.calendar_today_outlined, '$visits visit${visits == 1 ? '' : 's'}${isSub ? ' / month' : ''}', best),
          if (plants > 0) _stat(Icons.local_florist_outlined, 'Up to $plants plants', best),
        ]),
      ],
      const SizedBox(height: 16),
      Container(height: 1, color: line),
      const SizedBox(height: 14),
      for (final f in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.check_rounded, size: 16, color: best ? V.lime : V.leaf),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(f, maxLines: compact ? 1 : 3, overflow: TextOverflow.ellipsis,
                style: p(13, color: best ? Colors.white.withValues(alpha: 0.85) : V.ink, h: 1.35))),
          ]),
        ),
      if (hidden > 0)
        GestureDetector(
          onTap: compact ? widget.onSelect : () => setState(() => _showAll = true),
          child: Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 6),
            child: Text('+ $hidden more', style: p(12.5, w: FontWeight.w600, color: best ? V.lime : V.leaf)),
          ),
        ),
      if (compact) const Spacer() else const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: widget.onSelect,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: best ? V.lime : V.ink,
            foregroundColor: best ? V.ink : Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          ),
          child: Text(cta, style: vx(14.5, w: FontWeight.w600, color: best ? V.ink : Colors.white)),
        ),
      ),
    ]);

    const pad = EdgeInsets.fromLTRB(20, 20, 20, 18);
    return GestureDetector(
      onTap: widget.onSelect,
      child: best
          ? VPod(radius: 26, padding: pad, child: body)
          : GGlass(
              radius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.88), V.mint.withValues(alpha: 0.55)],
              ),
              padding: pad,
              child: body,
            ),
    );
  }

  Widget _stat(IconData icon, String text, bool dark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.08) : V.mint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: dark ? Colors.white70 : V.deep),
          const SizedBox(width: 6),
          Text(text, style: p(12, w: FontWeight.w500, color: dark ? Colors.white : V.deep)),
        ]),
      );

  // 3999 → 3,999 (Indian grouping for larger values)
  static String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }
}
