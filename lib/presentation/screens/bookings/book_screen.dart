import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/location_provider.dart';
import '../../../data/services/ops_status_provider.dart';
import '../../../data/services/razorpay_service.dart';
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
  int _plantCount = 0; // additional plants beyond the plan's coverage (optional)
  String _date = '', _time = '';
  final Set<int> _selectedAddons = {};
  bool _autoRenew = true;

  // ── Coupon state (service bookings / monthly plans) ──────────────────────
  final _couponCtrl = TextEditingController();
  String? _appliedCouponCode;
  double _couponDiscount = 0;
  String? _couponMsg;
  bool _couponBusy = false;
  List<dynamic> _availableCoupons = [];
  bool _couponsLoaded = false; // false until the first /coupons response lands
  String? _couponsLoadedFor; // "scope|subtotal" key the available-coupon list was fetched for
  Timer? _couponsDebounce;

  static const _slots = ['08:00','09:00','10:00','11:00','14:00','15:00','16:00'];
  List<String> _availableSlots = [];
  bool _loadingSlots = false, _slotsLoaded = false, _noGardenersInZone = false, _slotsError = false;
  // Availability per date, so switching back to a date shows its real slots
  // instantly instead of an unloaded (all-open) grid.
  final Map<String, ({List<String> slots, bool noGardeners})> _slotCache = {};

  // Instant booking has been removed from the UI. All on-demand bookings are
  // scheduled — the user picks a date + time. The instant flow (toggle,
  // availability check, instant payload, _ModeCard, getInstantAvailability) is
  // gone; restore from git history to re-enable.
  // final String _mode = 'schedule';
  // Map<String, dynamic>? _instantInfo;
  // bool _checkingInstant = false;

  bool get _isSub => asStr(_selectedPlan?['plan_type']) == 'subscription';
  bool get _planPreSelected => widget.planId != null;

  List<String> get _labels {
    // Add-ons step removed from the flow for now (re-add 'Add-ons' to re-enable).
    if (_planPreSelected) {
      return _isSub ? ['Location', 'Checkout'] : ['Location', 'Plants', 'Schedule', 'Checkout'];
    } else {
      return _isSub ? ['Location', 'Plan', 'Checkout'] : ['Location', 'Plan', 'Plants', 'Schedule', 'Checkout'];
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

  // Pre-GST amount: plan/zone base + extra plants + add-ons. Coupons are
  // validated against this figure.
  double get _baseAmount {
    // Base = zone base price for on-demand, plan price for subscriptions.
    double base = asDouble(_selectedPlan?['price']);
    if (!_isSub && _picked != null && _zone != null && asDouble(_zone!['base_price']) > 0) {
      base = asDouble(_zone!['base_price']);
    }
    // Additional plants are optional, ₹25 each, on top of the plan's free coverage.
    double t = base + (_plantCount * 25);
    for (final id in _selectedAddons) {
      final a = _addons.where((x) => asInt(x['id']) == id).firstOrNull;
      t += asDouble(a?['price']);
    }
    return t;
  }

  double get _gstAmount => _baseAmount * 0.18; // 18% GST
  double get _grossTotal => _baseAmount * 1.18; // GST-inclusive, before coupon

  // Payable total: discount comes off the GST-inclusive amount (matches server).
  double get _total {
    final t = _grossTotal - _couponDiscount;
    return t < 0 ? 0 : t;
  }

  String get _couponScope => _isSub ? 'subscription' : 'booking';

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
        } else {
          _loadInstantInfo();
          _scheduleCouponRefresh(); // zone base price feeds the coupon subtotal
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
        setState(() { _picked = updated; _zoneChecking = false; _slotCache.clear(); _slotsLoaded = false; });
        // Persist the resolved zone back to provider
        context.read<LocationProvider>().updateZoneForCurrent(zone);
        _loadInstantInfo();
        _scheduleCouponRefresh(); // zone base price feeds the coupon subtotal
      } else {
        if (mounted) setState(() => _zoneChecking = false);
      }
    } catch (_) {
      if (mounted) setState(() => _zoneChecking = false);
    }
  }

  @override void dispose() { _couponsDebounce?.cancel(); _notesCtrl.dispose(); _couponCtrl.dispose(); super.dispose(); }

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
      _loadCoupons();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _selectPlan(Map<String, dynamic> pl) {
    final newId = asInt(pl['id']);
    if (newId == _planId) return;
    setState(() { _planId = newId; _clearCoupon(); }); // also refreshes coupons (scope/subtotal may change)
  }

  // ── Coupons ──────────────────────────────────────────────────────────────
  // The server evaluates every coupon against (scope, pre-GST subtotal) and
  // returns eligible-first rows with `eligible`, `reason` and the exact
  // `discount_amount`. Re-fetched whenever either input changes.
  String get _couponsKey => '$_couponScope|${_baseAmount.toStringAsFixed(2)}';

  Future<void> _loadCoupons() async {
    final scope = _couponScope;
    final base = _baseAmount;
    final key = _couponsKey;
    if (_couponsLoadedFor == key) return;
    try {
      final res = await _api.getAvailableCoupons(scope, base);
      // Drop a stale response if the priced selection moved on meanwhile.
      if (!mounted || _couponsKey != key) return;
      setState(() { _availableCoupons = asList(res); _couponsLoaded = true; _couponsLoadedFor = key; });
    } catch (_) {/* non-critical */}
  }

  // Light debounce so rapid taps on the plant counter / add-ons collapse
  // into a single refresh.
  void _scheduleCouponRefresh() {
    _couponsDebounce?.cancel();
    _couponsDebounce = Timer(const Duration(milliseconds: 350), () { if (mounted) _loadCoupons(); });
  }

  // Drop an applied coupon whenever the priced selection changes so a stale
  // discount never reaches the server. Also queues an available-coupon
  // refresh since eligibility/savings depend on the new subtotal.
  void _clearCoupon() {
    _appliedCouponCode = null;
    _couponDiscount = 0;
    _couponMsg = null;
    _couponCtrl.clear();
    _scheduleCouponRefresh();
  }

  Future<void> _applyCoupon([String? codeArg]) async {
    final code = (codeArg ?? _couponCtrl.text).trim().toUpperCase();
    if (code.isEmpty) { setState(() => _couponMsg = 'Enter a coupon code'); return; }
    final scope = _couponScope;
    final base = _baseAmount;
    setState(() { _couponBusy = true; _couponMsg = null; _couponCtrl.text = code; });
    try {
      final res = await _api.validateCoupon(code, base, scope);
      if (!mounted) return;
      // Ignore a late response if the priced selection changed meanwhile.
      if (_couponScope != scope || _baseAmount != base) return;
      if (res is Map && res['code'] != null && res['discount_amount'] != null) {
        setState(() { _appliedCouponCode = asStr(res['code']); _couponDiscount = asDouble(res['discount_amount']); _couponMsg = null; });
        showMsg(context, 'Coupon ${asStr(res['code'])} applied', ok: true);
      } else {
        final msg = res is Map ? asStr(res['message']) : '';
        setState(() { _appliedCouponCode = null; _couponDiscount = 0; _couponMsg = msg.isEmpty ? 'Invalid coupon code' : msg; });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _appliedCouponCode = null; _couponDiscount = 0; _couponMsg = e.message; });
    } catch (_) {
      if (mounted) setState(() { _appliedCouponCode = null; _couponDiscount = 0; _couponMsg = 'Could not apply coupon. Please try again.'; });
    } finally { if (mounted) setState(() => _couponBusy = false); }
  }

  void _removeCoupon() => setState(_clearCoupon);

  // Select a date and show its availability. Only the response for the date
  // that is *currently* selected is applied — a slow reply for a date the user
  // already left can no longer overwrite the current one.
  void _selectDate(String date) {
    final cached = _slotCache[date];
    setState(() {
      _date = date;
      _slotsError = false;
      if (cached != null) {
        _applySlots(cached.slots, cached.noGardeners);
      } else {
        _availableSlots = [];
        _slotsLoaded = false;
        _noGardenersInZone = false;
      }
    });
    _loadAvailability(date);
  }

  // Must be called inside setState.
  void _applySlots(List<String> slots, bool noGardeners) {
    _availableSlots = slots;
    _noGardenersInZone = noGardeners;
    _slotsLoaded = true;
    // Drop a previously picked time that isn't free on this date.
    if (!slots.contains(_time)) _time = '';
  }

  Future<void> _loadAvailability(String date) async {
    final zoneId = _zone != null ? asInt(_zone!['id']) : 0;
    if (zoneId == 0) return;
    setState(() { _loadingSlots = !_slotCache.containsKey(date); _slotsError = false; });
    try {
      final res = await _api.checkAvailability(date: date, geofenceId: zoneId);
      if (!mounted) return;
      final slots = asList(res is Map ? (res['available_slots'] ?? res['slots'] ?? res) : res)
          .map((s) => s.toString()).toList();
      final noGardeners = (res is Map && res['no_gardeners_in_zone'] == true) || slots.isEmpty;
      _slotCache[date] = (slots: slots, noGardeners: noGardeners);
      if (date != _date) return; // user moved on to another date
      setState(() { _applySlots(slots, noGardeners); _loadingSlots = false; });
    } catch (_) {
      if (!mounted || date != _date) return;
      setState(() {
        _loadingSlots = false;
        if (!_slotCache.containsKey(date)) { _slotsLoaded = false; _slotsError = true; _time = ''; }
      });
    }
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
      setState(() { _picked = result; _slotCache.clear(); _slotsLoaded = false; _time = ''; }); // new address → new availability
      _loadInstantInfo();
      _scheduleCouponRefresh(); // zone base price feeds the coupon subtotal
    }
  }

  // Instant booking removed — this is now a no-op. The original instant
  // availability check is preserved in git history.
  Future<void> _loadInstantInfo() async {
    // No-op: all on-demand bookings are scheduled.
    // ── ORIGINAL (instant availability check) ────────────────────────────────
    // final id = asInt(_picked?.zone['id']);
    // if (id <= 0 || _isSub) { setState(() { _instantInfo = null; }); return; }
    // setState(() => _checkingInstant = true);
    // try {
    //   final res = asMap(await _api.getInstantAvailability(id));
    //   if (!mounted) return;
    //   setState(() {
    //     _instantInfo = res;
    //     final etaOk = asInt(res['eta_minutes']) > 0;
    //     final available = res['available'] == true;
    //     if (_mode == 'instant' && (!etaOk || !available)) _mode = 'schedule';
    //   });
    // } catch (_) {
    //   if (mounted) setState(() => _instantInfo = {'available': false, 'eta_minutes': 0});
    // } finally {
    //   if (mounted) setState(() => _checkingInstant = false);
    // }
  }

  Future<void> _submit() async {
    if (_picked == null || _selectedPlan == null) return;
    // Operations kill-switch — short-circuit before hitting the API. The
    // server enforces this regardless (503 on create endpoints).
    final ops = context.read<OpsStatusProvider>();
    if (ops.paused) { showMsg(context, ops.displayMessage, err: true); return; }
    setState(() => _submitting = true);
    var zoneId = _zone != null && asInt(_zone!['id']) > 0 ? asInt(_zone!['id']) : 0;

    try {
      if (zoneId == 0) throw ApiError('Please select a serviceable location first.', 404);

      // Re-confirm the address with the server right before booking — zones
      // cached on the device can be stale (area removed / boundaries changed).
      final fresh = asMap(asMap(await _api.checkServiceability(_picked!.lat, _picked!.lng))['zone']);
      if (fresh.isEmpty) {
        throw ApiError("We don't serve this address yet. Please choose another location.", 404);
      }
      zoneId = asInt(fresh['id']);
      if (mounted) context.read<LocationProvider>().updateZoneForCurrent(fresh);

      final addonsPayload = _selectedAddons.map((id) => {'addon_id': id, 'quantity': 1}).toList();
      final totalAmount = _total; // client estimate; server recomputes and is authoritative
      final couponCode = _appliedCouponCode;

      if (_isSub) {
        final sub = await _api.createSubscription(
          planId: _planId!,
          zoneId: zoneId,
          geofenceId: _picked?.geofenceId,
          serviceAddress: _picked!.address,
          lat: _picked!.lat, lng: _picked!.lng,
          flatNo: _picked!.flatNo, building: _picked!.building,
          area: _picked!.area, landmark: _picked!.landmark,
          city: _picked!.city, state: _picked!.state, pincode: _picked!.pincode,
          plantCount: _plantCount,
          autoRenew: _autoRenew,
          addons: addonsPayload,
          totalAmount: totalAmount,
          paymentMethod: 'razorpay',
          couponCode: couponCode,
        );
        final subId = asInt(asMap(sub)['id']);
        final pay = await RazorpayService().pay(type: 'subscription', subscriptionId: subId);
        if (!mounted) return;
        setState(() => _submitting = false);
        showMsg(context, pay.ok ? 'Subscription activated!' : (pay.cancelled ? 'Payment cancelled — subscription not placed.' : (pay.message ?? 'Payment failed')), ok: pay.ok, err: !pay.ok && !pay.cancelled);
        await Future.delayed(1000.ms);
        if (mounted) { Navigator.pop(context, true); Navigator.pushNamed(context, '/subscriptions'); }
      } else {
        // On-demand bookings are always scheduled (instant booking removed).
        final booking = await _api.createBooking(
          zoneId: zoneId,
          geofenceId: _picked?.geofenceId,
          isInstant: false,
          scheduledDate: _date,
          scheduledTime: _time,
          serviceAddress: _picked!.address,
          lat: _picked!.lat, lng: _picked!.lng,
          flatNo: _picked!.flatNo, building: _picked!.building,
          area: _picked!.area, landmark: _picked!.landmark,
          city: _picked!.city, state: _picked!.state, pincode: _picked!.pincode,
          plantCount: _plantCount,
          planId: _planId,
          customerNotes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          addons: addonsPayload,
          totalAmount: totalAmount,
          couponCode: couponCode,
        );
        final bookingId = asInt(asMap(booking)['id']);
        final pay = await RazorpayService().pay(type: 'booking', bookingId: bookingId);
        if (!mounted) return;
        setState(() => _submitting = false);
        showMsg(context, pay.ok ? 'Booking confirmed & paid!' : (pay.cancelled ? 'Payment cancelled — booking not placed.' : (pay.message ?? 'Payment failed')), ok: pay.ok, err: !pay.ok && !pay.cancelled);
        await Future.delayed(800.ms);
        if (mounted) {
          BookingsScreen.needsReload = true;
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
      case 'Schedule':
        if (_isSub) return true;
        // Scheduled: need a date, slots loaded, gardeners available, and a valid selected slot.
        return _date.isNotEmpty && _slotsLoaded && !_noGardenersInZone && _time.isNotEmpty && _availableSlots.contains(_time);
      default:         return true;
    }
  }

  String get _currentStepKey => _labels[_stepIdx];
  void _goNext() { if (_canNext()) setState(() => _stepIdx++); }

  @override
  Widget build(BuildContext ctx) {
    final labels = _labels;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Column(children: [
          _buildHeader(ctx, labels),
          const GOpsBanner(margin: EdgeInsets.fromLTRB(16, 12, 16, 0)),
          Expanded(child: _buildBody()),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav(ctx)),
      ]),
    );
  }

  static const _stepTitles = {
    'Location': 'Where should\nwe come?',
    'Plan': 'Choose your\ncare',
    'Plants': 'Any extra\nplants?',
    'Add-ons': 'Anything\nextra?',
    'Schedule': 'Pick a date\n& time',
    'Checkout': 'Review\n& pay',
  };

  Widget _buildHeader(BuildContext ctx, List<String> labels) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          VRoundBtn(icon: Icons.arrow_back_rounded, onTap: () => _stepIdx == 0 ? Navigator.pop(ctx) : setState(() => _stepIdx--)),
          const Spacer(),
          Text('Step ${_stepIdx + 1} of ${labels.length}', style: p(12.5, w: FontWeight.w600, color: V.fog)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isSub ? 'Subscription' : 'One-time visit', style: p(12.5, color: V.leaf, w: FontWeight.w600)),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(_stepTitles[labels[_stepIdx]] ?? labels[_stepIdx],
                key: ValueKey(_stepIdx),
                style: vx(30, w: FontWeight.w600, color: V.ink, ls: -0.8, h: 1.05)),
            ),
            const SizedBox(height: 14),
            Row(children: List.generate(labels.length, (i) => Expanded(child: AnimatedContainer(
              duration: 300.ms,
              height: 4,
              margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 5),
              decoration: BoxDecoration(
                color: i < _stepIdx ? V.leaf : (i == _stepIdx ? V.ink : V.ink.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(99)),
            )))),
          ]),
        ),
      ]),
    ),
  );

  Widget _buildBody() {
    if (_loading && _stepIdx >= 1) return const Center(child: CircularProgressIndicator(color: V.leaf));
    return AnimatedSwitcher(duration: 300.ms, child: KeyedSubtree(key: ValueKey(_stepIdx), child: _buildStep()));
  }

  bool get _isAnnualPlan => _isSub && asInt(_selectedPlan?['duration_days']) >= 300;

  // Live one-line summary of what's been chosen so far.
  String get _summary {
    final parts = <String>[];
    final plan = asStr(_selectedPlan?['name']);
    if (plan.isNotEmpty) parts.add(plan);
    if (!_isSub && _date.isNotEmpty && _time.isNotEmpty) {
      final d = DateTime.tryParse(_date);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      if (d != null) parts.add('${d.day} ${m[d.month - 1]}${_time.isNotEmpty ? ', $_time' : ''}');
    }
    if (_plantCount > 0) parts.add('+$_plantCount plants');
    return parts.join('  ·  ');
  }

  // Floating bottom: summary pill + button, no bar behind them.
  Widget _buildBottomNav(BuildContext ctx) {
    final summary = _summary;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(ctx).padding.bottom + 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFFF5F9F4).withValues(alpha: 0), const Color(0xFFF5F9F4).withValues(alpha: 0.95)],
          stops: const [0, 0.45],
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (summary.isNotEmpty && _selectedPlan != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(12.5, color: V.fog))),
              const SizedBox(width: 10),
              Text('₹${_total.toStringAsFixed(0)}', style: vx(18, w: FontWeight.w600, color: V.ink)),
            ]),
          ),
        _stepIdx < _lastStep
          ? GBtn(label: 'Continue', icon: Icons.arrow_forward_rounded, glass: true, onTap: _canNext() ? _goNext : null)
          : GBtn(
              label: _isSub ? 'Subscribe · ₹${_total.toStringAsFixed(0)}${_isAnnualPlan ? '/yr' : '/mo'}' : 'Pay ₹${_total.toStringAsFixed(0)} & book',
              loading: _submitting, glass: true, onTap: _submit),
      ]),
    );
  }

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

  static const _stepPad = EdgeInsets.fromLTRB(16, 22, 16, 170);

  Widget _stepLocation() => SingleChildScrollView(padding: _stepPad, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (_picked != null) GCard(
      padding: const EdgeInsets.all(18),
      radius: BorderRadius.circular(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const VOrb(icon: Icons.location_on_outlined, size: 44),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((_picked!.label ?? '').isNotEmpty ? _picked!.label! : 'Service address', style: vx(17, w: FontWeight.w600, color: V.ink)),
            const SizedBox(height: 3),
            Text(_cleanAddr(_picked!.fullAddress), style: p(12.5, color: V.fog, h: 1.45)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _zoneChecking
            ? Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: V.leaf)),
                const SizedBox(width: 10),
                Text('Checking your area…', style: p(12.5, color: V.fog)),
              ])
            : asInt(_picked!.zone['id']) > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, size: 15, color: V.deep),
                    const SizedBox(width: 6),
                    Flexible(child: Text('We serve ${asStr(_picked!.zone['name'], 'this area')}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: p(12, w: FontWeight.w600, color: V.deep))),
                  ]),
                )
              : Text("We don't serve this address yet — try another.", style: p(12.5, color: C.amber, w: FontWeight.w600))),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
              child: Text('Change', style: p(12.5, w: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ]),
    )
    else Column(children: [
      const SizedBox(height: 30),
      const VOrb(icon: Icons.add_location_alt_outlined, size: 80, dark: false),
      const SizedBox(height: 20),
      Text('Add your address', style: vx(22, w: FontWeight.w600, color: V.ink), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text("We'll check that a gardener can reach you.", style: p(13.5, color: V.fog), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      GBtn(label: 'Choose address', icon: Icons.near_me_outlined, onTap: _openPicker),
    ]),
  ]));

  // ── Service details ("What's included & FAQs") ────────────────────────────
  bool _svcInfoLoading = false;

  Future<void> _showServiceInfo() async {
    if (_svcInfoLoading) return;
    final slug = _isSub ? 'monthly-plant-care' : 'one-time-plant-care';
    setState(() => _svcInfoLoading = true);
    try {
      final svc = await ServiceDetailsCache.bySlug(slug); // in-memory, cached per slug
      if (!mounted) return;
      if (svc.isEmpty) { showMsg(context, 'Service details are unavailable right now.', err: true); return; }
      showServiceDetailsSheet(context, svc);
    } on ApiError catch (e) {
      if (mounted) showMsg(context, e.message, err: true);
    } catch (_) {
      if (mounted) showMsg(context, 'Could not load service details. Please try again.', err: true);
    } finally {
      if (mounted) setState(() => _svcInfoLoading = false);
    }
  }

  Widget _serviceInfoRow() => GestureDetector(
    onTap: _showServiceInfo,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white)),
      child: Row(children: [
        const Icon(Icons.help_outline_rounded, size: 19, color: V.leaf),
        const SizedBox(width: 10),
        Expanded(child: Text("What's included & FAQs", style: p(13.5, w: FontWeight.w600, color: V.ink))),
        _svcInfoLoading
          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: V.leaf))
          : const Icon(Icons.arrow_forward_rounded, size: 17, color: V.fog),
      ]),
    ),
  );

  Widget _stepPlan() => SingleChildScrollView(padding: _stepPad, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_odPlans.isNotEmpty) ...[
      GSec('One-time visit'),
      const SizedBox(height: 12),
      ..._odPlans.map((pl) => _PlanItem(plan: pl, sel: _planId == asInt(pl['id']), onTap: () => _selectPlan(Map<String, dynamic>.from(pl)), displayPrice: _odPrice(Map<String, dynamic>.from(pl as Map)))),
    ],
    if (_subPlans.isNotEmpty) ...[
      if (_odPlans.isNotEmpty) const SizedBox(height: 24),
      GSec('Subscriptions'),
      const SizedBox(height: 12),
      ..._subPlans.map((pl) => _PlanItem(plan: pl, sel: _planId == asInt(pl['id']), onTap: () => _selectPlan(Map<String, dynamic>.from(pl)), displayPrice: _odPrice(Map<String, dynamic>.from(pl as Map)))),
    ],
    const SizedBox(height: 10),
    _serviceInfoRow(),
  ]));

  Widget _stepPlants() {
    final freePlants = asInt(_selectedPlan?['max_plants']);
    return SingleChildScrollView(padding: _stepPad, child: Column(children: [
      Text(
        freePlants > 0
            ? 'Your plan covers up to $freePlants plants. Add more only if you need them — ₹25 each.'
            : 'Add plants beyond your plan — ₹25 each. This is optional.',
        textAlign: TextAlign.center,
        style: p(13.5, color: V.fog, h: 1.5),
      ),
      const SizedBox(height: 34),
      // Rotary knob — turn to change the count; one haptic tick per step.
      _PlantKnob(
        value: _plantCount,
        max: 200,
        onChanged: (v) => setState(() { _plantCount = v; _clearCoupon(); }),
      ),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _CounterBtn(icon: Icons.remove_rounded, enabled: _plantCount > 0, onTap: () => setState(() { _plantCount--; _clearCoupon(); })),
        const SizedBox(width: 18),
        Text('Turn the dial or tap', style: p(12, color: V.fog)),
        const SizedBox(width: 18),
        _CounterBtn(icon: Icons.add_rounded, enabled: _plantCount < 200, onTap: () => setState(() { _plantCount++; _clearCoupon(); })),
      ]),
      const SizedBox(height: 20),
      Text(_plantCount == 0 ? 'No extra plants' : '$_plantCount extra plant${_plantCount == 1 ? '' : 's'}  ·  +₹${_plantCount * 25}',
        style: p(14, color: V.deep, w: FontWeight.w600)),
    ]));
  }

  Widget _stepAddons() => SingleChildScrollView(padding: _stepPad, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_addons.isEmpty) const GEmpty(title: 'No add-ons right now', sub: 'Continue to the next step.', icon: Icons.add_box_outlined)
    else ...[
      Text('Optional extras for this visit.', style: p(13.5, color: V.fog)),
      const SizedBox(height: 14),
      ..._addons.map((a) {
        final id = asInt(a['id']); final sel = _selectedAddons.contains(id);
        return GestureDetector(
          onTap: () => setState(() { if (sel) { _selectedAddons.remove(id); } else { _selectedAddons.add(id); } _clearCoupon(); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sel ? V.mint : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? V.leaf : Colors.white, width: sel ? 1.5 : 1),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24, height: 24,
                decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? V.leaf : Colors.transparent, border: Border.all(color: sel ? V.leaf : V.fog, width: 1.5)),
                child: sel ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(asStr(a['name']), style: p(14, w: FontWeight.w600, color: V.ink))),
              Text('+₹${asDouble(a['price']).toStringAsFixed(0)}', style: vx(17, w: FontWeight.w600, color: V.ink)),
            ]),
          ),
        );
      }),
    ],
  ]));

  // Instant booking removed — this step is now scheduled-only (date + time + notes).
  Widget _stepSchedule() {
    // First time on this step: fetch the default date's slots.
    if (_date.isNotEmpty && !_slotsLoaded && !_loadingSlots && !_slotsError && !_slotCache.containsKey(_date)) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && !_loadingSlots && !_slotsLoaded) _loadAvailability(_date); });
    }
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return SingleChildScrollView(padding: _stepPad, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GSec('Date'),
      const SizedBox(height: 12),
      SizedBox(height: 92, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = DateTime.now().add(Duration(days: i + 1));
          final ds = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}';
          final sel = _date == ds;
          return GestureDetector(
            onTap: () => _selectDate(ds),
            child: AnimatedContainer(
              duration: 200.ms,
              width: 66,
              decoration: BoxDecoration(
                color: sel ? V.ink : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? V.ink : Colors.white),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(days[d.weekday - 1], style: p(11, w: FontWeight.w500, color: sel ? Colors.white70 : V.fog)),
                const SizedBox(height: 2),
                Text('${d.day}', style: vx(24, w: FontWeight.w600, color: sel ? Colors.white : V.ink, h: 1.1)),
                Text(months[d.month - 1], style: p(10.5, color: sel ? V.lime : V.fog)),
              ]),
            ),
          );
        },
      )),
      const SizedBox(height: 26),
      GSec('Time'),
      const SizedBox(height: 12),
      if (_loadingSlots || (!_slotsLoaded && !_slotsError))
        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: V.leaf))))
      else if (_slotsError)
        GestureDetector(
          onTap: () => _loadAvailability(_date),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white)),
            child: Row(children: [
              const Icon(Icons.refresh_rounded, color: V.leaf, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text("Couldn't load time slots. Tap to try again.", style: p(13, w: FontWeight.w600, color: V.ink))),
            ]),
          ),
        )
      else if (_slotsLoaded && _noGardenersInZone)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFFF6E0), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF1D58A))),
          child: Row(children: [
            const Icon(Icons.event_busy_outlined, color: Color(0xFF8A6400), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('No gardeners are free on this date. Please pick another day.', style: p(13, w: FontWeight.w600, color: const Color(0xFF6B4E00), h: 1.4))),
          ]),
        )
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: ({..._slots, ..._availableSlots}.toList()..sort()).map((t) {
            // A slot is only selectable once this date's availability has loaded
            // and the server listed it as free.
            final available = _slotsLoaded && _availableSlots.contains(t);
            final sel = available && _time == t;
            return GestureDetector(
              onTap: available ? () => setState(() => _time = t) : null,
              child: AnimatedContainer(
                duration: 200.ms,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? V.ink : available ? Colors.white.withValues(alpha: 0.7) : V.ink.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? V.ink : available ? Colors.white : Colors.transparent),
                ),
                child: Text(t, style: p(14, w: FontWeight.w600,
                  color: sel ? Colors.white : available ? V.ink : V.fog.withValues(alpha: 0.5),
                  decoration: available ? null : TextDecoration.lineThrough)),
              ),
            );
          }).toList(),
        ),
      const SizedBox(height: 26),
      GField(ctrl: _notesCtrl, label: 'Notes for the gardener', hint: 'Gate code, which plants need attention…', maxLines: 3),
    ]));
  }

  Widget _stepCheckout() {
    final prov = context.read<LocationProvider>();
    final d = DateTime.tryParse(_date);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    Widget line(String l, String v, {Color? color, bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: strong ? vx(18, w: FontWeight.w600, color: V.ink) : p(13, color: color ?? V.fog)),
        const SizedBox(width: 16),
        Expanded(child: Text(v, textAlign: TextAlign.right,
          style: strong ? vx(24, w: FontWeight.w600, color: V.ink) : p(13, w: FontWeight.w600, color: color ?? V.ink))),
      ]),
    );
    return SingleChildScrollView(padding: _stepPad, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Visit ticket
      VPod(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asStr(_selectedPlan?['name'], 'Garden care'), style: vx(22, w: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          if (!_isSub && d != null)
            Text('${d.day} ${months[d.month - 1]} ${d.year}  ·  $_time', style: p(14, w: FontWeight.w600, color: V.lime)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Colors.white60),
            const SizedBox(width: 8),
            Expanded(child: Text('${prov.label} — ${_cleanAddr(prov.fullAddress)}', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: p(12.5, color: Colors.white.withValues(alpha: 0.85), h: 1.4))),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      GCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        radius: BorderRadius.circular(24),
        child: Column(children: [
          line('Extra plants', _plantCount == 0 ? 'None' : '$_plantCount × ₹25'),
          if (!_isSub && _selectedAddons.isNotEmpty)
            line('Add-ons', _addons.where((a) => _selectedAddons.contains(asInt(a['id']))).map((a) => asStr(a['name'])).join(', ')),
          line('Subtotal', '₹${_baseAmount.toStringAsFixed(0)}'),
          line('GST (18%)', '₹${_gstAmount.toStringAsFixed(0)}'),
          if (_appliedCouponCode != null && _couponDiscount > 0)
            line('Coupon $_appliedCouponCode', '− ₹${_couponDiscount.toStringAsFixed(0)}', color: const Color(0xFF166534)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: CustomPaint(size: const Size(double.infinity, 1), painter: _Dash())),
          const SizedBox(height: 6),
          line('Total', '₹${_total.toStringAsFixed(0)}', strong: true),
        ]),
      ),
      const SizedBox(height: 18),
      _couponSection(),
      const SizedBox(height: 16),
      _serviceInfoRow(),
    ]));
  }

  // ── Coupon card (checkout) ───────────────────────────────────────────────
  Widget _couponSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GSec('Coupon'),
      const SizedBox(height: 10),
      if (_appliedCouponCode != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(18), border: Border.all(color: V.leaf.withValues(alpha: 0.4))),
          child: Row(children: [
            const Icon(Icons.local_offer_outlined, color: V.deep, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('$_appliedCouponCode applied · you save ₹${_couponDiscount.toStringAsFixed(0)}', style: p(13.5, w: FontWeight.w600, color: V.deep), maxLines: 1, overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: _removeCoupon, child: Text('Remove', style: p(12.5, w: FontWeight.w600, color: C.red))),
          ]),
        )
      else ...[
        Container(
          height: 54,
          padding: const EdgeInsets.only(left: 18, right: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white)),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _couponCtrl,
              textCapitalization: TextCapitalization.characters,
              enabled: !_couponBusy,
              style: p(14, w: FontWeight.w600, color: V.ink, ls: 1),
              decoration: InputDecoration(
                hintText: 'Enter coupon code',
                hintStyle: p(13.5, color: V.fog),
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) { if (_couponMsg != null) setState(() => _couponMsg = null); },
              onSubmitted: (_) { if (!_couponBusy) _applyCoupon(); },
            )),
            GestureDetector(
              onTap: _couponBusy ? null : () => _applyCoupon(),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: V.ink, borderRadius: BorderRadius.circular(99)),
                child: _couponBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Apply', style: p(13.5, w: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
        if (_couponMsg != null)
          Padding(padding: const EdgeInsets.only(top: 8, left: 6), child: Text(_couponMsg!, style: p(12, w: FontWeight.w500, color: C.red))),
        if (_couponsLoaded) ..._couponGroups(),
      ],
    ]);
  }

  // Eligible coupons first (tap = apply), then "not eligible yet" with the
  // server's reason. Eligibility and savings come from the server.
  List<Widget> _couponGroups() {
    final rows = _availableCoupons.map((c) => asMap(c)).toList();
    if (rows.isEmpty) return const [];
    final eligible = rows.where((c) => c['eligible'] == true).toList();
    final ineligible = rows.where((c) => c['eligible'] != true).toList();
    return [
      const SizedBox(height: 12),
      if (eligible.isNotEmpty) _couponRow(eligible),
      if (ineligible.isNotEmpty) ...[
        if (eligible.isNotEmpty) const SizedBox(height: 10),
        Text('Unlock with a bigger order', style: p(12, color: V.fog)),
        const SizedBox(height: 8),
        _couponRow(ineligible),
      ],
    ];
  }

  Widget _couponRow(List<Map<String, dynamic>> items) => SizedBox(
    height: 66,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => _couponChip(items[i]),
    ),
  );

  Widget _couponChip(Map<String, dynamic> c) {
    final code = asStr(c['code']);
    final eligible = c['eligible'] == true;
    final saving = asDouble(c['discount_amount']);
    final reason = asStr(c['reason']);
    final desc = asStr(c['description']);
    return GestureDetector(
      onTap: (eligible && !_couponBusy) ? () => _applyCoupon(code) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 230),
        decoration: BoxDecoration(
          color: eligible ? V.mint : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: eligible ? V.leaf.withValues(alpha: 0.5) : Colors.white),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eligible ? '$code · save ₹${saving.toStringAsFixed(0)}' : code, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: p(13, w: FontWeight.w700, color: eligible ? V.deep : V.fog, ls: 0.3)),
          const SizedBox(height: 3),
          Text(eligible ? (desc.isNotEmpty ? desc : 'Tap to apply') : (reason.isNotEmpty ? reason : 'Not eligible yet'),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: p(11, color: eligible ? V.leaf : V.fog)),
        ]),
      ),
    );
  }
}

