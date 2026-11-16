// One-time gardening service pricing — mirror of the backend engine
// (GharKaMali_Backend/src/services/oneTimePricing.js), used only to show the
// price instantly. The server always recomputes the amount at checkout.
//
//   Service charge = zone base price (first 10 plants)
//                  + Σ (plants inside each range × that range's rate)
// Rounded to the nearest rupee once, after the full amount. Summed in paise.

const int kBasePlants = 10;
const int kMinPlants = 10;
const List<int> kVermicompostSizes = [1, 5, 10];

int _toPaise(num rupees) => (rupees * 100).round();
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

class RateInterval {
  final int min, max;
  final double rate;
  const RateInterval(this.min, this.max, this.rate);
}

class RangeCharge {
  final int plants;
  final double rate;
  const RangeCharge(this.plants, this.rate);
}

class ServiceCharge {
  final bool ok;          // false → above the last range: custom quote
  final int plants;
  final double rawAmount; // before rounding
  final int amount;       // customer amount, nearest ₹1
  final int maxPlants;
  final List<RangeCharge> breakdown;
  const ServiceCharge({required this.ok, required this.plants, this.rawAmount = 0, this.amount = 0, required this.maxPlants, this.breakdown = const []});
}

class SurchargeLine {
  final int id;
  final String name, reason, type;
  final double value, amount;
  const SurchargeLine({required this.id, required this.name, required this.reason, required this.type, required this.value, required this.amount});
  String get basis => type == 'percentage' ? '${_fmt(value)}% of the service charge' : 'Fixed charge';
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

const List<RateInterval> kDefaultIntervals = [
  RateInterval(11, 15, 30.2), RateInterval(16, 20, 20), RateInterval(21, 30, 15),
  RateInterval(31, 40, 15), RateInterval(41, 50, 10), RateInterval(51, 60, 20),
  RateInterval(61, 70, 20), RateInterval(71, 80, 20), RateInterval(81, 100, 20),
  RateInterval(101, 150, 10), RateInterval(151, 200, 10),
];
const Map<int, double> kDefaultVermicompost = {1: 100, 5: 300, 10: 580};

class OneTimePricing {
  final double basePrice;
  final List<RateInterval> intervals;
  final Map<int, double> vermicompost; // kg → price
  final List<Map<String, dynamic>> surcharges;
  final bool isFallback;

  const OneTimePricing({required this.basePrice, required this.intervals, required this.vermicompost, this.surcharges = const [], this.isFallback = false});

  // Zone base + standard rates, used until the zone's own table loads.
  factory OneTimePricing.fallback(double basePrice) =>
      OneTimePricing(basePrice: basePrice, intervals: kDefaultIntervals, vermicompost: kDefaultVermicompost, isFallback: true);

  // Payload of GET /pricing/one-time?geofence_id=
  factory OneTimePricing.fromJson(Map json) {
    final ivs = <RateInterval>[];
    for (final e in (json['intervals'] is List ? json['intervals'] as List : const [])) {
      if (e is Map) ivs.add(RateInterval(_i(e['min']), _i(e['max']), _d(e['rate'])));
    }
    final vc = <int, double>{};
    for (final e in (json['vermicompost'] is List ? json['vermicompost'] as List : const [])) {
      if (e is Map) vc[_i(e['kg'])] = _d(e['price']);
    }
    final sur = <Map<String, dynamic>>[];
    for (final e in (json['surcharges'] is List ? json['surcharges'] as List : const [])) {
      if (e is Map) sur.add(Map<String, dynamic>.from(e));
    }
    return OneTimePricing(
      basePrice: _d(json['base_price']),
      intervals: ivs.isEmpty ? kDefaultIntervals : ivs,
      vermicompost: vc.isEmpty ? kDefaultVermicompost : vc,
      surcharges: sur,
    );
  }

  int get maxPlants => intervals.isEmpty ? kBasePlants : intervals.last.max;

  ServiceCharge serviceCharge(int quantity) {
    final plants = quantity < kMinPlants ? kMinPlants : quantity;
    if (plants > maxPlants) return ServiceCharge(ok: false, plants: plants, maxPlants: maxPlants);
    var paise = _toPaise(basePrice);
    final parts = <RangeCharge>[];
    for (final iv in intervals) {
      final top = plants < iv.max ? plants : iv.max;
      final count = top - iv.min + 1;
      if (count > 0) {
        paise += count * _toPaise(iv.rate);
        parts.add(RangeCharge(count, iv.rate));
      }
    }
    return ServiceCharge(ok: true, plants: plants, rawAmount: paise / 100, amount: (paise / 100).round(), maxPlants: maxPlants, breakdown: parts);
  }

  // Surcharges for a visit on [date] (yyyy-MM-dd); the API already filtered
  // them to this zone and to active ones. Each applies at most once.
  List<SurchargeLine> surchargeLines(int serviceAmount, String date) {
    final seen = <int>{};
    final out = <SurchargeLine>[];
    for (final s in surcharges) {
      final id = _i(s['id']);
      if (seen.contains(id)) continue;
      final from = '${s['starts_on'] ?? ''}';
      final to = '${s['ends_on'] ?? ''}';
      if (date.isNotEmpty && from.length >= 10 && date.compareTo(from.substring(0, 10)) < 0) continue;
      if (date.isNotEmpty && to.length >= 10 && date.compareTo(to.substring(0, 10)) > 0) continue;
      seen.add(id);
      final type = '${s['type']}';
      final value = _d(s['value']);
      final amount = type == 'percentage' ? (serviceAmount * value / 100).roundToDouble() : (value * 100).roundToDouble() / 100;
      if (amount <= 0) continue;
      out.add(SurchargeLine(id: id, name: '${s['name'] ?? 'Surcharge'}', reason: '${s['reason'] ?? ''}', type: type, value: value, amount: amount));
    }
    return out;
  }
}
