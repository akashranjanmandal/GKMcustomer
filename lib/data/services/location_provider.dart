import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gharkamali/presentation/widgets/location_picker_sheet.dart';
import 'package:gharkamali/data/services/api.dart' as api_svc;

const _kLocKey = 'gkm_locations';
const _kIdxKey = 'gkm_loc_idx';
const _kGeoKey = 'gkm_geofences';

class LocationProvider extends ChangeNotifier {
  List<PickedLocation> _locations = [];
  List<dynamic> _geofences = [];
  int _currentIndex = -1;
  bool _loading = true;

  List<PickedLocation> get locations => _locations;
  PickedLocation? get location => _currentIndex >= 0 && _currentIndex < _locations.length ? _locations[_currentIndex] : null;
  bool get loading => _loading;
  bool get hasLocation => location != null;

  double get lat => location?.lat ?? 0.0;
  double get lng => location?.lng ?? 0.0;
  int? get zoneId => location?.zone != null ? (int.tryParse(location!.zone['id'].toString())) : null;

  String get fullAddress {
    if (location == null) return 'Select Delivery Address';
    // Build from structured user-provided fields — these are always clean
    final parts = <String>[
      if (location!.flatNo?.isNotEmpty == true) 'Flat ${location!.flatNo}',
      if (location!.building?.isNotEmpty == true) location!.building!,
      if (location!.area?.isNotEmpty == true) location!.area!,
      if (location!.city?.isNotEmpty == true) location!.city!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    // Fallback: sanitize the raw geocoded address (may contain coordinates)
    return _sanitizeRawAddress(location!.address);
  }

  String _sanitizeRawAddress(String? s) {
    if (s == null || s.trim().isEmpty) return 'Current Location';
    final reg = RegExp(r'-?\d{1,3}\.\d{5,}');
    if (reg.allMatches(s).length >= 2) return 'Current Location';
    return s.trim();
  }

  // Raw address for API
  String get shippingAddress => location?.address ?? '';
  String get city => location?.city ?? '';
  String get pincode => location?.pincode ?? '';

  bool get isGpsLocation => location?.label == _kGpsLabel;

  String get label {
    if (location == null) return 'Select Location';
    final parts = <String>[
      if (location!.area?.isNotEmpty == true) location!.area!,
      if (location!.city?.isNotEmpty == true) location!.city!,
    ];
    final s = parts.isNotEmpty ? parts.join(', ') : _sanitizeRawAddress(location!.address);
    return s.length > 28 ? '${s.substring(0, 28)}…' : s;
  }

  LocationProvider() { _hydrate(); }

  Future<void> _hydrate() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kLocKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _locations = list.map((e) => _fromMap(Map<String, dynamic>.from(e))).toList();
      }

      final rawGeo = p.getString(_kGeoKey);
      if (rawGeo != null) {
        _geofences = jsonDecode(rawGeo) as List;
      }

      _currentIndex = p.getInt(_kIdxKey) ?? (_locations.isNotEmpty ? 0 : -1);
      
      // Also fetch from server to sync
      await fetchSavedAddresses();

      // If any location is still missing a zone, try to find it from the fetched geofences
      for (var i = 0; i < _locations.length; i++) {
        if (_locations[i].zone.isEmpty) {
          final zone = _findZone(_locations[i].lat, _locations[i].lng);
          if (zone.isNotEmpty) {
            _locations[i] = _locations[i].copyWith(zone: zone);
          }
        }
      }

