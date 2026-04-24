import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/location_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/location_picker_sheet.dart';
import 'bookings_screen.dart';

class BookScreen extends StatefulWidget {
  final int? planId;
  const BookScreen({super.key, this.planId});
  @override State<BookScreen> createState() => _BookState();
}

class _BookState extends State<BookScreen> {
  final _api = Api();
  bool _loading = true, _submitting = false;

  List<dynamic> _plans = [], _addons = [];
  PickedLocation? _picked;
  Map<String, dynamic>? get _zone => _picked?.zone;

  final _notesCtrl = TextEditingController();
  int? _planId;
  int _plantCount = 5;
  String _date = '', _time = '09:00';
  final Set<int> _selectedAddons = {};
  bool _autoRenew = true;

  static const _slots = ['08:00','09:00','10:00','11:00','14:00','15:00','16:00'];

  bool get _isSub => asStr(_selectedPlan?['plan_type']) == 'subscription';
  bool get _planPreSelected => widget.planId != null;

  List<String> get _labels {
    if (_planPreSelected) {
      return _isSub ? ['Location', 'Checkout'] : ['Location', 'Plants', 'Add-ons', 'Schedule', 'Checkout'];
    } else {
      return _isSub ? ['Location', 'Plan', 'Checkout'] : ['Location', 'Plan', 'Plants', 'Add-ons', 'Schedule', 'Checkout'];
    }
  }

  int get _lastStep => _labels.length - 1;
  int _stepIdx = 0;

  Map<String, dynamic>? get _selectedPlan {
    final pl = _plans.where((e) => asInt(e['id']) == _planId).firstOrNull;
    return pl == null ? null : Map<String, dynamic>.from(pl as Map);
  }

  List<dynamic> get _subPlans => _plans.where((p) => asStr(p['plan_type']) == 'subscription').toList();
  List<dynamic> get _odPlans  => _plans.where((p) => asStr(p['plan_type']) != 'subscription').toList();

  // Geofence-based price for a given on-demand plan (uses zone pricing when location is set)
  double _odPrice(Map<String, dynamic> plan) {
    if (asStr(plan['plan_type']) == 'subscription') return asDouble(plan['price']);
    if (_picked != null && _zone != null && _zone!.containsKey('base_price')) {
      final base = asDouble(_zone!['base_price']);
      if (base > 0) {
        final surge = asDouble(_zone!['surge_multiplier']) > 0 ? asDouble(_zone!['surge_multiplier']) : 1.0;
        return base * surge;
      }
    }
    return asDouble(plan['price']);
  }

  double get _total {
    double t = asDouble(_selectedPlan?['price']);
    
    // If it's an on-demand visit, use geofence specific pricing if available
    if (!_isSub && _picked != null && _zone != null && _zone!.containsKey('base_price')) {
      final base = asDouble(_zone!['base_price']);
      if (base > 0) {
        final ppp = asDouble(_zone!['price_per_plant']);
        final min = asInt(_zone!['min_plants']);
        final surge = asDouble(_zone!['surge_multiplier']) > 0 ? asDouble(_zone!['surge_multiplier']) : 1.0;
        
        t = base;
        if (_plantCount > min) t += (_plantCount - min) * ppp;
        t *= surge;
      }
    }

    for (final id in _selectedAddons) {
      final a = _addons.where((x) => asInt(x['id']) == id).firstOrNull;
      t += asDouble(a?['price']);
    }
    return t;
  }

  bool _zoneChecking = false;

