import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
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
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Subscription Plans', style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text('Choose the care schedule that fits you', style: p(12.5, color: Colors.white60)),
            ])),
          ]),
          const SizedBox(height: 22),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
              _FilterChip(label: 'All', sel: _filter == _Cycle.all, onTap: () => setState(() => _filter = _Cycle.all)),
              const SizedBox(width: 8),
              _FilterChip(label: 'One-time', sel: _filter == _Cycle.oneTime, onTap: () => setState(() => _filter = _Cycle.oneTime)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Monthly', sel: _filter == _Cycle.monthly, onTap: () => setState(() => _filter = _Cycle.monthly)),
              const SizedBox(width: 8),
              _FilterChip(label: 'Annually', sel: _filter == _Cycle.annually, onTap: () => setState(() => _filter = _Cycle.annually)),
            ]),
          ),
        ]))),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: C.forest)))
        else if (_filtered.isEmpty)
          const SliverFillRemaining(child: GEmpty(title: 'No plans found', sub: 'Try a different filter or check back later', icon: Icons.spa_outlined))
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 28, bottom: 32),
              // Re-keying on the filter restarts the carousel at its first card
              // whenever the filtered plan list changes.
              child: _PlansCarousel(key: ValueKey(_filter), plans: _filtered),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: sel ? C.gold : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: sel ? C.gold : Colors.white.withOpacity(0.18)),
        boxShadow: sel ? [BoxShadow(color: C.gold.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? const Color(0xFF1A0F00) : Colors.white70)),
    ),
  );
}

// Same deep metallic gradient system as Home's "Best Value Plans" carousel.
const _tiers = [
  _Tier('BRONZE',   Color(0xFFE8A05C), [Color(0xFF4A3122), Color(0xFF2A1B12)]),
  _Tier('SILVER',   Color(0xFFD7E0E6), [Color(0xFF394149), Color(0xFF20262C)]),
  _Tier('GOLD',     Color(0xFFF2D78B), [Color(0xFF4A3D14), Color(0xFF2A2208)]),
  _Tier('PLATINUM', Color(0xFFAFD4F5), [Color(0xFF1E3A52), Color(0xFF0F2233)]),
  _Tier('DIAMOND',  Color(0xFFE6B8F0), [Color(0xFF3D2148), Color(0xFF24132B)]),
];
_Tier _tierFor(int index) => _tiers[index % _tiers.length];
IconData _tierIcon(int index) {
  switch (index % _tiers.length) {
    case 0: return Icons.workspace_premium_rounded;
    case 1: return Icons.military_tech_rounded;
    case 2: return Icons.star_rounded;
    case 3: return Icons.diamond_rounded;
    default: return Icons.auto_awesome_rounded;
  }
}

class _Tier {
  final String label;
  final Color accent;
  final List<Color> gradient;
  const _Tier(this.label, this.accent, this.gradient);
}

// ─── Hotstar-style plans carousel — same visual system as Home, bigger cards ──
// The PageView box height is content-driven: each card is measured off-screen
// once (via GlobalKey), and the box animates to the active card's real height
// instead of using one fixed height for every card.
class _PlansCarousel extends StatefulWidget {
  final List<dynamic> plans;
  const _PlansCarousel({super.key, required this.plans});
  @override State<_PlansCarousel> createState() => _PlansCarouselState();
}

