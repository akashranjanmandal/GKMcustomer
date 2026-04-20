import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../presentation/widgets/location_picker_sheet.dart';

const _kLocKey = 'gkm_location';

class LocationProvider extends ChangeNotifier {
  PickedLocation? _location;
  bool _loading = true;

  PickedLocation? get location => _location;
  bool get loading => _loading;
  bool get hasLocation => _location != null;

  double get lat => _location?.lat ?? 0.0;
  double get lng => _location?.lng ?? 0.0;
  int? get zoneId => _location?.zone != null ? (int.tryParse(_location!.zone['id'].toString())) : null;

  String get fullAddress {
    if (_location == null) return 'Select Delivery Address';
    final parts = [
      if (_location!.flatNo?.isNotEmpty == true) 'Flat/House: ${_location!.flatNo}',
      if (_location!.building?.isNotEmpty == true) 'Building: ${_location!.building}',
      if (_location!.area?.isNotEmpty == true) _location!.area,
      if (_location!.city?.isNotEmpty == true) _location!.city,
    ];
    return parts.isNotEmpty ? parts.join(', ') : _location!.address;
  }

  // Raw address for API
  String get shippingAddress => _location?.address ?? '';
  String get city => _location?.city ?? '';
  String get pincode => _location?.pincode ?? '';

  String get label {
    if (_location == null) return 'Select Location';
    final parts = [
      if (_location!.area?.isNotEmpty == true) _location!.area!,
      if (_location!.city?.isNotEmpty == true) _location!.city!,
    ];
    final s = parts.isNotEmpty ? parts.join(', ') : _location!.address;
    return s.length > 30 ? '${s.substring(0, 30)}…' : s;
  }

  LocationProvider() { _hydrate(); }

  Future<void> _hydrate() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kLocKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _location = _fromMap(m);
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> save(PickedLocation loc) async {
    _location = loc;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocKey, jsonEncode(_toMap(loc)));
    notifyListeners();
  }

  Future<void> clear() async {
    _location = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLocKey);
    notifyListeners();
  }

  Future<void> autoDetect() async {
    try {
      final loc = await detectCurrentLocation();
      if (loc != null) save(loc);
    } catch (_) {}
  }

  static Map<String, dynamic> _toMap(PickedLocation l) => {
    'lat': l.lat, 'lng': l.lng, 'address': l.address,
    'flatNo': l.flatNo, 'building': l.building, 'area': l.area,
    'city': l.city, 'state': l.state, 'pincode': l.pincode,
    'zone': l.zone,
  };

  static PickedLocation _fromMap(Map<String, dynamic> m) => PickedLocation(
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    address: m['address'] as String? ?? '',
    flatNo: m['flatNo'] as String?,
    building: m['building'] as String?,
    area: m['area'] as String?,
    city: m['city'] as String?,
    state: m['state'] as String?,
    pincode: m['pincode'] as String?,
    zone: (m['zone'] as Map?)?.cast<String, dynamic>() ?? {},
  );
}
