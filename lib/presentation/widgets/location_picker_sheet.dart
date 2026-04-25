import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/services/api.dart';
import '../../data/services/location_provider.dart';
import '../theme/theme.dart';
import 'widgets.dart';

class PickedLocation {
  final int? id;
  final String? label;
  final double lat, lng;
  final String address;
  final String? flatNo, building, area, landmark, city, state, pincode;
  final Map<String, dynamic> zone;
  final int? geofenceId;

  const PickedLocation({
    this.id, this.label,
    required this.lat, required this.lng, required this.address,
    this.flatNo, this.building, this.area, this.landmark, this.city, this.state, this.pincode,
    required this.zone, this.geofenceId,
  });

  PickedLocation copyWith({
    int? id, String? label, double? lat, double? lng, String? address,
    String? flatNo, String? building, String? area, String? landmark, String? city, String? state, String? pincode,
    Map<String, dynamic>? zone,
  }) => PickedLocation(
    id: id ?? this.id, label: label ?? this.label,
    lat: lat ?? this.lat, lng: lng ?? this.lng, address: address ?? this.address,
    flatNo: flatNo ?? this.flatNo, building: building ?? this.building, area: area ?? this.area,
    landmark: landmark ?? this.landmark, city: city ?? this.city, state: state ?? this.state, pincode: pincode ?? this.pincode,
    zone: zone ?? this.zone,
  );

