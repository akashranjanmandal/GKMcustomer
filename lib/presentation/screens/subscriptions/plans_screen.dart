import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/plan_card.dart';
import '../../widgets/widgets.dart';

enum _Cycle { all, oneTime, monthly, annually }

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override State<PlansScreen> createState() => _PlansState();
}

class _PlansState extends State<PlansScreen> {
  final _api = Api();
  List<dynamic> _plans = [];
  bool _loading = true;
  _Cycle _filter = _Cycle.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getPlans();
      if (mounted) setState(() { _plans = asList(r); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  // The backend has no dedicated billing-cycle field — derive it from
  // plan_type + duration_days (30 = monthly, 365 = annual, ondemand = one-time).
  _Cycle _cycleOf(Map<String, dynamic> pl) {
    if (asStr(pl['plan_type']) != 'subscription') return _Cycle.oneTime;
    return asInt(pl['duration_days']) >= 300 ? _Cycle.annually : _Cycle.monthly;
  }

  List<dynamic> get _filtered {
    if (_filter == _Cycle.all) return _plans;
    return _plans.where((p) => _cycleOf(asMap(p)) == _filter).toList();
  }

  @override
  Widget build(BuildContext ctx) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: GHeader(pb: 22, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text('Care plans', style: vx(24, w: FontWeight.w600, color: Colors.white, ls: -0.4))),
          ]),
          const SizedBox(height: 10),
          Text('Pick a one-time visit or a regular schedule. You can change or pause anytime.',
            style: p(12.5, color: Colors.white.withValues(alpha: 0.7), h: 1.45)),
          const SizedBox(height: 18),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
              for (final c in _Cycle.values) ...[
                _FilterChip(
                  label: switch (c) { _Cycle.all => 'All', _Cycle.oneTime => 'One-time', _Cycle.monthly => 'Monthly', _Cycle.annually => 'Annual' },
                  sel: _filter == c,
                  onTap: () => setState(() => _filter = c),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),
        ]))),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: V.leaf)))
        else if (list.isEmpty)
          const SliverFillRemaining(child: GEmpty(title: 'No plans found', sub: 'Try a different filter or check back later', icon: Icons.spa_outlined))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                key: ValueKey('${_filter.name}-$i'),
                padding: const EdgeInsets.only(bottom: 14),
                child: GPlanCard(
                  plan: asMap(list[i]),
                  onSelect: () => Navigator.pushNamed(ctx, '/book', arguments: asInt(asMap(list[i])['id'])),
                ),
              ).animate().fadeIn(delay: (i * 60).ms, duration: 350.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              childCount: list.length,
            )),
          ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: 200.ms,
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: sel ? Colors.white : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: sel ? Colors.white : Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(label, style: p(12.5, w: FontWeight.w600, color: sel ? V.ink : Colors.white70)),
    ),
  );
}
