import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  String?               _token;
  bool                  _loading = true;

  Map<String, dynamic>? get user     => _user;
  String?               get token    => _token;
  bool                  get isAuthed => _token != null && _token!.isNotEmpty;
  bool                  get loading  => _loading;

  // Typed getters
  String  get name          => asStr(_user?['name'], 'User');
  String  get phone         => asStr(_user?['phone'] ?? _user?['phone_number'] ?? _user?['mobile']);
  String? get email         => _user?['email'] as String?;
  String? get profileImage  => _user?['profile_image'] as String?;
  double  get walletBalance => asDouble(_user?['wallet_balance']);
  String? get referralCode  => _user?['referral_code'] as String?;

  AuthProvider() { _hydrate(); }

  Future<void> _hydrate() async {
    try {
      final p = await SharedPreferences.getInstance();
      _token = p.getString(kTokKey);
      final raw = p.getString(kUserKey);
      if (_token != null && _token!.isNotEmpty && raw != null) {
        try { _user = jsonDecode(raw) as Map<String, dynamic>?; }
        catch (_) { _token = null; _user = null; }
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> login(Map<String, dynamic> user, String token) async {
    _user = user; _token = token;
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString(kTokKey, token),
      p.setString(kUserKey, jsonEncode(user)),
    ]);
    notifyListeners();
  }

  Future<void> patchUser(Map<String, dynamic> updates) async {
    _user = {...?_user, ...updates};
    final p = await SharedPreferences.getInstance();
    await p.setString(kUserKey, jsonEncode(_user));
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      final res = await Api().getProfile();
      if (res is Map) await patchUser(asMap(res));
    } catch (_) {}
  }

  Future<void> logout() async {
    _user = null; _token = null;
    final p = await SharedPreferences.getInstance();
    await Future.wait([p.remove(kTokKey), p.remove(kUserKey)]);
    notifyListeners();
  }
}
