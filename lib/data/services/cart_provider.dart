import 'package:flutter/material.dart';
import '../services/api.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, Map<String, dynamic>> _cart = {};

  int    get count => _cart.values.fold(0, (s, e) => s + asInt(e['qty']));
  double get total => _cart.values.fold(0.0, (s, e) => s + asDouble(asMap(e['product'])['price']) * asInt(e['qty']));
  List<Map<String, dynamic>> get items => _cart.values.toList();
  Map<int, Map<String, dynamic>> get rawCart => Map.unmodifiable(_cart);

  int qty(int id) => asInt(_cart[id]?['qty']);

  void add(Map<String, dynamic> product) {
    final id = asInt(product['id']);
    if (_cart.containsKey(id)) {
      _cart[id]!['qty'] = asInt(_cart[id]!['qty']) + 1;
    } else {
      _cart[id] = {'product': product, 'qty': 1};
    }
    notifyListeners();
  }

  void remove(int id) {
    if (!_cart.containsKey(id)) return;
    final q = asInt(_cart[id]!['qty']) - 1;
    if (q <= 0) _cart.remove(id); else _cart[id]!['qty'] = q;
    notifyListeners();
  }

  void clear() { _cart.clear(); notifyListeners(); }
}