class _Dash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = V.ink.withValues(alpha: 0.18)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) { canvas.drawLine(Offset(x, 0), Offset(x + 3.5, 0), paint); }
  }
  @override
  bool shouldRepaint(_Dash old) => false;
}

// Selectable plan row: light glass, or the dark panel with a lime check when
// selected.
class _PlanItem extends StatelessWidget {
  final Map<String, dynamic> plan; final bool sel; final VoidCallback onTap;
  final double? displayPrice;
  const _PlanItem({required this.plan, required this.sel, required this.onTap, this.displayPrice});

  // Same billing-cycle derivation as the Plans page — the backend has no
  // dedicated field, so annual vs monthly comes from duration_days.
  bool get _isSub => asStr(plan['plan_type']) == 'subscription';
  bool get _isAnnual => _isSub && asInt(plan['duration_days']) >= 300;

  @override
  Widget build(BuildContext ctx) {
    final shownPrice = displayPrice ?? asDouble(plan['price']);
    final priceSubtitle = asStr(plan['price_subtitle']).isNotEmpty
        ? asStr(plan['price_subtitle'])
        : (_isSub ? (_isAnnual ? 'per year' : 'per month') : 'per visit');
    final tagline = asStr(plan['tagline']).isNotEmpty
        ? asStr(plan['tagline'])
        : asStr(plan['plan_summary'], _isSub ? 'Regular care' : 'A single expert visit');
    final visits = asInt(plan['visits_per_month']);
    final maxPlants = asInt(plan['max_plants']);
    final features = asList(plan['features']).map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    final fg = sel ? Colors.white : V.ink;
    final muted = sel ? Colors.white.withValues(alpha: 0.85) : V.fog;

    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(top: 2),
          width: 24, height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? V.lime : Colors.transparent,
            border: Border.all(color: sel ? V.lime : V.fog, width: 1.5)),
          child: sel ? const Icon(Icons.check_rounded, size: 15, color: V.ink) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asStr(plan['name']), style: vx(18, w: FontWeight.w600, color: fg)),
          const SizedBox(height: 2),
          Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(12, color: muted)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${shownPrice.toStringAsFixed(0)}', style: vx(22, w: FontWeight.w600, color: fg)),
          Text(priceSubtitle, style: p(10.5, color: muted)),
        ]),
      ]),
      if ((_isSub && visits > 0) || maxPlants > 0 || features.isNotEmpty) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text([
            if (_isSub && visits > 0) '$visits visits / month',
            if (maxPlants > 0) 'up to $maxPlants plants',
            ...features.take(2),
          ].join('  ·  '), maxLines: 2, overflow: TextOverflow.ellipsis, style: p(12, color: muted, h: 1.4)),
        ),
      ],
    ]);

    const pad = EdgeInsets.fromLTRB(16, 16, 16, 16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: sel
              ? VPod(key: const ValueKey('sel'), radius: 22, padding: pad, child: body)
              : Container(
                  key: const ValueKey('unsel'),
                  padding: pad,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white)),
                  child: body,
                ),
        ),
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon; final bool enabled; final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: enabled ? () { HapticFeedback.selectionClick(); onTap(); } : () => HapticFeedback.heavyImpact(),
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.35,
      child: Container(width: 56, height: 56,
        decoration: const BoxDecoration(color: V.ink, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white)),
    ),
  );
}