class _PlansCarouselState extends State<_PlansCarousel> {
  late final PageController _pageCtrl;
  int _current = 0;
  final _heights = <int, double>{};
  late final List<GlobalKey> _measureKeys;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.90, initialPage: 0);
    _measureKeys = List.generate(widget.plans.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAll());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _measureAll() {
    if (!mounted) return;
    var changed = false;
    for (var i = 0; i < _measureKeys.length; i++) {
      final h = _measureKeys[i].currentContext?.size?.height;
      if (h != null && h > 0 && _heights[i] != h) { _heights[i] = h; changed = true; }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plans.isEmpty) return const SizedBox.shrink();
    // Falls back to a sane default until the off-screen measurement pass lands.
    final boxHeight = _heights[_current] ?? 480;
    // The PageView gives each card this exact width (viewportFraction of the
    // full screen) — the off-screen measurement copy must use the identical
    // width, otherwise text/chips wrap differently and the measured height
    // is wrong (too short), which is what was clipping long-content cards.
    final cardWidth = MediaQuery.of(context).size.width * 0.90;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _tierFor(_current).gradient.last, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${_current + 1}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: _tierFor(_current).accent)),
              Text(' / ${widget.plans.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Invisible measurement pass — lays out every card at full natural
        // height (unconstrained) off-screen, at the SAME width the real
        // PageView card gets, so its true content height can be captured
        // via GlobalKey without ever painting or hit-testing it.
        Offstage(
          child: Column(children: List.generate(widget.plans.length, (i) => SizedBox(
            key: _measureKeys[i],
            width: cardWidth,
            child: _PlanCardBody(plan: asMap(widget.plans[i]), index: i, interactive: false),
          ))),
        ),

        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: boxHeight,
          child: PageView.builder(
            controller: _pageCtrl,
            clipBehavior: Clip.none,
            itemCount: widget.plans.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _measureAll();
            },
            itemBuilder: (_, i) {
              final isActive = i == _current;
              return AnimatedScale(
                scale: isActive ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: _PlanCardBody(plan: asMap(widget.plans[i]), index: i, isActive: isActive),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── The card itself — extracted so it can be measured off-screen AND shown ──
class _PlanCardBody extends StatelessWidget {
  final Map<String, dynamic> plan;
  final int index;
  final bool isActive;
  final bool interactive;
  const _PlanCardBody({required this.plan, required this.index, this.isActive = true, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(index);
    final isSub = asStr(plan['plan_type']) == 'subscription';
    final price = asDouble(plan['price']);
    final name = asStr(plan['name']);
    final tagline = asStr(plan['tagline']).isNotEmpty ? asStr(plan['tagline']) : asStr(plan['plan_summary'] ?? (isSub ? 'best care' : 'on-demand visit'));
    final priceSubtitle = asStr(plan['price_subtitle']).isNotEmpty ? asStr(plan['price_subtitle']) : '/ plan';
    final desc = asStr(plan['description']);
    final visits = asInt(plan['visits_per_month']);
    final maxPlants = asInt(plan['max_plants']);
    final isBestValue = asBool(plan['is_best_value']);
    final features = asList(plan['features']).map((e) => e.toString()).toList();
    final buttonText = asStr(plan['button_text']).isNotEmpty ? asStr(plan['button_text']) : 'Select Plan';

    final card = Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: tier.accent.withOpacity(isActive ? 0.40 : 0.14), blurRadius: isActive ? 30 : 14, spreadRadius: isActive ? 1 : 0, offset: const Offset(0, 14)),
          BoxShadow(color: Colors.black.withOpacity(isActive ? 0.25 : 0.10), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tier.gradient)),
          ),
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 230, height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [tier.accent.withOpacity(0.30), tier.accent.withOpacity(0.0)]),
              ),
            ),
          ),
          Positioned(
            top: -25, left: -45,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(width: 70, height: 380, color: Colors.white.withOpacity(0.04)),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: tier.accent.withOpacity(0.22), width: 1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tier.accent.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: tier.accent.withOpacity(0.45), width: 1),
                    ),
                    child: Icon(_tierIcon(index), size: 18, color: tier.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(tagline, style: p(11.5, color: Colors.white54, h: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 8),
                  if (isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: tier.accent, borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bolt_rounded, size: 10, color: tier.gradient.last),
                        const SizedBox(width: 2),
                        Text('BEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: tier.gradient.last, letterSpacing: 0.5)),
                      ]),
                    ),
                ]),

                const SizedBox(height: 16),

                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: tier.accent, height: 1)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(priceSubtitle, style: p(11.5, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ]),

                if (desc.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(desc, style: p(11.5, color: Colors.white60, h: 1.4)),
                ),

                if (visits > 0 || maxPlants > 0) Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(children: [
                    if (visits > 0) _statPill(Icons.event_repeat_rounded, '$visits', 'visits/mo', tier.accent),
                    if (visits > 0 && maxPlants > 0) const SizedBox(width: 8),
                    if (maxPlants > 0) _statPill(Icons.spa_rounded, '$maxPlants', 'plants', tier.accent),
                  ]),
                ),

                if (features.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: features.map((f) => _featureChip(f, tier.accent)).toList(),
                  ),
                ],

                const SizedBox(height: 18),
                GBtn(
                  label: buttonText,
                  onTap: interactive ? () => Navigator.pushNamed(context, '/book', arguments: asInt(plan['id'])) : null,
                  bg: tier.accent,
                  labelColor: tier.gradient.last,
                  h: 46,
                ),
              ],
            ),
          ),
        ]),
      ),
    );

    if (!interactive) return card;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/book', arguments: asInt(plan['id'])),
      child: card,
    );
  }

  Widget _statPill(IconData icon, String value, String label, Color accent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: accent),
      const SizedBox(width: 5),
      Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 3),
        Text(label, style: p(9.5, color: Colors.white54)),
      ],
    ]),
  );

  Widget _featureChip(String text, Color accent) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 200),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withOpacity(0.22), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_rounded, size: 10, color: accent),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: p(10, w: FontWeight.w600, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}