      _loading = false;
      notifyListeners();
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSavedAddresses() async {
    try {
      final api = api_svc.Api();
      
      // Fetch both addresses and geofences
      final results = await Future.wait([
        api.getMyAddresses().catchError((_) => []),
        api.getGeofences().catchError((_) => []),
      ]);

      if (results[1] is List) {
        _geofences = results[1] as List;
        final p = await SharedPreferences.getInstance();
        await p.setString(_kGeoKey, jsonEncode(_geofences));
      }

      if (results[0] is List) {
        final res = results[0] as List;
        final serverLocs = await Future.wait(res.map((e) async {
          final m = api_svc.asMap(e);
          final loc = _fromServerMap(m);

          // 1. Try to reuse zone from local cache (exact coordinate match)
          final localMatch = _locations.firstWhere(
            (l) => (l.lat - loc.lat).abs() < 0.000001 && (l.lng - loc.lng).abs() < 0.000001 && l.zone.isNotEmpty,
            orElse: () => loc,
          );
          if (localMatch.zone.isNotEmpty) return loc.copyWith(zone: localMatch.zone);

          // 2. Try local polygon lookup against cached geofences
          final polyZone = _findZone(loc.lat, loc.lng);
          if (polyZone.isNotEmpty) return loc.copyWith(zone: polyZone);

          // 3. Hit the serviceability API directly (most reliable)
          try {
            final sRes = await api.checkServiceability(loc.lat, loc.lng);
            final data = api_svc.asMap(sRes);
            final apiZone = api_svc.asMap(data['zone']);
            if (apiZone.isNotEmpty) return loc.copyWith(zone: apiZone);
          } catch (_) {}

          return loc; // zone stays empty — location not serviceable
        }).toList());

        if (serverLocs.isNotEmpty) {
          final current = location;
          _locations = serverLocs;

          if (current != null) {
            final newIdx = _locations.indexWhere((l) => (l.lat - current.lat).abs() < 0.000001 && (l.lng - current.lng).abs() < 0.000001);
            if (newIdx != -1) _currentIndex = newIdx;
          }

          if (_currentIndex >= _locations.length) _currentIndex = _locations.length - 1;
          if (_currentIndex == -1 && _locations.isNotEmpty) _currentIndex = 0;
        }
        notifyListeners();
      }
    } catch (e) { }
  }

  Map<String, dynamic> _findZone(double lat, double lng) {
    for (var z in _geofences) {
      final zone = api_svc.asMap(z);
      final coordsStr = api_svc.asStr(zone['polygon_coords']);
      if (coordsStr.isEmpty) continue;
      try {
        final poly = jsonDecode(coordsStr) as List;
        if (isPointInPolygon(lat, lng, poly)) return zone;
      } catch (_) {}
    }
    return {};
  }

