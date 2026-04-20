import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../data/services/api.dart';
import '../theme/theme.dart';
import 'widgets.dart';

class PickedLocation {
  final double lat, lng;
  final String address;
  final String? flatNo, building, area, city, state, pincode;
  final Map<String, dynamic> zone;

  const PickedLocation({
    required this.lat, required this.lng, required this.address,
    this.flatNo, this.building, this.area, this.city, this.state, this.pincode,
    required this.zone,
  });

  String get fullAddress {
    final parts = [
      if (flatNo?.isNotEmpty == true) 'Flat/House: $flatNo',
      if (building?.isNotEmpty == true) 'Building: $building',
      if (area?.isNotEmpty == true) area!,
      address,
    ];
    return parts.join(', ');
  }

  String get label {
    if (flatNo?.isNotEmpty == true) return 'Flat $flatNo, $address'.split(',')[0];
    return address.split(',')[0];
  }
}

Future<PickedLocation?> detectCurrentLocation() async {
  try {
    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (![LocationPermission.whileInUse, LocationPermission.always].contains(perm)) return null;

    final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 8));

    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18');
    final res = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 4));
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};

    final api = Api();
    var zone = <String, dynamic>{};
    try {
      final sRes = await api.checkServiceability(pos.latitude, pos.longitude);
      final data = asMap(sRes);
      zone = asMap(data['zone']);
      if (asInt(zone['id']) == 0) {
        final arr = data['zones'];
        if (arr is List && arr.isNotEmpty) zone = asMap(arr.first);
      }
      if (asInt(zone['id']) == 0 && asBool(data['serviceable'])) {
        zone = {'id': 1, 'name': 'Your Area'};
      }
    } catch (_) {}

    return PickedLocation(
      lat: pos.latitude, lng: pos.longitude,
      address: (j['display_name'] as String?) ?? '${pos.latitude}, ${pos.longitude}',
      city:    (a['city'] ?? a['town'] ?? a['village'] ?? '') as String,
      area:    (a['suburb'] ?? a['neighbourhood'] ?? a['road'] ?? '') as String,
      pincode: (a['postcode'] ?? '') as String,
      state:   (a['state'] ?? '') as String,
      zone: zone,
    );
  } catch (_) { return null; }
}