// ─── Rotary plant-count knob ──────────────────────────────────────────────────
// Drag around the dial: every [_step] of rotation is one plant, with a
// selection-click haptic per detent and a heavier bump when hitting 0 or max.
// The face (grip notches) turns with the finger; the outer arc fills with the
// count (full at [_arcFull] plants).
class _PlantKnob extends StatefulWidget {
  final int value, max;
  final ValueChanged<int> onChanged;
  const _PlantKnob({required this.value, required this.max, required this.onChanged});
  @override
  State<_PlantKnob> createState() => _PlantKnobState();
}

class _PlantKnobState extends State<_PlantKnob> {
  static const double _step = math.pi / 10; // 18° per plant
  static const int _arcFull = 50;
  double _rotation = 0; // visual rotation of the face
  double _carry = 0;    // rotation not yet turned into a step
  double? _lastAngle;
  bool _active = false;

  void _release() => setState(() { _lastAngle = null; _carry = 0; _active = false; });

  double _angleOf(Offset local, Size size) =>
      math.atan2(local.dy - size.height / 2, local.dx - size.width / 2);

  void _onUpdate(Offset local, Size size) {
    final a = _angleOf(local, size);
    final last = _lastAngle;
    _lastAngle = a;
    if (last == null) return;
    var d = a - last;
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    _carry += d;
    var v = widget.value;
    while (_carry >= _step) { _carry -= _step; v++; }
    while (_carry <= -_step) { _carry += _step; v--; }
    final clamped = v.clamp(0, widget.max);
    if (clamped != v) {
      // Hit a limit — stop the dial and give a firm bump once.
      if (widget.value != clamped || _carry.abs() > 0) HapticFeedback.heavyImpact();
      _carry = 0;
    }
    setState(() => _rotation += (clamped == v) ? d : 0);
    if (clamped != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    const size = 220.0;
    return SizedBox(
      width: size, height: size,
      // Claims the touch immediately so the page doesn't scroll while the
      // dial is being turned.
      child: RawGestureDetector(
        gestures: {
          _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(_EagerPan.new, (r) => r
            ..onStart = (d) { _lastAngle = _angleOf(d.localPosition, const Size(size, size)); setState(() => _active = true); HapticFeedback.lightImpact(); }
            ..onUpdate = (d) { _onUpdate(d.localPosition, const Size(size, size)); }
            ..onEnd = (_) { _release(); }
            ..onCancel = () { _release(); }),
        },
        child: Stack(alignment: Alignment.center, children: [
          // Ticks + progress arc
          CustomPaint(size: const Size(size, size), painter: _KnobRingPainter(
            fraction: (widget.value / _arcFull).clamp(0.0, 1.0),
            over: widget.value > _arcFull,
          )),
          // Knob face — scales slightly while held, grip notches rotate
          AnimatedScale(
            scale: _active ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: size * 0.66, height: size * 0.66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(center: Alignment(-0.35, -0.45), colors: [Colors.white, Color(0xFFE6EFE8)]),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: V.ink.withValues(alpha: _active ? 0.10 : 0.16), blurRadius: _active ? 14 : 26, offset: Offset(0, _active ? 6 : 12)),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 10, offset: const Offset(-4, -4)),
                ],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Transform.rotate(
                  angle: _rotation,
                  child: CustomPaint(size: Size.square(size * 0.66), painter: _GripPainter()),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                    child: Text('${widget.value}', key: ValueKey(widget.value), style: vx(52, w: FontWeight.w600, color: V.ink, h: 1)),
                  ),
                  Text(widget.value == 1 ? 'plant' : 'plants', style: p(12, color: V.fog)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _KnobRingPainter extends CustomPainter {
  final double fraction;
  final bool over;
  _KnobRingPainter({required this.fraction, required this.over});
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    const start = -math.pi / 2;
    // 50 tick marks
    for (var i = 0; i < 50; i++) {
      final a = start + i / 50 * 2 * math.pi;
      final lit = i / 50 < fraction || over;
      final major = i % 5 == 0;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - (major ? 12 : 8));
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(p1, p2, Paint()
        ..strokeWidth = major ? 2.2 : 1.4
        ..strokeCap = StrokeCap.round
        ..color = lit ? V.leaf : V.ink.withValues(alpha: 0.14));
    }
    // inner progress arc
    final rect = Rect.fromCircle(center: c, radius: r - 20);
    canvas.drawArc(rect, 0, 2 * math.pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = V.ink.withValues(alpha: 0.06));
    if (fraction > 0) {
      canvas.drawArc(rect, start, 2 * math.pi * fraction, false, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = V.lime);
    }
  }
  @override
  bool shouldRepaint(_KnobRingPainter old) => old.fraction != fraction || old.over != over;
}

class _GripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()..strokeWidth = 2..strokeCap = StrokeCap.round..color = V.ink.withValues(alpha: 0.08);
    for (var i = 0; i < 24; i++) {
      final a = i / 24 * 2 * math.pi;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r - 14), c + Offset(math.cos(a), math.sin(a)) * (r - 6), paint);
    }
    // indicator notch
    canvas.drawCircle(c + const Offset(0, -1) * (r - 22), 4, Paint()..color = V.leaf);
  }
  @override
  bool shouldRepaint(_GripPainter old) => false;
}

class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