  Future<void> selectIndex(int i) async {
    if (i >= 0 && i < _locations.length) {
      _currentIndex = i;
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kIdxKey, _currentIndex);
      
      // If the selected address has an ID, we can notify the server if needed
      // but usually selecting is just local state
      notifyListeners();
    }
  }

  // Update zone for whichever location is currently selected (used after re-check)
  void updateZoneForCurrent(Map<String, dynamic> zone) {
    if (_currentIndex >= 0 && _currentIndex < _locations.length) {
      _locations[_currentIndex] = _locations[_currentIndex].copyWith(zone: zone);
      notifyListeners();
    }
  }

  Future<void> save(PickedLocation loc) async {
    // Check if duplicate (by lat/lng or address)
    final existingIdx = _locations.indexWhere((e) => 
      (e.lat == loc.lat && e.lng == loc.lng) || e.address == loc.address
    );

    if (existingIdx != -1) {
      _locations[existingIdx] = loc;
      _currentIndex = existingIdx;
    } else {
      _locations.add(loc);
      _currentIndex = _locations.length - 1;
    }

    // Persist Locally
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocKey, jsonEncode(_locations.map((e) => _toMap(e)).toList()));
    await p.setInt(_kIdxKey, _currentIndex);
    notifyListeners();

    // Persist to Server
    try {
      final api = api_svc.Api();
      await api.addAddress({
        'label': (loc.building?.isNotEmpty == true ? loc.building : loc.area) ?? 'Home',
        'flat_no': loc.flatNo,
        'building': loc.building,
        'area': loc.area,
        'landmark': loc.landmark ?? loc.address, // Send full address as landmark fallback
        'city': loc.city,
        'state': loc.state,
        'pincode': loc.pincode,
        'latitude': loc.lat,
        'longitude': loc.lng,
        'zone_id': api_svc.asInt(loc.zone['id']),
        'geofence_id': loc.geofenceId ?? api_svc.asInt(loc.zone['id']),
        'is_default': _locations.length == 1,
      });
    } catch (e) { }
  }

  Future<void> remove(int index) async {
    if (index >= 0 && index < _locations.length) {
      final loc = _locations[index];
      
      _locations.removeAt(index);
      if (_currentIndex >= _locations.length) {
        _currentIndex = _locations.length - 1;
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLocKey, jsonEncode(_locations.map((e) => _toMap(e)).toList()));
      await p.setInt(_kIdxKey, _currentIndex);
      notifyListeners();

      // Attempt server delete if we have an ID
      if (loc.id != null) {
        try {
          final api = api_svc.Api();
          await api.deleteAddress(loc.id!);
        } catch (e) { }
      }
    }
  }

  Future<void> clear() async {
    _locations = [];
    _currentIndex = -1;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLocKey);
    await p.remove(_kIdxKey);
    notifyListeners();
  }

  // GPS label used to identify the auto-detected slot
  static const _kGpsLabel = '__gps__';

  Future<void> autoDetect() async {
    try {
      final loc = await detectCurrentLocation();
      if (loc == null) return;
      final gpsLoc = loc.copyWith(label: _kGpsLabel);

      // Find existing GPS slot and update it, or insert at index 0
      final existingIdx = _locations.indexWhere((l) => l.label == _kGpsLabel);
      if (existingIdx != -1) {
        _locations[existingIdx] = gpsLoc;
        // Only switch to GPS slot if user hasn't manually selected another
        if (_currentIndex == existingIdx) {
          _currentIndex = existingIdx;
        } else if (_locations[_currentIndex].label == _kGpsLabel) {
          _currentIndex = existingIdx;
        }
      } else {
        final hadNoLocation = _locations.isEmpty;
        _locations.insert(0, gpsLoc);
        if (hadNoLocation) {
          // First time: select GPS location
          _currentIndex = 0;
        } else {
          // Shift existing selection index since we inserted at 0
          _currentIndex = (_currentIndex + 1).clamp(0, _locations.length - 1);
        }
      }

      final p = await SharedPreferences.getInstance();
      await p.setString(_kLocKey, jsonEncode(_locations.map((e) => _toMap(e)).toList()));
      await p.setInt(_kIdxKey, _currentIndex);
      notifyListeners();
    } catch (_) {}
  }

  static Map<String, dynamic> _toMap(PickedLocation l) => {
    'id': l.id,
    'label': l.label,
    'lat': l.lat, 'lng': l.lng, 'address': l.address,
    'flatNo': l.flatNo, 'building': l.building, 'area': l.area,
    'landmark': l.landmark,
    'city': l.city, 'state': l.state, 'pincode': l.pincode,
    'zone': l.zone,
    'geofenceId': l.geofenceId,
  };

  static PickedLocation _fromMap(Map<String, dynamic> m) => PickedLocation(
    id: api_svc.asInt(m['id']) > 0 ? api_svc.asInt(m['id']) : null,
    label: m['label'] as String?,
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    address: m['address'] as String? ?? '',
    flatNo: m['flatNo'] as String?,
    building: m['building'] as String?,
    area: m['area'] as String?,
    landmark: m['landmark'] as String?,
    city: m['city'] as String?,
    state: m['state'] as String?,
    pincode: m['pincode'] as String?,
    zone: (m['zone'] as Map?)?.cast<String, dynamic>() ?? {},
    geofenceId: api_svc.asInt(m['geofenceId']) > 0 ? api_svc.asInt(m['geofenceId']) : null,
  );

  static PickedLocation _fromServerMap(Map<String, dynamic> m) {
    String addr = api_svc.asStr(m['landmark']);
    if (addr.isEmpty || !addr.contains(',')) {
      final parts = [
        if (api_svc.asStr(m['flat_no']).isNotEmpty) api_svc.asStr(m['flat_no']),
        if (api_svc.asStr(m['building']).isNotEmpty) api_svc.asStr(m['building']),
        if (api_svc.asStr(m['area']).isNotEmpty) api_svc.asStr(m['area']),
        if (api_svc.asStr(m['city']).isNotEmpty) api_svc.asStr(m['city']),
      ];
      addr = parts.isNotEmpty ? parts.join(', ') : 'Saved Address';
    }

    return PickedLocation(
      id: api_svc.asInt(m['id']),
      label: api_svc.asStr(m['label']),
      lat: api_svc.asDouble(m['latitude']),
      lng: api_svc.asDouble(m['longitude']),
      address: addr,
      flatNo: api_svc.asStr(m['flat_no']),
      building: api_svc.asStr(m['building']),
      area: api_svc.asStr(m['area']),
      landmark: api_svc.asStr(m['landmark']),
      city: api_svc.asStr(m['city']),
      state: api_svc.asStr(m['state']),
      pincode: api_svc.asStr(m['pincode']),
      zone: {}, 
    );
  }
}