  String get fullAddress {
    final parts = <String>[
      if (flatNo?.isNotEmpty == true) 'Flat $flatNo',
      if (building?.isNotEmpty == true) building!,
      if (area?.isNotEmpty == true) area!,
      if (city?.isNotEmpty == true) city!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    // Fallback to address if no structured fields
    return address.isNotEmpty ? address : 'Current Location';
  }

  String get displayLabel {
    if (label != null && label!.isNotEmpty && label != '__gps__') return label!;
    if (flatNo?.isNotEmpty == true) return 'Flat $flatNo, ${area ?? address}'.split(',').first;
    if (area?.isNotEmpty == true) return area!;
    return address.split(',').first;
  }
}

// Utility for point-in-polygon check
bool isPointInPolygon(double lat, double lng, List<dynamic> poly) {
  if (poly.isEmpty) return false;

  // Recursively find the actual points array (handles standard GeoJSON [[[lng, lat], ...]])
  List<dynamic> points = poly;
  while (points.isNotEmpty && points[0] is List && points[0].isNotEmpty && points[0][0] is List) {
    points = points[0] as List;
  }

  if (points.isEmpty || points.length < 3) return false;

  bool check(double y, double x, List<dynamic> p, int yIdx, int xIdx) {
    bool inside = false;
    final n = p.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final vi = p[i] as List; final vj = p[j] as List;
      // Safety checks for point data
      if (vi.length <= yIdx || vi.length <= xIdx || vj.length <= yIdx || vj.length <= xIdx) continue;
      
      final yi = (vi[yIdx] as num).toDouble();
      final xi = (vi[xIdx] as num).toDouble();
      final yj = (vj[yIdx] as num).toDouble();
      final xj = (vj[xIdx] as num).toDouble();
      
      final intersect = ((yi > y) != (yj > y)) && 
                        (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // Try GeoJSON [lng, lat] (Standard)
  if (check(lat, lng, points, 1, 0)) return true;
  // Fallback to [lat, lng]
  return check(lat, lng, points, 0, 1);
}

Future<PickedLocation?> detectCurrentLocation() async {
  try {
    print('>>> [LocationDetection] Starting detection...');
    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) {
      print('>>> [LocationDetection] FAILED: Location services are disabled on device');
      return null;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      print('>>> [LocationDetection] Permission denied, requesting...');
      perm = await Geolocator.requestPermission();
    }
    if (![LocationPermission.whileInUse, LocationPermission.always].contains(perm)) {
      print('>>> [LocationDetection] FAILED: Location permission not granted ($perm)');
      return null;
    }

    Position pos;
    try {
      print('>>> [LocationDetection] Getting current position...');
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10));
    } catch (e) {
      print('>>> [LocationDetection] getCurrentPosition failed ($e), trying last known...');
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        pos = last;
      } else {
        print('>>> [LocationDetection] No last known position, trying low accuracy...');
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 10));
      }
    }

    print('>>> [LocationDetection] Found coordinates: ${pos.latitude}, ${pos.longitude}');
    
    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18');
    print('>>> [LocationDetection] Fetching address from Nominatim...');
    final res = await http.get(uri, headers: {'Accept-Language': 'en', 'User-Agent': 'GharKaMali/1.0'}).timeout(const Duration(seconds: 8));

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};

    final road   = (a['road'] ?? a['footway'] ?? '').toString().trim();
    final suburb = (a['suburb'] ?? a['neighbourhood'] ?? a['quarter'] ?? '').toString().trim();
    final city   = (a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '').toString().trim();

    final addrParts = <String>[
      if (road.isNotEmpty) road,
      if (suburb.isNotEmpty) suburb,
      if (city.isNotEmpty) city,
    ].where((s) => s.isNotEmpty).toList();
    String addr = addrParts.isNotEmpty ? addrParts.join(', ') : (suburb.isNotEmpty ? suburb : city.isNotEmpty ? city : 'Current Location');

    final api = Api();
    print('>>> [LocationDetection] Checking serviceability for: ${pos.latitude}, ${pos.longitude}');
    final sRes = await api.checkServiceability(pos.latitude, pos.longitude);
    final data = asMap(sRes);
    
    // Trust the backend's resolved zone first
    Map<String, dynamic> found = asMap(data['zone']);
    if (found.isNotEmpty) {
      print('>>> [LocationDetection] Backend matched zone: ${found['name']} (ID: ${found['id']})');
    } else {
      print('>>> [LocationDetection] Backend found NO matching zone. Attempting local fallback check...');
      final allZones = data['zones'] as List? ?? [];
      for (var z in allZones) {
        final zone = asMap(z);
        final poly = asList(zone['polygon_coords']);
        if (poly.isNotEmpty && isPointInPolygon(pos.latitude, pos.longitude, poly)) {
          found = zone;
          print('>>> [LocationDetection] Local fallback matched: ${found['name']}');
          break;
        }
      }
    }

    if (found.isEmpty) {
      print('>>> [LocationDetection] WARNING: No matching zone found for these coordinates.');
    }

    return PickedLocation(
      lat: pos.latitude, lng: pos.longitude,
      address: addr,
      city:    city,
      area:    suburb.isNotEmpty ? suburb : road,
      pincode: (a['postcode'] ?? '').toString(),
      state:   (a['state'] ?? '').toString(),
      zone:    found,
    );
  } catch (e) { 
    print('>>> [LocationDetection] CRITICAL ERROR: $e');
    return null; 
  }
}

Future<PickedLocation?> showLocationPicker(BuildContext context) {
  return showModalBottomSheet<PickedLocation>(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => const _LocationPickerSheet(),
  );
}

Future<PickedLocation?> showSavedLocations(BuildContext context) {
  return showModalBottomSheet<PickedLocation>(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => const _SavedLocationsSheet(),
  );
}

