import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _date = '', _time = '09:00';
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
  bool _loadingSlots = false, _slotsLoaded = false, _noGardenersInZone = false;

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
        setState(() { _picked = updated; _zoneChecking = false; });
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

  Future<void> _loadAvailability(String date) async {
    final zoneId = _zone != null ? asInt(_zone!['id']) : 0;
    if (zoneId == 0) return;
    setState(() { _loadingSlots = true; _slotsLoaded = false; _noGardenersInZone = false; });
    try {
      final res = await _api.checkAvailability(date: date, geofenceId: zoneId);
      if (!mounted) return;
      final slots = asList(res is Map ? (res['available_slots'] ?? res['slots'] ?? res) : res)
          .map((s) => s.toString()).toList();
      setState(() {
        _availableSlots = slots;
        _noGardenersInZone = (res is Map && res['no_gardeners_in_zone'] == true) || slots.isEmpty;
        _slotsLoaded = true;
        _loadingSlots = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loadingSlots = false; _slotsLoaded = false; });
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
      setState(() => _picked = result);
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
    final zoneId = _zone != null && asInt(_zone!['id']) > 0 ? asInt(_zone!['id']) : 0;

    try {
      if (zoneId == 0) throw ApiError('Please select a serviceable location first.', 404);

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
        return _date.isNotEmpty && !_loadingSlots && !_noGardenersInZone && _availableSlots.contains(_time);
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
        const GOpsBanner(margin: EdgeInsets.fromLTRB(16, 16, 16, 0)),
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

  bool get _isAnnualPlan => _isSub && asInt(_selectedPlan?['duration_days']) >= 300;

  Widget _buildBottomNav(BuildContext ctx) => Container(
    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 16),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))]),
    child: _stepIdx < _lastStep
      ? GBtn(label: 'Continue', icon: Icons.arrow_forward_rounded, onTap: _canNext() ? _goNext : null, bg: C.forest)
      : GBtn(label: _isSub ? 'Subscribe — ₹${_total.toStringAsFixed(0)}${_isAnnualPlan ? '/yr' : '/mo'}' : 'Confirm Booking — ₹${_total.toStringAsFixed(0)}', bg: C.forest, loading: _submitting, onTap: _submit),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: C.forest.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border)),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: C.forest),
        const SizedBox(width: 10),
        Expanded(child: Text("What's included & FAQs",
          style: p(13, w: FontWeight.w700, color: C.forest))),
        _svcInfoLoading
          ? const SizedBox(width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: C.forest))
          : const Icon(Icons.chevron_right_rounded, size: 18, color: C.forest),
      ]),
    ),
  );

  Widget _stepPlan() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_odPlans.isNotEmpty) ...[
      GSec('One-Time Visit'),
      const SizedBox(height: 12),
      ..._odPlans.map((pl) => _PlanItem(plan: pl, sel: _planId == asInt(pl['id']), onTap: () => _selectPlan(Map<String, dynamic>.from(pl)), displayPrice: _odPrice(Map<String, dynamic>.from(pl as Map)))),
    ],
    if (_subPlans.isNotEmpty) ...[
      if (_odPlans.isNotEmpty) const SizedBox(height: 32),
      GSec('Subscription Plans'),
      const SizedBox(height: 12),
      ..._subPlans.map((pl) => _PlanItem(plan: pl, sel: _planId == asInt(pl['id']), onTap: () => _selectPlan(Map<String, dynamic>.from(pl)), displayPrice: _odPrice(Map<String, dynamic>.from(pl as Map)))),
    ],
    const SizedBox(height: 20),
    _serviceInfoRow(),
  ]));

  Widget _stepPlants() {
    final freePlants = asInt(_selectedPlan?['max_plants']);
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Additional Plants', style: p(24, w: FontWeight.w900, color: Colors.black)),
        const SizedBox(height: 10),
        Text(
          freePlants > 0
              ? 'Your plan already covers up to $freePlants plants. Add extra only if you need more — ₹25 each (optional).'
              : 'Add extra plants beyond your plan — ₹25 each (optional).',
          textAlign: TextAlign.center,
          style: p(13, color: Colors.black54, w: FontWeight.w600, h: 1.5),
        ),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _CounterBtn(icon: Icons.remove, enabled: _plantCount > 0, onTap: () => setState(() { _plantCount--; _clearCoupon(); })),
          SizedBox(width: 140, child: Center(child: Text('$_plantCount', style: GoogleFonts.poppins(fontSize: 80, fontWeight: FontWeight.w900, color: C.forest)))),
          _CounterBtn(icon: Icons.add, enabled: _plantCount < 200, onTap: () => setState(() { _plantCount++; _clearCoupon(); })),
        ]),
        const SizedBox(height: 16),
        Text(
          _plantCount == 0 ? 'No additional plants (plan only)' : '$_plantCount extra plants · +₹${_plantCount * 25}',
          style: p(14, color: C.forest, w: FontWeight.w700),
        ),
      ]),
    ));
  }

  Widget _stepAddons() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GSec('Optional Add-ons'),
    const SizedBox(height: 16),
    if (_addons.isEmpty) const GEmpty(title: 'No add-ons', sub: 'Continue to final step', icon: Icons.add_box_outlined)
    else ..._addons.map((a) {
      final id = asInt(a['id']); final sel = _selectedAddons.contains(id);
      return GestureDetector(
        onTap: () => setState(() { if (sel) { _selectedAddons.remove(id); } else { _selectedAddons.add(id); } _clearCoupon(); }),
        child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: sel ? C.forest : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? C.forest : Colors.black.withOpacity(0.08))), child: Row(children: [
          Icon(Icons.add_circle_outline_rounded, color: sel ? Colors.white : C.forest),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(asStr(a['name']), style: p(14, w: FontWeight.w700, color: sel ? Colors.white : Colors.black)), Text('Best for extra care', style: p(11, color: sel ? Colors.white70 : Colors.black38))])),
          Text('₹${asDouble(a['price']).toStringAsFixed(0)}', style: p(15, w: FontWeight.w800, color: sel ? C.gold : C.forest)),
        ])),
      );
    }),
  ]));

  // Instant booking removed — this step is now scheduled-only (date + time + notes).
  Widget _stepSchedule() {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GSec('Preferred Date'),
    const SizedBox(height: 16),
    SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 14, itemBuilder: (_, i) {
      final d = DateTime.now().add(Duration(days: i + 1));
      final ds = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}';
      final sel = _date == ds;
      return GestureDetector(
        onTap: () { setState(() { _date = ds; _slotsLoaded = false; _availableSlots = []; _noGardenersInZone = false; }); _loadAvailability(ds); },
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
    if (_loadingSlots)
      const Padding(padding: EdgeInsets.only(bottom: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.forest))))
    else if (_slotsLoaded && _noGardenersInZone)
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF5C842))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF7A5C00), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('No gardeners available in your area for this date. Please try another date.', style: p(13, w: FontWeight.w600, color: const Color(0xFF7A5C00)))),
        ]),
      )
    else
      Wrap(spacing: 12, runSpacing: 12, children: _slots.map((t) {
        final sel = _time == t;
        final available = !_slotsLoaded || _availableSlots.contains(t);
        return GestureDetector(
          onTap: available ? () => setState(() => _time = t) : null,
          child: AnimatedContainer(duration: 200.ms, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: sel ? C.forest : available ? const Color(0xFFF9F9F9) : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? C.forest : Colors.transparent)), child: Text(t, style: p(14, w: FontWeight.w700, color: sel ? Colors.white : available ? Colors.black54 : Colors.black26))),
        );
      }).toList()),
    const SizedBox(height: 32),
    GSec('Instructions'),
    const SizedBox(height: 12),
    TextField(controller: _notesCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'Any special requests?', filled: true, fillColor: const Color(0xFFF9F9F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
  ]));
  }

  Widget _stepCheckout() {
    final prov = context.read<LocationProvider>();
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GSec('Booking Overview'),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(32)), child: Column(children: [
        _RowInfo(label: 'Location', value: prov.label),
        _RowInfo(label: 'Address', value: _cleanAddr(prov.fullAddress), isBold: false),
        _RowInfo(label: 'Plan', value: asStr(_selectedPlan?['name'])),
        _RowInfo(label: 'Additional Plants', value: _plantCount == 0 ? 'None (plan only)' : '$_plantCount × ₹25 = +₹${_plantCount * 25}'),
        if (!_isSub) ...[
          _RowInfo(label: 'Date', value: _date),
          _RowInfo(label: 'Time', value: _time),
        ],
        if (!_isSub && _selectedAddons.isNotEmpty) _RowInfo(label: 'Add-ons', value: _selectedAddons.length.toString()),
        const Divider(height: 48),
        _couponSection(),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Subtotal (excl. GST)', style: p(13, color: Colors.black54, w: FontWeight.w600)),
          Text('₹${_baseAmount.toStringAsFixed(0)}', style: p(13, color: Colors.black54, w: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('GST (18%)', style: p(13, color: Colors.black54, w: FontWeight.w600)),
          Text('₹${_gstAmount.toStringAsFixed(0)}', style: p(13, color: Colors.black54, w: FontWeight.w700)),
        ]),
        if (_appliedCouponCode != null && _couponDiscount > 0) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Discount ($_appliedCouponCode)', style: p(13, color: C.green, w: FontWeight.w700)),
            Text('− ₹${_couponDiscount.toStringAsFixed(0)}', style: p(13, color: C.green, w: FontWeight.w800)),
          ]),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Amount', style: p(16, w: FontWeight.w700)),
          Text('₹${_total.toStringAsFixed(0)}', style: p(24, w: FontWeight.w900, color: C.green)),
        ]),
      ])),
      const SizedBox(height: 16),
      // Also reachable here for flows that skip the Plan step (pre-selected plan).
      _serviceInfoRow(),
      const SizedBox(height: 40),
    ]));
  }

  // ── Coupon card (checkout) ───────────────────────────────────────────────
  Widget _couponSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.local_offer_outlined, size: 16, color: C.forest),
        const SizedBox(width: 8),
        Text('Have a coupon?', style: p(13, w: FontWeight.w800, color: C.forest)),
      ]),
      const SizedBox(height: 10),
      if (_appliedCouponCode != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: C.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.green.withOpacity(0.5), width: 1.2),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: C.green, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('$_appliedCouponCode applied · −₹${_couponDiscount.toStringAsFixed(0)}', style: p(14, w: FontWeight.w800, color: C.green), maxLines: 1, overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: _removeCoupon,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: C.green.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: C.green),
              ),
            ),
          ]),
        )
      else ...[
        Row(children: [
          Expanded(child: TextField(
            controller: _couponCtrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_couponBusy,
            style: p(14, w: FontWeight.w700, color: Colors.black),
            decoration: InputDecoration(
              hintText: 'COUPON CODE',
              hintStyle: const TextStyle(color: Colors.black26, fontSize: 13, letterSpacing: 1),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.forest)),
            ),
            onChanged: (_) { if (_couponMsg != null) setState(() => _couponMsg = null); },
            onSubmitted: (_) { if (!_couponBusy) _applyCoupon(); },
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _couponBusy ? null : () => _applyCoupon(),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(12)),
              child: _couponBusy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Apply', style: p(14, w: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
        if (_couponMsg != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(_couponMsg!, style: p(12, w: FontWeight.w600, color: Colors.red[400]))),
        if (_couponsLoaded) ..._couponGroups(),
      ],
    ]);
  }

  // Eligible chips first (tap = apply), then "not eligible yet" chips greyed
  // out with the server's reason. Eligibility and savings come from the
  // server response — no client-side min-order guesswork.
  List<Widget> _couponGroups() {
    final rows = _availableCoupons.map((c) => asMap(c)).toList();
    if (rows.isEmpty) return const [];
    final eligible = rows.where((c) => c['eligible'] == true).toList();
    final ineligible = rows.where((c) => c['eligible'] != true).toList();
    return [
      const SizedBox(height: 12),
      if (eligible.isNotEmpty) ...[
        Text('ELIGIBLE COUPONS', style: p(11, w: FontWeight.w800, color: C.green, ls: 0.5)),
        const SizedBox(height: 8),
        _couponRow(eligible),
      ] else
        Text('No coupons eligible yet', style: p(12, w: FontWeight.w600, color: Colors.black38)),
      if (ineligible.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('NOT ELIGIBLE YET', style: p(11, w: FontWeight.w800, color: Colors.black38, ls: 0.5)),
        const SizedBox(height: 8),
        _couponRow(ineligible),
      ],
    ];
  }

  Widget _couponRow(List<Map<String, dynamic>> items) => SizedBox(
        height: 64,
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
    final title = eligible ? '$code · Save ₹${saving.toStringAsFixed(0)}' : code;
    final sub = eligible
        ? (desc.isNotEmpty ? desc : 'Tap to apply')
        : (reason.isNotEmpty ? reason : 'Not eligible yet');
    return GestureDetector(
      onTap: (eligible && !_couponBusy) ? () => _applyCoupon(code) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: eligible ? C.green.withOpacity(0.06) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: eligible ? C.green.withOpacity(0.45) : Colors.black.withOpacity(0.06)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_offer_rounded, size: 13, color: eligible ? C.green : Colors.black26),
            const SizedBox(width: 6),
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(13, w: FontWeight.w800, color: eligible ? C.forest : Colors.black38))),
          ]),
          const SizedBox(height: 3),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(10, w: FontWeight.w600, color: eligible ? C.green : Colors.black38)),
        ]),
      ),
    );
  }
}