  @override
  void initState() {
    super.initState();
    _planId = widget.planId;
    _date = _tomorrow();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = context.read<LocationProvider>().location;
      if (saved != null && mounted) {
        setState(() => _picked = saved);
        // If saved location has no zone, re-check serviceability immediately
        if (saved.zone.isEmpty || asInt(saved.zone['id']) == 0) {
          _recheckZone(saved.lat, saved.lng);
        }
      }
    });
  }

  Future<void> _recheckZone(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _zoneChecking = true);
    try {
      final sRes = await _api.checkServiceability(lat, lng);
      final data = asMap(sRes);
      final zone = asMap(data['zone']);
      if (mounted && zone.isNotEmpty && _picked != null) {
        final updated = _picked!.copyWith(zone: zone);
        setState(() { _picked = updated; _zoneChecking = false; });
        // Persist the resolved zone back to provider
        context.read<LocationProvider>().updateZoneForCurrent(zone);
      } else {
        if (mounted) setState(() => _zoneChecking = false);
      }
    } catch (_) {
      if (mounted) setState(() => _zoneChecking = false);
    }
  }

  @override void dispose() { _notesCtrl.dispose(); super.dispose(); }

  String _cleanAddr(String s) {
    final reg = RegExp(r'-?\d{1,3}\.\d{4,}');
    if (reg.allMatches(s).length >= 2) return 'Service Location';
    return s.isEmpty ? '—' : s;
  }

  String _tomorrow() {
    final d = DateTime.now().add(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([ _api.getPlans().catchError((_) => null), _api.getAddons().catchError((_) => null) ]);
      if (!mounted) return;
      setState(() {
        _plans  = asList(r[0]);
        _addons = asList(r[1]);
        if (_planId == null && _plans.isNotEmpty) _planId = asInt(_plans.first['id']);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _openPicker() async {
    final lp = context.read<LocationProvider>();
    PickedLocation? result;
    
    if (lp.locations.isEmpty) {
      result = await showLocationPicker(context);
    } else {
      result = await showSavedLocations(context);
    }

    if (result != null && mounted) {
      // lp.save(result); // Already handled in showSavedLocations for new ones
      setState(() => _picked = result);
    }
  }

  Future<void> _submit() async {
    if (_picked == null || _selectedPlan == null) return;
    setState(() => _submitting = true);
    final zoneId = _zone != null && asInt(_zone!['id']) > 0 ? asInt(_zone!['id']) : 0;

    try {
      if (zoneId == 0) throw ApiError('Please select a serviceable location first.', 404);

      final addonsPayload = _selectedAddons.map((id) => {'addon_id': id, 'quantity': 1}).toList();
      final totalAmount = _total;

      if (_isSub) {
        await _api.createSubscription(
          planId: _planId!,
          zoneId: zoneId,
          geofenceId: _picked?.geofenceId,
          serviceAddress: _picked!.address,
          lat: _picked!.lat, lng: _picked!.lng,
          flatNo: _picked!.flatNo, building: _picked!.building,
          area: _picked!.area, landmark: _picked!.landmark,
          city: _picked!.city, state: _picked!.state, pincode: _picked!.pincode,
          plantCount: null,
          autoRenew: _autoRenew,
          addons: addonsPayload,
          totalAmount: totalAmount,
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        showMsg(context, 'Subscription created! Schedule visits from My Profile.', ok: true);
        await Future.delayed(1200.ms);
        if (mounted) { Navigator.pop(context, true); Navigator.pushNamed(context, '/subscriptions'); }
      } else {
        await _api.createBooking(
          zoneId: zoneId,
          geofenceId: _picked?.geofenceId,
          scheduledDate: _date, scheduledTime: _time,
          serviceAddress: _picked!.address,
          lat: _picked!.lat, lng: _picked!.lng,
          flatNo: _picked!.flatNo, building: _picked!.building,
          area: _picked!.area, landmark: _picked!.landmark,
          city: _picked!.city, state: _picked!.state, pincode: _picked!.pincode,
          plantCount: _plantCount,
          customerNotes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          addons: addonsPayload,
          totalAmount: totalAmount,
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        showMsg(context, 'Booking confirmed!', ok: true);
        await Future.delayed(800.ms);
        if (mounted) {
          BookingsScreen.needsReload = true;
          showMsg(context, 'Booking successful!', ok: true);
          Navigator.pushNamedAndRemoveUntil(context, '/bookings', (r) => r.isFirst);
        }
      }
    } on ApiError catch (e) {
      setState(() => _submitting = false);
      if (mounted) showMsg(context, e.message, err: true);
    }
  }

  bool _canNext() {
    switch (_currentStepKey) {
      case 'Location': return !_zoneChecking && _picked != null && asInt(_picked?.zone['id']) > 0;
      case 'Plan':     return _planId != null;
      case 'Schedule': return _isSub || _date.isNotEmpty;
      default:         return true;
    }
  }

  String get _currentStepKey => _labels[_stepIdx];
  void _goNext() { if (_canNext()) setState(() => _stepIdx++); }

  @override
  Widget build(BuildContext ctx) {
    final labels = _labels;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _buildHeader(ctx, labels),
        Expanded(child: _buildBody()),
        _buildBottomNav(ctx),
      ]),
    );
  }

  Widget _buildHeader(BuildContext ctx, List<String> labels) => Container(
    padding: EdgeInsets.fromLTRB(24, MediaQuery.of(ctx).padding.top + 10, 24, 20),
    decoration: const BoxDecoration(color: C.forest),
    child: Column(children: [
      Row(children: [
        GestureDetector(onTap: () => _stepIdx == 0 ? Navigator.pop(ctx) : setState(() => _stepIdx--), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: Colors.white))),
        const SizedBox(width: 16),
        Expanded(child: Text(_isSub ? 'Subscription' : 'One-Time Visit', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text('${_stepIdx + 1}/${labels.length}', style: p(12, w: FontWeight.w800, color: Colors.white))),
      ]),
      const SizedBox(height: 24),
      Row(children: List.generate(labels.length, (i) => Expanded(child: AnimatedContainer(duration: 300.ms, height: 4, margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6), decoration: BoxDecoration(color: i <= _stepIdx ? C.gold : Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(height: 12),
      Row(children: [
         const Icon(Icons.check_circle_outline_rounded, size: 14, color: C.gold),
         const SizedBox(width: 6),
         Text(labels[_stepIdx], style: p(12, w: FontWeight.w700, color: C.gold, ls: 0.5)),
      ]),
    ]),
  );

  Widget _buildBody() {
    if (_loading && _stepIdx >= 1) return const Center(child: CircularProgressIndicator(color: C.forest));
    return AnimatedSwitcher(duration: 300.ms, child: _buildStep());
  }

  Widget _buildBottomNav(BuildContext ctx) => Container(
    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 16),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))]),
    child: _stepIdx < _lastStep
      ? GBtn(label: 'Continue', icon: Icons.arrow_forward_rounded, onTap: _canNext() ? _goNext : null, bg: C.forest)
      : GBtn(label: _isSub ? 'Subscribe — ₹${_total.toStringAsFixed(0)}/mo' : 'Confirm Booking — ₹${_total.toStringAsFixed(0)}', bg: C.forest, loading: _submitting, onTap: _submit),
  );

  Widget _buildStep() {
    switch (_currentStepKey) {
      case 'Location': return _stepLocation();
      case 'Plan':     return _stepPlan();
      case 'Plants':   return _stepPlants();
      case 'Add-ons':  return _stepAddons();
      case 'Schedule': return _stepSchedule();
      case 'Checkout': return _stepCheckout();
      default:         return const SizedBox();
    }
  }

  Widget _stepLocation() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Service Location', style: p(18, w: FontWeight.w800)),
    const SizedBox(height: 16),
    if (_picked != null) Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: C.forest.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: C.forest.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.forest.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.location_on_rounded, color: C.forest, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Location Set', style: p(14, w: FontWeight.w800, color: C.forest)),
            Text(_picked!.fullAddress, style: p(11, color: C.forest.withOpacity(0.7), h: 1.4)),
          ])),
          GestureDetector(onTap: _openPicker, child: Text('Change', style: p(13, w: FontWeight.w800, color: C.forest))),
        ]),
        const Divider(height: 24),
        if (_zoneChecking)
          Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.forest)),
            const SizedBox(width: 12),
            Text('Checking serviceability...', style: p(12, color: C.t3)),
          ])
        else if (asInt(_picked!.zone['id']) > 0)
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: C.green, size: 16),
            const SizedBox(width: 8),
            Text('Serviceable · ${asStr(_picked!.zone['name'])}', style: p(12, w: FontWeight.w700, color: C.green)),
          ])
        else
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('This area may not be serviceable. Try changing location.', style: p(12, color: Colors.orange))),
          ]),
      ]),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0)
    else Column(children: [
      const SizedBox(height: 40),
      const Icon(Icons.add_location_alt_rounded, size: 80, color: C.forest),
      const SizedBox(height: 24),
      Text('Where should we come?', style: p(20, w: FontWeight.w800), textAlign: TextAlign.center),
      Text('Set your service address to continue', style: p(14, color: Colors.black45), textAlign: TextAlign.center),
      const SizedBox(height: 48),
      GBtn(label: 'Select Service Location', bg: C.forest, onTap: _openPicker),
    ]),
  ]));

  Widget _stepPlan() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_subPlans.isNotEmpty) ...[
      GSec('Subscription Plans'),
      const SizedBox(height: 12),
      ..._subPlans.map((pl) => _PlanItem(plan: pl, sel: _planId == asInt(pl['id']), onTap: () => setState(() => _planId = asInt(pl['id'])), displayPrice: _odPrice(Map<String, dynamic>.from(pl as Map)))),
    ],
    if (_odPlans.isNotEmpty) ...[
      if (_subPlans.isNotEmpty) const SizedBox(height: 32),
      GSec('One-Time Visit'),
      const SizedBox(height: 12),
      ..._odPlans.map((pl) => _PlanItem(plan: pl, sel: _planId == asInt(pl['id']), onTap: () => setState(() => _planId = asInt(pl['id'])), displayPrice: _odPrice(Map<String, dynamic>.from(pl as Map)))),
    ],
  ]));

  Widget _stepPlants() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text('How many plants?', style: p(24, w: FontWeight.w900, color: Colors.black)),
    const SizedBox(height: 40),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _CounterBtn(icon: Icons.remove, enabled: _plantCount > 1, onTap: () => setState(() => _plantCount--)),
      SizedBox(width: 140, child: Center(child: Text('$_plantCount', style: GoogleFonts.poppins(fontSize: 80, fontWeight: FontWeight.w900, color: C.forest)))),
      _CounterBtn(icon: Icons.add, enabled: _plantCount < 200, onTap: () => setState(() => _plantCount++)),
    ]),
    const SizedBox(height: 16),
    Text('Up to 200 plants supported', style: p(13, color: Colors.black38, w: FontWeight.w600)),
  ]));

  Widget _stepAddons() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GSec('Optional Add-ons'),
    const SizedBox(height: 16),
    if (_addons.isEmpty) const GEmpty(title: 'No add-ons', sub: 'Continue to final step', icon: Icons.add_box_outlined)
    else ..._addons.map((a) {
      final id = asInt(a['id']); final sel = _selectedAddons.contains(id);
      return GestureDetector(
        onTap: () => setState(() => sel ? _selectedAddons.remove(id) : _selectedAddons.add(id)),
        child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: sel ? C.forest : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? C.forest : Colors.black.withOpacity(0.08))), child: Row(children: [
          Icon(Icons.add_circle_outline_rounded, color: sel ? Colors.white : C.forest),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(asStr(a['name']), style: p(14, w: FontWeight.w700, color: sel ? Colors.white : Colors.black)), Text('Best for extra care', style: p(11, color: sel ? Colors.white70 : Colors.black38))])),
          Text('₹${asDouble(a['price']).toStringAsFixed(0)}', style: p(15, w: FontWeight.w800, color: sel ? C.gold : C.forest)),
        ])),
      );
    }),
  ]));

  Widget _stepSchedule() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GSec('Preferred Date'),
    const SizedBox(height: 16),
    SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 14, itemBuilder: (_, i) {
      final d = DateTime.now().add(Duration(days: i + 1));
      final ds = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}';
      final sel = _date == ds;
      return GestureDetector(
        onTap: () => setState(() => _date = ds),
        child: AnimatedContainer(duration: 200.ms, width: 70, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: sel ? C.forest : const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(18), border: Border.all(color: sel ? C.forest : Colors.transparent)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(['MON','TUE','WED','THU','FRI','SAT','SUN'][d.weekday-1], style: p(10, w: FontWeight.w800, color: sel ? Colors.white70 : Colors.black38)),
          const SizedBox(height: 4),
          Text('${d.day}', style: p(20, w: FontWeight.w900, color: sel ? Colors.white : Colors.black)),
        ])),
      );
    })),
    const SizedBox(height: 32),
    GSec('Preferred Time'),
    const SizedBox(height: 16),
    Wrap(spacing: 12, runSpacing: 12, children: _slots.map((t) {
      final sel = _time == t;
      return GestureDetector(
        onTap: () => setState(() => _time = t),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: sel ? C.forest : const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? C.forest : Colors.transparent)), child: Text(t, style: p(14, w: FontWeight.w700, color: sel ? Colors.white : Colors.black54))),
      );
    }).toList()),
    const SizedBox(height: 32),
    GSec('Instructions'),
    const SizedBox(height: 12),
    TextField(controller: _notesCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'Any special requests?', filled: true, fillColor: const Color(0xFFF9F9F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
  ]));

  Widget _stepCheckout() {
    final prov = context.read<LocationProvider>();
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GSec('Booking Overview'),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(32)), child: Column(children: [
        _RowInfo(label: 'Location', value: prov.label),
        _RowInfo(label: 'Address', value: _cleanAddr(prov.fullAddress), isBold: false),
        _RowInfo(label: 'Plan', value: asStr(_selectedPlan?['name'])),
        if (!_isSub) _RowInfo(label: 'Plants', value: '$_plantCount plants'),
        if (!_isSub) ...[ _RowInfo(label: 'Date', value: _date), _RowInfo(label: 'Time', value: _time) ],
        if (!_isSub && _selectedAddons.isNotEmpty) _RowInfo(label: 'Add-ons', value: _selectedAddons.length.toString()),
        const Divider(height: 48),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Amount', style: p(16, w: FontWeight.w700)),
          Text('₹${_total.toStringAsFixed(0)}', style: p(24, w: FontWeight.w900, color: C.green)),
        ]),
      ])),
      const SizedBox(height: 40),
    ]));
  }
}

