import 'package:flutter/material.dart';
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
  String _sort = 'recommended';
  static const _sortLabels = {'recommended': 'Recommended', 'price_asc': 'Price: low to high', 'price_desc': 'Price: high to low'};

  static String _cycleLabel(_Cycle c) => switch (c) { _Cycle.all => 'All', _Cycle.oneTime => 'One-time', _Cycle.monthly => 'Monthly', _Cycle.annually => 'Annual' };

  Future<void> _openFilters() async {
    final res = await showFilterSheet(context,
      title: 'Filter plans',
      sections: [
        VFilterSection(title: 'Plan type', defaultValue: 'all', options: [
          VFilterOption('all', 'All', icon: Icons.apps_rounded),
          VFilterOption('oneTime', 'One-time', icon: Icons.bolt_outlined),
          VFilterOption('monthly', 'Monthly', icon: Icons.event_repeat_outlined),
          VFilterOption('annually', 'Annual', icon: Icons.calendar_month_outlined),
        ]),
        VFilterSection(title: 'Sort by', defaultValue: 'recommended', tiles: false, options: [
          for (final e in _sortLabels.entries) VFilterOption(e.key, e.value),
        ]),
      ],
      current: [_filter.name, _sort],
    );
    if (res == null || !mounted) return;
    setState(() { _filter = _Cycle.values.byName(res[0]); _sort = res[1]; });
  }

  Widget _darkChip(String label, VoidCallback onClear) => GestureDetector(
    onTap: onClear,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: p(12, w: FontWeight.w600, color: Colors.white)),
        const SizedBox(width: 4),
        const Icon(Icons.close_rounded, size: 14, color: Colors.white),
      ]),
    ),
  );

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
    final l = _filter == _Cycle.all ? [..._plans] : _plans.where((p) => _cycleOf(asMap(p)) == _filter).toList();
    if (_sort == 'price_asc') l.sort((a, b) => asDouble(asMap(a)['price']).compareTo(asDouble(asMap(b)['price'])));
    if (_sort == 'price_desc') l.sort((a, b) => asDouble(asMap(b)['price']).compareTo(asDouble(asMap(a)['price'])));
    return l;
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
            style: p(12.5, color: Colors.white.withValues(alpha: 0.85), h: 1.45)),
          const SizedBox(height: 18),
          Row(children: [
            if (_filter != _Cycle.all) _darkChip(_cycleLabel(_filter), () => setState(() => _filter = _Cycle.all)),
            if (_sort != 'recommended') ...[
              const SizedBox(width: 8),
              _darkChip(_sortLabels[_sort]!, () => setState(() => _sort = 'recommended')),
            ],
            const Spacer(),
            VFilterButton(active: _filter != _Cycle.all || _sort != 'recommended', onTap: _openFilters),
          ]),
        ]))),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: V.leaf)))
        else if (list.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: GEmpty(title: 'No plans here', sub: 'Nothing matches this filter right now.', icon: Icons.spa_outlined,
            action: _filter == _Cycle.all ? null : GBtn(label: 'Show all plans', onTap: () => setState(() => _filter = _Cycle.all), w: 220, h: 48)))
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
              ),
              childCount: list.length,
            )),
          ),
      ]),
    );
  }
}