class _SavedLocationsSheet extends StatelessWidget {
  const _SavedLocationsSheet();
  @override
  Widget build(BuildContext ctx) {
    final lp = ctx.watch<LocationProvider>();
    final bottom = MediaQuery.of(ctx).padding.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Saved Addresses', style: p(20, w: FontWeight.w800, color: C.t1)),
          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: C.t3)),
        ]),
        const SizedBox(height: 16),
        
        // Add New Address Button
        GestureDetector(
          onTap: () async {
            final res = await showLocationPicker(ctx);
            if (res != null && ctx.mounted) {
              lp.save(res);
              Navigator.pop(ctx, res);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.forest.withOpacity(0.3), width: 1.5, style: BorderStyle.solid),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.add_circle_outline_rounded, color: C.forest, size: 20),
              const SizedBox(width: 10),
              Text('Add New Address', style: p(14, w: FontWeight.w700, color: C.forest)),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        Flexible(child: ListView.builder(
          shrinkWrap: true, itemCount: lp.locations.length,
          itemBuilder: (_, i) {
            final loc = lp.locations[i]; final sel = lp.location == loc;
            return GestureDetector(
              onTap: () { lp.selectIndex(i); Navigator.pop(ctx, loc); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel ? C.forest.withOpacity(0.04) : const Color(0xFFF8FBF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? C.forest : Colors.black.withOpacity(0.04)),
                ),
                child: Row(children: [
                  Icon(loc.label == '__gps__' ? Icons.my_location_rounded : Icons.place_rounded,
                      color: sel ? C.forest : C.t4, size: 20),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(loc.label == '__gps__' ? 'Current Location' : loc.displayLabel,
                        style: p(14, w: FontWeight.w700, color: sel ? C.forest : C.t1)),
                    Text(loc.address.isEmpty ? 'Detected via GPS' : loc.address,
                        style: p(12, color: C.t3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  if (sel) const Icon(Icons.check_circle_rounded, color: C.forest, size: 18),
                  if (loc.label != '__gps__')
                    IconButton(onPressed: () => lp.remove(i), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent)),
                ]),
              ),
            );
          },
        )),
        if (lp.locations.isEmpty) ...[
          const SizedBox(height: 12),
          GBtn(label: 'Choose from Map', icon: Icons.map_rounded, onTap: () async {
            final res = await showLocationPicker(ctx);
            if (res != null && ctx.mounted) {
              lp.save(res);
              Navigator.pop(ctx, res);
            }
          }, bg: C.forest),
        ],
      ]),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();
  @override State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _api = Api();
  int  _step      = 0; // 0: Search, 1: Map, 2: Details
  bool _gpsLoading = false, _geocoding = false, _searching = false;
  double? _lat, _lng;
  String _detectedAddress = '';
  Map<String, dynamic> _detectedZone = {};

  final _searchCtrl   = TextEditingController();
  final _flatCtrl     = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _areaCtrl     = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _stateCtrl    = TextEditingController();
  final _pincodeCtrl  = TextEditingController();
  List<dynamic> _searchResults = [];

  final _mapCtrl = MapController();
  LatLng? _mapTarget;

  Timer? _mapIdleTimer;
  Timer? _searchDebounce;

  bool get _isServiceable => _detectedZone.isNotEmpty && asInt(_detectedZone['id']) > 0;

  @override void initState() { super.initState(); _detectGPS(); }
  @override void dispose() {
    _mapIdleTimer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _flatCtrl.dispose();
    _buildingCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectGPS() async {
    setState(() { _gpsLoading = true; _searchResults = []; });
    try {
      final svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) { if (mounted) await Geolocator.openLocationSettings(); setState(() => _gpsLoading = false); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (![LocationPermission.whileInUse, LocationPermission.always].contains(perm)) { setState(() => _gpsLoading = false); return; }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 15));
      }

      if (!mounted || pos == null) { setState(() => _gpsLoading = false); return; }
      _lat = pos.latitude; _lng = pos.longitude;
      _mapTarget = LatLng(_lat!, _lng!);
      if (_step == 1) _mapCtrl.move(_mapTarget!, 17);
      setState(() { _gpsLoading = false; _geocoding = true; });
      await _reverseGeocode(_lat!, _lng!);
      // Auto-advance to map step when GPS succeeds in the search step
      if (mounted && _step == 0 && _isServiceable) {
        setState(() => _step = 1);
      }
    } catch (_) {
      if (mounted) setState(() { _gpsLoading = false; _geocoding = false; });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.length < 3) {
      if (_searchResults.isNotEmpty) setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _searchAddress(query));
  }

  Future<void> _searchAddress(String query) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(query)}&limit=8&addressdetails=1&countrycodes=in');
      final res = await http.get(uri, headers: {'Accept-Language': 'en', 'User-Agent': 'GharKaMali/1.0'}).timeout(const Duration(seconds: 8));
      final j   = jsonDecode(res.body) as List;
      if (mounted) setState(() { _searchResults = j; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectSearchResult(dynamic item) async {
    final m = asMap(item);
    _lat = double.tryParse(asStr(m['lat']));
    _lng = double.tryParse(asStr(m['lon']));
    _detectedAddress = asStr(m['display_name']);
    if (_lat != null && _lng != null) {
      _mapTarget = LatLng(_lat!, _lng!);
      setState(() { _step = 1; _searchResults = []; _searchCtrl.clear(); _geocoding = true; });
      await _reverseGeocode(_lat!, _lng!);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final zoneFuture = _checkZone(lat, lng);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18');
      final res = await http.get(uri, headers: {'Accept-Language': 'en', 'User-Agent': 'GharKaMali/1.0'}).timeout(const Duration(seconds: 8));
      final j   = jsonDecode(res.body) as Map<String, dynamic>;
      final a   = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};

      final road     = (a['road'] ?? a['footway'] ?? '').toString().trim();
      final suburb   = (a['suburb'] ?? a['neighbourhood'] ?? a['quarter'] ?? '').toString().trim();
      final city     = (a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '').toString().trim();
      final state    = (a['state'] ?? '').toString().trim();
      final postcode = (a['postcode'] ?? '').toString().trim();

      // Build a clean human-readable address without coordinates
      final addrParts = <String>[
        if (road.isNotEmpty) road,
        if (suburb.isNotEmpty) suburb,
        if (city.isNotEmpty) city,
      ].where((s) => s.isNotEmpty).toList();
      final addr = addrParts.isNotEmpty ? addrParts.join(', ') : (suburb.isNotEmpty ? suburb : city.isNotEmpty ? city : 'Current Location');

      await zoneFuture;
      if (mounted) setState(() {
        _detectedAddress = addr;
        _areaCtrl.text    = suburb.isNotEmpty ? suburb : road;
        _cityCtrl.text    = city;
        _stateCtrl.text   = state;
        _pincodeCtrl.text = postcode;
        _geocoding = false;
      });
    } catch (_) {
      await zoneFuture;
      if (mounted) setState(() { _geocoding = false; if (_detectedAddress.isEmpty) _detectedAddress = 'Current Location'; });
    }
  }

  Future<void> _checkZone(double lat, double lng) async {
    try {
      print('>>> [ZoneCheck] Checking: $lat, $lng');
      final sRes = await _api.checkServiceability(lat, lng);
      final data = asMap(sRes);
      print('>>> [ZoneCheck] Backend raw response keys: ${data.keys.toList()}');
      print('>>> [ZoneCheck] serviceable=${data["serviceable"]}, zone=${data["zone"]}');
      
      // Trust the backend's resolved zone first
      Map<String, dynamic> found = asMap(data['zone']);
      
      if (found.isNotEmpty) {
        print('>>> [ZoneCheck] Backend matched: ${found["name"]} (id=${found["id"]})');
      } else {
        print('>>> [ZoneCheck] Backend found no zone. Attempting local polygon check...');
        final allZones = asList(data['zones']);
        print('>>> [ZoneCheck] Local check against ${allZones.length} zones');
        for (var z in allZones) {
          final zone = asMap(z);
          final poly = asList(zone['polygon_coords']);
          print('>>> [ZoneCheck]   Zone "${zone["name"]}" has ${poly.length} polygon points');
          if (poly.isNotEmpty && isPointInPolygon(lat, lng, poly)) {
            found = zone;
            print('>>> [ZoneCheck] Local match: ${found["name"]}');
            break;
          }
        }
        if (found.isEmpty) {
          print('>>> [ZoneCheck] WARNING: No zone matched for ($lat, $lng). Not serviceable.');
        }
      }

      if (mounted) setState(() => _detectedZone = found);
    } catch (e, stack) { 
      print('>>> [ZoneCheck] ERROR: $e');
      print('>>> [ZoneCheck] Stack: $stack');
    }
  }


  void _onSaveAll() {
    Navigator.pop(context, PickedLocation(
      lat: _lat!, lng: _lng!,
      address: _detectedAddress,
      flatNo:   _flatCtrl.text.trim(),
      building: _buildingCtrl.text.trim(),
      area:     _areaCtrl.text.trim(),
      city:     _cityCtrl.text.trim(),
      state:    _stateCtrl.text.trim(),
      pincode:  _pincodeCtrl.text.trim(),
      zone:     _detectedZone,
      geofenceId: asInt(_detectedZone['id']),
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * (_step == 1 ? 0.95 : 0.9)),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_step != 1) ...[
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
          ],
          Flexible(child: AnimatedSwitcher(duration: 300.ms, child: _renderStep())),
        ]),
      ),
    );
  }

  Widget _renderStep() {
    switch (_step) {
      case 0: return _buildSearchStep();
      case 1: return _buildMapStep();
      case 2: return _buildDetailsStep();
      default: return const SizedBox();
    }
  }

  // ── Step 0: Search / GPS ───────────────────────────────────────────────────
  Widget _buildSearchStep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(key: const ValueKey(0), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Add New Address', style: p(20, w: FontWeight.w800, color: C.t1)),
      const SizedBox(height: 4),
      Text('Find your location to check serviceability', style: p(13, color: C.t3)),
      const SizedBox(height: 24),

      // Search Box
      Container(
        height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF3F7F0), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
        child: Row(children: [
          const Icon(Icons.search_rounded, color: C.forest, size: 20),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(hintText: 'Search area, colony, landmark...', border: InputBorder.none, isDense: true),
            style: p(14, w: FontWeight.w600),
          )),
          if (_searching) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.forest)),
        ]),
      ),

      if (_searchResults.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
          child: ListView.separated(
            shrinkWrap: true, separatorBuilder: (_,__) => const Divider(height: 1),
            itemCount: _searchResults.length,
            itemBuilder: (_, i) {
              final res = _searchResults[i];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined, size: 18),
                title: Text(asStr(res['display_name']), style: p(12, w: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _selectSearchResult(res),
              );
            },
          ),
        ),
      ],

      const SizedBox(height: 20),
      Center(child: Text('OR', style: p(11, w: FontWeight.w800, color: C.t4))),
      const SizedBox(height: 20),

      _LocTile(
        icon: _gpsLoading ? Icons.gps_fixed : Icons.my_location_rounded,
        text: _gpsLoading
            ? 'Detecting your location...'
            : _geocoding
                ? 'Fetching address...'
                : _detectedAddress.isNotEmpty
                    ? _detectedAddress
                    : 'Use Current Location',
        onTap: _gpsLoading ? null : _detectGPS,
      ),

      const SizedBox(height: 20),
      if (_detectedAddress.isNotEmpty && !_gpsLoading && !_geocoding) ...[
        if (!_isServiceable)
          _Badge(icon: Icons.info_outline_rounded, color: Colors.orange, text: 'This area may not be serviceable. You can still pin your location on the map.'),
        const SizedBox(height: 16),
        GBtn(
          label: 'Confirm on Map',
          icon: Icons.map_rounded,
          bg: C.forest,
          onTap: () => setState(() => _step = 1),
        ),
      ],
      const SizedBox(height: 24),
    ]),
  );

  // ── Step 1: Map (Precise Selection) ──────────────────────────────────────────
  Widget _buildMapStep() => Column(key: const ValueKey(1), children: [
    Expanded(child: Stack(children: [
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: _mapTarget ?? LatLng(22.5726, 88.3639),
          initialZoom: 17,
          onPositionChanged: (camera, hasGesture) {
            if (hasGesture) {
              _mapTarget = camera.center;
              _mapIdleTimer?.cancel();
              _mapIdleTimer = Timer(const Duration(milliseconds: 500), () async {
                if (_mapTarget != null && mounted) {
                  setState(() => _geocoding = true);
                  _lat = _mapTarget!.latitude; _lng = _mapTarget!.longitude;
                  await _reverseGeocode(_lat!, _lng!);
                }
              });
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.gharkamali.customer',
          ),
        ],
      ),
      // Center Pin
      Center(child: Padding(padding: const EdgeInsets.only(bottom: 35), child: Icon(Icons.location_on_rounded, color: C.forest, size: 45))),
      
      // Floating Header (Address Bar)
      Positioned(top: 20, left: 16, right: 16, child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: s2()),
        child: Row(children: [
          GestureDetector(onTap: () => setState(() => _step = 0), child: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 12),
          Expanded(child: Text(_geocoding ? 'Fetching address...' : _detectedAddress, style: p(13, w: FontWeight.w600, color: C.t1), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      )),

      // Floating Action (Current Loc)
      Positioned(bottom: 220, right: 16, child: FloatingActionButton(onPressed: _detectGPS, backgroundColor: Colors.white, child: const Icon(Icons.my_location_rounded, color: C.forest))),
    ])),

    // Bottom Panel
    Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_geocoding)
          _Badge(icon: Icons.sync_rounded, color: C.t3, text: 'Finding address for this location...')
        else if (_isServiceable)
          _Badge(icon: Icons.check_circle_rounded, color: C.green, text: 'Serviceable in ${asStr(_detectedZone['name'])} · Tap Confirm to continue')
        else
          _Badge(icon: Icons.info_outline_rounded, color: Colors.orange, text: 'Move the pin to your exact location for best results'),

        const SizedBox(height: 20),
        GBtn(
          label: _geocoding ? 'Locating...' : 'Confirm Location',
          icon: Icons.check_rounded,
          onTap: (_lat != null && _lng != null && !_geocoding) ? () => setState(() => _step = 2) : null,
          bg: (_lat != null && !_geocoding) ? C.forest : C.t4.withOpacity(0.3),
        ),
      ]),
    ),
  ]);

  // ── Step 2: Address Details ─────────────────────────────────────────────────
  Widget _buildDetailsStep() => SingleChildScrollView(
    key: const ValueKey(2),
    padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(onTap: () => setState(() => _step = 1), child: const Icon(Icons.arrow_back_rounded, color: C.t1)),
        const SizedBox(width: 14),
        Text('Address Details', style: p(18, w: FontWeight.w800, color: C.t1)),
      ]),
      const SizedBox(height: 8),
      Padding(padding: const EdgeInsets.only(left: 38), child: Text('Precisely selected on map', style: p(12, w: FontWeight.w600, color: C.forest))),
      const SizedBox(height: 20),
      _SheetField(ctrl: _flatCtrl,     label: 'Flat / House No.',      hint: 'e.g. 101 or B-402',         icon: Icons.home_rounded),
      const SizedBox(height: 12),
      _SheetField(ctrl: _buildingCtrl, label: 'Building / Apartment',  hint: 'e.g. Green Valley Apts',    icon: Icons.apartment_rounded),
      const SizedBox(height: 12),
      _SheetField(ctrl: _areaCtrl,     label: 'Landmark / Area',       hint: 'e.g. Near Central Park',    icon: Icons.place_outlined),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _SheetField(ctrl: _cityCtrl, label: 'City', hint: 'e.g. Noida', icon: Icons.location_city_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _SheetField(ctrl: _pincodeCtrl, label: 'Pincode', hint: '6 digits', icon: Icons.pin_drop_rounded)),
      ]),
      const SizedBox(height: 28),
      GBtn(label: 'Save Address', onTap: _onSaveAll, bg: C.forest),
      const SizedBox(height: 120), // Extra space for keyboard
    ]),
  );
}

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

class _LocTile extends StatelessWidget {
  final IconData icon; final String text; final VoidCallback? onTap;
  const _LocTile({required this.icon, required this.text, this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
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
        if (onTap != null) const Icon(Icons.refresh_rounded, size: 16, color: C.t4),
      ]),
    ),
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