// _ModeCard (Instant vs Schedule toggle card) removed with instant booking.
// Restore from git history to re-enable.

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
        : (_isSub ? (_isAnnual ? '/ year' : '/ month') : '/ visit');
    final tagline = asStr(plan['tagline']).isNotEmpty
        ? asStr(plan['tagline'])
        : asStr(plan['plan_summary'], _isSub ? 'best care' : 'on-demand visit');
    final visits = asInt(plan['visits_per_month']);
    final maxPlants = asInt(plan['max_plants']);
    final features = asList(plan['features']).map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    final fg = sel ? Colors.white : Colors.black;
    final fgMuted = sel ? Colors.white60 : Colors.black38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: sel ? C.forest : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: sel ? C.forest : Colors.black.withOpacity(0.08)), boxShadow: [if (sel) BoxShadow(color: C.forest.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (sel ? Colors.white : C.forest).withOpacity(0.12), borderRadius: BorderRadius.circular(16)), child: Icon(_isSub ? Icons.repeat_rounded : Icons.bolt_rounded, color: sel ? Colors.white : C.forest)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asStr(plan['name']), style: p(16, w: FontWeight.w800, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(tagline, style: p(12, color: fgMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${shownPrice.toStringAsFixed(0)}', style: p(18, w: FontWeight.w900, color: sel ? C.gold : C.forest)),
              Text(priceSubtitle, style: p(10, color: fgMuted)),
            ]),
          ]),

          // ── Plan detail so the customer knows what they're getting ──────
          if (_isSub && (visits > 0 || maxPlants > 0)) Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(children: [
              if (visits > 0) _detailPill(Icons.event_repeat_rounded, '$visits visits/mo', sel),
              if (visits > 0 && maxPlants > 0) const SizedBox(width: 8),
              if (maxPlants > 0) _detailPill(Icons.spa_rounded, 'up to $maxPlants plants', sel),
            ]),
          ),
          if (features.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 6, runSpacing: 6, children: features.take(4).map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: (sel ? Colors.white : C.forest).withOpacity(0.08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: (sel ? Colors.white : C.forest).withOpacity(0.16)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_rounded, size: 11, color: sel ? C.gold : C.forest),
                const SizedBox(width: 4),
                Text(f, style: p(10.5, w: FontWeight.w600, color: fg)),
              ]),
            )).toList()),
          ),
        ]),
      ),
    );
  }

  Widget _detailPill(IconData icon, String label, bool sel) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: (sel ? Colors.white : C.forest).withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: (sel ? Colors.white : C.forest).withOpacity(0.14)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: sel ? C.gold : C.forest),
      const SizedBox(width: 5),
      Text(label, style: p(10.5, w: FontWeight.w700, color: sel ? Colors.white : C.t2)),
    ]),
  );
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