Future<PickedLocation?> showLocationPicker(BuildContext context) {
  return showModalBottomSheet<PickedLocation>(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => const _LocationPickerSheet(),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();
  @override State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _api = Api();
  int  _step      = 0;
  bool _gpsLoading = false, _geocoding = false;
  double? _lat, _lng;
  String _detectedAddress = '';
  Map<String, dynamic> _detectedZone = {};

  final _flatCtrl     = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _areaCtrl     = TextEditingController();

  bool get _isServiceable => _detectedZone.isNotEmpty && asInt(_detectedZone['id']) > 0;

  @override void initState() { super.initState(); _detectGPS(); }
  @override void dispose() { _flatCtrl.dispose(); _buildingCtrl.dispose(); _areaCtrl.dispose(); super.dispose(); }

  Future<void> _detectGPS() async {
    setState(() => _gpsLoading = true);
    try {
      final svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) { if (mounted) await Geolocator.openLocationSettings(); setState(() => _gpsLoading = false); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (![LocationPermission.whileInUse, LocationPermission.always].contains(perm)) { setState(() => _gpsLoading = false); return; }

      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 3));

      if (!mounted) return;
      _lat = pos.latitude; _lng = pos.longitude;
      setState(() { _gpsLoading = false; _geocoding = true; });
      await _reverseGeocode(_lat!, _lng!);
    } catch (_) {
      if (mounted) setState(() { _gpsLoading = false; _geocoding = false; _detectedAddress = 'Location detected via GPS'; });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18');
      final res = await http.get(uri, headers: {'Accept-Language': 'en'}).timeout(const Duration(seconds: 4));
      final j   = jsonDecode(res.body) as Map<String, dynamic>;
      try {
        final sRes    = await _api.checkServiceability(lat, lng);
        final data    = asMap(sRes);
        // Try zone object directly (backend returns data.zone)
        var zone      = asMap(data['zone']);
        // Fallback: first element of zones array
        if (asInt(zone['id']) == 0) {
          final arr = data['zones'];
          if (arr is List && arr.isNotEmpty) zone = asMap(arr.first);
        }
        // Fallback: if backend says serviceable but zone missing, use placeholder
        if (asInt(zone['id']) == 0 && asBool(data['serviceable'])) {
          zone = {'id': 1, 'name': 'Your Area'};
        }
        _detectedZone = zone;
        debugPrint('Zone result: $_detectedZone');
      } catch (e) { debugPrint('Serviceability error: $e'); }
      if (mounted) setState(() { _detectedAddress = (j['display_name'] as String?) ?? '$lat, $lng'; _geocoding = false; });
    } catch (_) {
      if (mounted) setState(() { _geocoding = false; _detectedAddress = '$_lat, $_lng'; });
    }
  }

  void _onSaveAll() {
    if (_lat == null) return;
    Navigator.pop(context, PickedLocation(
      lat: _lat!, lng: _lng!,
      address: _detectedAddress,
      flatNo:   _flatCtrl.text.trim(),
      building: _buildingCtrl.text.trim(),
      area:     _areaCtrl.text.trim(),
      zone:     _detectedZone,
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    final bottom = MediaQuery.of(ctx).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: AnimatedSwitcher(duration: 300.ms, child: _step == 0 ? _buildDetect() : _buildDetails()),
    );
  }

  // ── Step 0: GPS detect ──────────────────────────────────────────────────────
  Widget _buildDetect() => Column(key: const ValueKey(0), mainAxisSize: MainAxisSize.min, children: [
    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
    const SizedBox(height: 28),
    const Icon(Icons.location_searching_rounded, size: 44, color: C.forest),
    const SizedBox(height: 12),
    Text('Your Location', style: p(20, w: FontWeight.w800, color: C.t1)),
    const SizedBox(height: 6),
    Text('Detecting via GPS', style: p(13, color: C.t3)),
    const SizedBox(height: 28),

    if (_gpsLoading || _geocoding)
      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator(color: C.forest))
    else ...[
      if (_detectedAddress.isNotEmpty)
        _LocTile(icon: Icons.place_rounded, text: _detectedAddress),

      const SizedBox(height: 10),

      if (_isServiceable)
        _Badge(icon: Icons.check_circle_rounded, color: C.green, text: 'Service available in ${asStr(_detectedZone['name'])}')
      else
        _Badge(icon: Icons.info_outline_rounded, color: Colors.orange, text: 'GPS location may not be in our service zone. You can enter your address manually below.'),

      const SizedBox(height: 24),
      GBtn(
        label: _isServiceable ? 'Confirm & Add Details' : 'Enter Address Manually',
        onTap: () => setState(() => _step = 1),
        bg: C.forest,
      ),
    ],
    const SizedBox(height: 10),
  ]);

  // ── Step 1: Address details ─────────────────────────────────────────────────
  Widget _buildDetails() => Column(key: const ValueKey(1), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      GestureDetector(onTap: () => setState(() => _step = 0), child: const Icon(Icons.arrow_back_rounded, color: C.t1)),
      const SizedBox(width: 14),
      Text('Address Details', style: p(18, w: FontWeight.w800, color: C.t1)),
    ]),
    if (_detectedAddress.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(left: 38, top: 4),
        child: Text(_detectedAddress.split(',').take(2).join(','), style: p(12, color: C.t3), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    if (!_isServiceable)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _Badge(icon: Icons.warning_amber_rounded, color: Colors.orange, text: 'This area may not be in our service zone yet. We\'ll confirm after booking.'),
      ),

    const SizedBox(height: 20),
    _SheetField(ctrl: _flatCtrl,     label: 'Flat / House No.',      hint: 'e.g. 101 or B-402',         icon: Icons.home_rounded),
    const SizedBox(height: 12),
    _SheetField(ctrl: _buildingCtrl, label: 'Building / Apartment',  hint: 'e.g. Green Valley Apts',    icon: Icons.apartment_rounded),
    const SizedBox(height: 12),
    _SheetField(ctrl: _areaCtrl,     label: 'Landmark / Area',       hint: 'e.g. Near Central Park',    icon: Icons.place_outlined),
    const SizedBox(height: 28),
    GBtn(label: 'Save Address', onTap: _onSaveAll, bg: C.forest),
    const SizedBox(height: 8),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Clean input: one Container (bg + border), TextField with all decoration stripped
// ─────────────────────────────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  const _SheetField({required this.ctrl, required this.label, required this.hint, required this.icon});

  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: p(12, w: FontWeight.w600, color: C.t3)),
    const SizedBox(height: 6),
    Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F0),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: C.border, width: 1.2),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(icon, size: 18, color: C.forest.withOpacity(0.55)),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: ctrl,
          style: p(14, w: FontWeight.w600, color: C.t1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: C.t4, fontSize: 13),
            border:             InputBorder.none,
            enabledBorder:      InputBorder.none,
            focusedBorder:      InputBorder.none,
            errorBorder:        InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder:     InputBorder.none,
            filled:             false,
            isDense:            true,
            contentPadding:     EdgeInsets.zero,
          ),
        )),
      ]),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────
class _LocTile extends StatelessWidget {
  final IconData icon; final String text;
  const _LocTile({required this.icon, required this.text});
  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F0),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: C.border, width: 1.2),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: C.forest, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: p(13, color: C.t2, h: 1.45), maxLines: 3, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _Badge({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext ctx) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: p(12, w: FontWeight.w600, color: color, h: 1.45))),
    ]),
  );
}