class _PlanItem extends StatelessWidget {
  final Map<String, dynamic> plan; final bool sel; final VoidCallback onTap;
  final double? displayPrice;
  const _PlanItem({required this.plan, required this.sel, required this.onTap, this.displayPrice});
  @override
  Widget build(BuildContext ctx) {
    final isSub = asStr(plan['plan_type']) == 'subscription';
    final shownPrice = displayPrice ?? asDouble(plan['price']);
    return GestureDetector(
      onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: sel ? C.forest : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: sel ? C.forest : Colors.black.withOpacity(0.08)), boxShadow: [if(sel) BoxShadow(color: C.forest.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]), child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (sel ? Colors.white : C.forest).withOpacity(0.12), borderRadius: BorderRadius.circular(16)), child: Icon(isSub ? Icons.repeat_rounded : Icons.bolt_rounded, color: sel ? Colors.white : C.forest)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(asStr(plan['name']), style: p(16, w: FontWeight.w800, color: sel ? Colors.white : Colors.black)), Text('Best for basic maintenance', style: p(12, color: sel ? Colors.white60 : Colors.black38))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₹${shownPrice.toStringAsFixed(0)}', style: p(18, w: FontWeight.w900, color: sel ? C.gold : C.forest)), Text(isSub ? '/mo' : '/visit', style: p(10, color: sel ? Colors.white54 : Colors.black26))]),
      ])),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon; final bool enabled; final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(onTap: enabled ? onTap : null, child: Container(width: 56, height: 56, decoration: BoxDecoration(color: enabled ? C.forest : Colors.black12, shape: BoxShape.circle), child: Icon(icon, color: Colors.white)));
}

class _RowInfo extends StatelessWidget {
  final String label, value; final bool isBold;
  const _RowInfo({required this.label, required this.value, this.isBold = true});
  @override
  Widget build(BuildContext ctx) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(label, style: p(13, color: Colors.black26, w: FontWeight.w600))), Expanded(child: Text(value, style: p(13, w: isBold ? FontWeight.w800 : FontWeight.w500), textAlign: TextAlign.right))]));
}
