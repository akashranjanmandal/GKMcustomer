import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override State<PlansScreen> createState() => _PlansState();
}

class _PlansState extends State<PlansScreen> {
  final _api = Api();
  List<dynamic> _plans = [];
  bool _loading = true;

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

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: GHeader(pb: 16, child: Row(children: [
          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20)),
          const SizedBox(width: 8),
          Text('Subscription Plans', style: p(20, w: FontWeight.w800, color: Colors.white)),
        ]))),
        if (_loading) 
          SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: C.forest)))
        else if (_plans.isEmpty)
          const SliverFillRemaining(child: GEmpty(title: 'No plans found', sub: 'Please check back later', icon: Icons.spa_outlined))
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
               final pl = _plans[i];
               final isSub = asStr(pl['plan_type']) == 'subscription';
               return Container(
                 margin: const EdgeInsets.only(bottom: 16),
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: isSub ? C.forest : Colors.white,
                   borderRadius: BorderRadius.circular(24),
                   border: Border.all(color: Colors.black.withOpacity(0.08)),
                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                 ),
                 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (isSub ? Colors.white : C.forest).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isSub ? Icons.repeat : Icons.spa, color: isSub ? Colors.white : C.forest)),
                      const Spacer(),
                      Text('₹${asDouble(pl['price']).toStringAsFixed(0)}', style: p(24, w: FontWeight.w900, color: isSub ? Colors.white : C.forest)),
                      Text(isSub ? '/mo' : '/visit', style: p(14, color: isSub ? Colors.white70 : Colors.black45)),
                    ]),
                    const SizedBox(height: 16),
                    Text(asStr(pl['name']), style: p(20, w: FontWeight.w800, color: isSub ? Colors.white : Colors.black)),
                    const SizedBox(height: 8),
                    Text(isSub ? '${pl['visits_per_month']} maintenance visits per month' : 'One-time professional care visit', style: p(14, color: isSub ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 24),
                    GBtn(label: 'Select Plan', onTap: () => Navigator.pushNamed(ctx, '/book', arguments: asInt(pl['id'])), bg: isSub ? Colors.white : C.forest, labelColor: isSub ? C.forest : Colors.white),
                 ]),
               ).animate().fadeIn(delay: Duration(milliseconds: i * 100)).slideY(begin: 0.1, end: 0);
            }, childCount: _plans.length)),
          ),
      ]),
    );
  }
}
