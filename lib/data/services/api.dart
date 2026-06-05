import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

const kBase    = 'https://gkm.gobt.in/api';
const kTokKey  = 'gkm_token';
const kUserKey = 'gkm_user';

// ─── Custom Exception ─────────────────────────────────────────────────────────
class ApiError implements Exception {
  final String message;
  final int code;
  ApiError(this.message, [this.code = 0]);
  @override String toString() => message;
}

// ─── API Service ─────────────────────────────────────────────────────────────
class Api {
  static final Api _i = Api._();
  factory Api() => _i;
  Api._();

  // Token helpers
  Future<String?> token() async => (await SharedPreferences.getInstance()).getString(kTokKey);

  Future<Map<String, String>> _headers({bool auth = true, bool isJson = true}) async {
    final h = <String, String>{};
    if (isJson) h['Content-Type'] = 'application/json';
    if (auth) {
      final t = await token();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // Core JSON request
  Future<dynamic> req(
    String method, String path, {
    bool auth = true,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$kBase$path');
    if (query != null && query.isNotEmpty) {
      final filtered = Map.fromEntries(query.entries.where((e) => e.value.isNotEmpty));
      if (filtered.isNotEmpty) uri = uri.replace(queryParameters: filtered);
    }
    final headers = await _headers(auth: auth);
    final encoded = body != null ? jsonEncode(body) : null;

    final showLogs = path.contains('/shop/products') || path.contains('/payments/check-serviceability');
    if (showLogs) {
      print('>>> API REQ: $method $uri');
      if (encoded != null) print('>>> BODY: $encoded');
    }

    http.Response res;
    try {
      const to = Duration(seconds: 25);
      res = await switch (method) {
        'POST'   => http.post(uri, headers: headers, body: encoded).timeout(to),
        'PUT'    => http.put(uri, headers: headers, body: encoded).timeout(to),
        'PATCH'  => http.patch(uri, headers: headers, body: encoded).timeout(to),
        'DELETE' => http.delete(uri, headers: headers).timeout(to),
        _        => http.get(uri, headers: headers).timeout(to),
      };
    } on SocketException   { throw ApiError('No internet connection. Please check your network.'); }
    on TimeoutException    { throw ApiError('Request timed out. Please try again.'); }
    catch (e)              { if (e is ApiError) rethrow; throw ApiError('Something went wrong. Please try again.'); }

    if (showLogs) print('<<< API RES: ${res.statusCode} ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}');

    dynamic json;
    try { json = jsonDecode(utf8.decode(res.bodyBytes)); } catch (_) { json = {}; }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json is Map && json.containsKey('data')) return json['data'];
      return json;
    }
    final msg = (json is Map ? json['message'] : null) as String? ?? 'Error ${res.statusCode}';
    throw ApiError(msg, res.statusCode);
  }

  // Multipart request for file uploads
  Future<dynamic> upload(
    String method, String path, {
    required Map<String, String> fields,
    Map<String, File>? files,
  }) async {
    final headers = await _headers(auth: true, isJson: false);
    final req = http.MultipartRequest(method, Uri.parse('$kBase$path'))
      ..headers.addAll(headers)
      ..fields.addAll(fields);
    if (files != null) {
      for (final e in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
      }
    }
    final showLogs = path.contains('/shop/products');
    if (showLogs) print('>>> API UPLOAD: $method $path | fields: $fields | files: ${files?.keys}');
    http.Response res;
    try {
      final stream = await req.send().timeout(const Duration(seconds: 40));
      res = await http.Response.fromStream(stream);
    } on SocketException  { throw ApiError('No internet connection.'); }
    on TimeoutException   { throw ApiError('Upload timed out. Please try again.'); }

    if (showLogs) print('<<< API RES: ${res.statusCode} ${res.body}');

    dynamic json;
    try { json = jsonDecode(utf8.decode(res.bodyBytes)); } catch (_) { json = {}; }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json is Map && json.containsKey('data')) return json['data'];
      return json;
    }
    final msg = (json is Map ? json['message'] : null) as String? ?? 'Upload error ${res.statusCode}';
    throw ApiError(msg, res.statusCode);
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  Future<dynamic> sendOtp(String phone) =>
      req('POST', '/auth/send-otp', auth: false, body: {'phone': phone});

  Future<dynamic> verifyOtp(String phone, String otp, {String? name}) async {
    final res = await req('POST', '/auth/verify-otp', auth: false,
        body: {'phone': phone, 'otp': otp, if (name != null && name.isNotEmpty) 'name': name});
    if (res is Map && res.containsKey('token')) {
      final p = await SharedPreferences.getInstance();
      await p.setString(kTokKey, asStr(res['token']));
      if (res.containsKey('user')) await p.setString(kUserKey, jsonEncode(res['user']));
    }
    return res;
  }

  Future<dynamic> getProfile() => req('GET', '/auth/profile');

  Future<dynamic> updateProfile({String? name, String? email, File? profileImage}) =>
      upload('PUT', '/auth/profile',
          fields: {
            if (name != null && name.isNotEmpty) 'name': name,
            if (email != null && email.isNotEmpty) 'email': email,
          },
          files: profileImage != null ? {'profile_image': profileImage} : null);

  // ─── ZONES & SERVICEABILITY ──────────────────────────────────────────────
  Future<dynamic> getZones() => req('GET', '/zones', auth: false);
  Future<dynamic> getGeofences() => req('GET', '/geofences', auth: false);

  Future<dynamic> checkServiceability(double lat, double lng) =>
      req('GET', '/payments/check-serviceability', auth: false,
          query: {'latitude': lat.toString(), 'longitude': lng.toString()});

  // ─── PLANS & ADDONS ──────────────────────────────────────────────────────
  Future<dynamic> getPlans() => req('GET', '/plans', auth: false);
  Future<dynamic> getAddons() => req('GET', '/addons', auth: false);
  Future<dynamic> getBookingAddons(int bookingId) => req('GET', '/bookings/$bookingId/addons');
  Future<dynamic> addBookingAddons(int bookingId, List<Map<String, dynamic>> addonIds) =>
      req('POST', '/bookings/$bookingId/addons', body: {'addon_ids': addonIds});

  // ─── BOOKINGS ────────────────────────────────────────────────────────────
  // Instant booking — server picks today + (now + zone.instant_eta_minutes).
  // Pass `isInstant: true` and omit scheduledDate/Time; backend will compute them.
  Future<dynamic> createBooking({
    required int zoneId,
    String? scheduledDate,
    required String serviceAddress,
    required double lat,
    required double lng,
    String? flatNo, String? building, String? area, String? landmark,
    String? city, String? state, String? pincode,
    String? scheduledTime,
    int? plantCount,
    int? preferredGardenerId,
    String? customerNotes,
    List<Map<String, dynamic>>? addons,
    double? totalAmount,
    int? geofenceId,
    bool isInstant = false,
  }) => req('POST', '/bookings', body: {
    'zone_id': zoneId,
    'geofence_id': geofenceId ?? zoneId,
    'service_address': serviceAddress,
    'service_latitude': lat,
    'service_longitude': lng,
    'is_instant': isInstant,
    if (!isInstant && scheduledDate != null) 'scheduled_date': scheduledDate,
    if (flatNo != null) 'flat_no': flatNo,
    if (building != null) 'building': building,
    if (area != null) 'area': area,
    if (landmark != null) 'landmark': landmark,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (pincode != null) 'pincode': pincode,
    if (!isInstant && scheduledTime != null) 'scheduled_time': scheduledTime,
    if (plantCount != null) 'plant_count': plantCount,
    if (preferredGardenerId != null) 'preferred_gardener_id': preferredGardenerId,
    if (customerNotes != null && customerNotes.isNotEmpty) 'customer_notes': customerNotes,
    if (addons != null) 'addons': addons,
    if (totalAmount != null) 'total_amount': totalAmount,
  });

  // Check zone-configured instant ETA + whether any gardener is free right now.
  Future<dynamic> getInstantAvailability(int geofenceId) =>
      req('GET', '/bookings/instant-availability', query: {'geofence_id': '$geofenceId'});

  Future<dynamic> getMyBookings({String? status, int page = 1, int limit = 10}) =>
      req('GET', '/bookings/my', query: {
        if (status != null && status != 'all') 'status': status,
        'page': '$page', 'limit': '$limit',
      });

  Future<dynamic> getBooking(int id) => req('GET', '/bookings/$id');

  Future<dynamic> cancelBooking(int bookingId, {String? reason}) =>
      req('POST', '/bookings/cancel', body: {
        'booking_id': bookingId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<dynamic> rateBooking(int bookingId, int rating, {String? review}) =>
      req('POST', '/bookings/rate', body: {
        'booking_id': bookingId,
        'rating': rating,
        if (review != null && review.isNotEmpty) 'review': review,
      });

  Future<dynamic> trackBooking(int bookingId) => req('GET', '/bookings/track/$bookingId');

  Future<dynamic> checkAvailability({required String date, required int geofenceId}) =>
      req('GET', '/bookings/check-availability', query: {'date': date, 'geofence_id': geofenceId.toString()});

  // Time-extension addon (on-demand only). Block size + price are zone-configured.
  Future<dynamic> getTimeAddons(int bookingId) =>
      req('GET', '/bookings/$bookingId/time-addons');

  Future<dynamic> requestTimeAddon(int bookingId, {int blocks = 1}) =>
      req('POST', '/bookings/$bookingId/time-addon', body: {'blocks': blocks});

  Future<dynamic> rescheduleBooking(int bookingId, String newDate, {String? newTime}) =>
      req('POST', '/payments/reschedule', body: {
        'booking_id': bookingId,
        'new_date': newDate,
        if (newTime != null) 'new_time': newTime,
      });

  // ─── SUBSCRIPTIONS ────────────────────────────────────────────────────────
  Future<dynamic> createSubscription({
    required int planId,
    required int zoneId,
    required String serviceAddress,
    required double lat,
    required double lng,
    String? flatNo, String? building, String? area, String? landmark,
    String? city, String? state, String? pincode,
    int? plantCount,
    bool autoRenew = true,
    List<Map<String, dynamic>>? addons,
    double? totalAmount,
    int? geofenceId,
    String? paymentMethod,
  }) => req('POST', '/subscriptions', body: {
    'plan_id': planId,
    'zone_id': zoneId,
    'geofence_id': geofenceId ?? zoneId,
    'service_address': serviceAddress,
    'service_latitude': lat,
    'service_longitude': lng,
    if (flatNo != null) 'flat_no': flatNo,
    if (building != null) 'building': building,
    if (area != null) 'area': area,
    if (landmark != null) 'landmark': landmark,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (pincode != null) 'pincode': pincode,
    if (plantCount != null) 'plant_count': plantCount,
    'auto_renew': autoRenew,
    if (addons != null) 'addons': addons,
    if (totalAmount != null) 'total_amount': totalAmount,
    if (paymentMethod != null) 'payment_method': paymentMethod,
  });

  Future<dynamic> getMySubscriptions() => req('GET', '/subscriptions/my');
  Future<dynamic> cancelSubscription(int id) => req('PUT', '/subscriptions/$id/cancel');
  Future<dynamic> pauseSubscription(int id)  => req('PATCH', '/subscriptions/$id/pause');
  Future<dynamic> resumeSubscription(int id) => req('PATCH', '/subscriptions/$id/resume');
  Future<dynamic> selectSubscriptionDates(int id, List<String> dates) =>
      req('POST', '/subscriptions/$id/select-dates', body: {'dates': dates});

  // ─── CONTENT & SETTINGS ──────────────────────────────────────────────────
  Future<dynamic> getActiveTaglines() => req('GET', '/taglines', auth: false);

  // ─── SHOP ─────────────────────────────────────────────────────────────────
  Future<dynamic> getShopCategories() => req('GET', '/shop/categories', auth: false);

  Future<dynamic> getShopProducts({String? category, String? search, int page = 1, int limit = 20}) =>
      req('GET', '/shop/products', auth: false, query: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': '$page', 'limit': '$limit',
      });

  Future<dynamic> getShopProduct(int id) => req('GET', '/shop/products/$id', auth: false);

  Future<dynamic> createShopOrder({
    required List<Map<String, dynamic>> items,
    required String shippingAddress,
    String? city, String? pincode,
    required double lat,
    required double lng,
    String paymentMethod = 'wallet',
    int? zoneId,
    bool applyGst = false,
    String? shippingState,
    String? billingGstin,
    String? billingBusinessName,
    String? couponCode,
  }) => req('POST', '/shop/orders', body: {
    'items': items,
    'shipping_address': shippingAddress,
    'shipping_city': city,
    'shipping_pincode': pincode,
    'service_latitude': lat,
    'service_longitude': lng,
    'payment_method': paymentMethod,
    if (zoneId != null) 'zone_id': zoneId,
    if (zoneId != null) 'geofence_id': zoneId,
    'apply_gst': applyGst,
    if (applyGst && shippingState != null) 'shipping_state': shippingState,
    if (applyGst && billingGstin != null && billingGstin.isNotEmpty) 'billing_gstin': billingGstin,
    if (applyGst && billingBusinessName != null && billingBusinessName.isNotEmpty) 'billing_business_name': billingBusinessName,
    if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
  });

  // ─── COUPONS ──────────────────────────────────────────────────────────────
  // On success returns { code, discount_amount, ... }; on a (200) validation
  // failure returns the { success:false, message } envelope.
  Future<dynamic> validateCoupon(String code, double subtotal) =>
      req('POST', '/coupons/validate', body: {'code': code, 'subtotal': subtotal});

  // Coupons the customer can currently apply (returns a list).
  Future<dynamic> getAvailableCoupons() => req('GET', '/coupons');

  Future<dynamic> getMyShopOrders({int page = 1, int limit = 10}) =>
      req('GET', '/shop/orders/my', query: {'page': '$page', 'limit': '$limit'});

  // ─── PAYMENTS / WALLET ────────────────────────────────────────────────────
  Future<dynamic> getMyPayments({int page = 1, int limit = 20}) =>
      req('GET', '/payments/my', query: {'page': '$page', 'limit': '$limit'});

  Future<dynamic> walletTopup(double amount) =>
      req('POST', '/payments/wallet-topup', body: {'amount': amount});

  Future<dynamic> getPaymentStatus(String txnId) =>
      req('GET', '/payments/status/$txnId');

  // ─── RAZORPAY ──────────────────────────────────────────────────────────────
  Future<dynamic> createRazorpayOrder({String? type, double? amount, int? bookingId, int? subscriptionId, int? orderId, int? geofenceId}) =>
      req('POST', '/payments/razorpay/order', body: {
        if (type != null) 'type': type,
        if (amount != null) 'amount': amount,
        if (bookingId != null) 'booking_id': bookingId,
        if (subscriptionId != null) 'subscription_id': subscriptionId,
        if (orderId != null) 'order_id': orderId,
        if (geofenceId != null) 'geofence_id': geofenceId,
      });

  Future<dynamic> verifyRazorpayPayment({required String razorpayOrderId, required String razorpayPaymentId, required String razorpaySignature}) =>
      req('POST', '/payments/razorpay/verify', body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      });

  // Void a dismissed/unpaid payment so its order/booking/subscription is
  // cancelled (stock + coupon restored) instead of lingering in "pending".
  Future<dynamic> cancelRazorpayPayment({required String razorpayOrderId}) =>
      req('POST', '/payments/razorpay/cancel', body: {'razorpay_order_id': razorpayOrderId});

  // ─── PLANTOPEDIA ──────────────────────────────────────────────────────────
  Future<dynamic> identifyPlant(File image) =>
      upload('POST', '/plants/identify', fields: {}, files: {'image': image});

  Future<dynamic> getPlantHistory() => req('GET', '/plants/history');

  // ─── BLOGS ───────────────────────────────────────────────────────────────
  Future<dynamic> getBlogs({int page = 1, int limit = 12}) =>
      req('GET', '/blogs', auth: false, query: {'page': '$page', 'limit': '$limit'});

  Future<dynamic> getBlog(String slug) => req('GET', '/blogs/$slug', auth: false);

  // ─── NOTIFICATIONS ────────────────────────────────────────────────────────
  Future<dynamic> getNotifications() => req('GET', '/notifications');
  Future<dynamic> markNotificationRead(int id) => req('PUT', '/notifications/$id/read');
  Future<dynamic> markAllNotificationsRead() => req('PUT', '/notifications/read-all');

  // ─── COMPLAINTS / TICKETING ──────────────────────────────────────────────
  Future<dynamic> createComplaint({
    required String type,
    required String description,
    int? bookingId,
    String priority = 'medium',
    String? subject,
    int? departmentId,
    List<File>? attachments,
  }) async {
    final headers = await _headers(auth: true, isJson: false);
    final r = http.MultipartRequest('POST', Uri.parse('$kBase/complaints'))
      ..headers.addAll(headers)
      ..fields['type'] = type
      ..fields['description'] = description
      ..fields['priority'] = priority;
    if (bookingId != null) r.fields['booking_id'] = '$bookingId';
    if (subject != null && subject.isNotEmpty) r.fields['subject'] = subject;
    if (departmentId != null) r.fields['department_id'] = '$departmentId';
    if (attachments != null) {
      for (final f in attachments) {
        r.files.add(await http.MultipartFile.fromPath('attachments', f.path));
      }
    }
    final stream = await r.send().timeout(const Duration(seconds: 40));
    final res = await http.Response.fromStream(stream);
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return json is Map && json.containsKey('data') ? json['data'] : json;
    throw ApiError(json is Map ? (json['message'] ?? 'Failed') : 'Failed', res.statusCode);
  }

  Future<dynamic> getMyComplaints() => req('GET', '/complaints/my');
  Future<dynamic> getComplaintDetail(int id) => req('GET', '/complaints/$id');
  Future<dynamic> getComplaintDepartments() => req('GET', '/complaints/departments');

  Future<dynamic> addComplaintComment({
    required int complaintId,
    String? comment,
    List<File>? attachments,
  }) async {
    final headers = await _headers(auth: true, isJson: false);
    final r = http.MultipartRequest('POST', Uri.parse('$kBase/complaints/$complaintId/comments'))
      ..headers.addAll(headers);
    if (comment != null && comment.isNotEmpty) r.fields['comment'] = comment;
    if (attachments != null) {
      for (final f in attachments) {
        r.files.add(await http.MultipartFile.fromPath('attachments', f.path));
      }
    }
    final stream = await r.send().timeout(const Duration(seconds: 40));
    final res = await http.Response.fromStream(stream);
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return json is Map && json.containsKey('data') ? json['data'] : json;
    throw ApiError(json is Map ? (json['message'] ?? 'Failed') : 'Failed', res.statusCode);
  }

  // ─── ADDRESSES ────────────────────────────────────────────────────────────
  Future<dynamic> getMyAddresses() => req('GET', '/addresses');
  Future<dynamic> addAddress(Map<String, dynamic> data) => req('POST', '/addresses', body: data);
  Future<dynamic> deleteAddress(int id) => req('DELETE', '/addresses/$id');
  Future<dynamic> setDefaultAddress(int id) => req('PATCH', '/addresses/$id/default');
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
List<dynamic> asList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v;
  if (v is String && v.trim().startsWith('[')) {
    try { return jsonDecode(v); } catch(_) {}
  }
  if (v is Map) {
    final items = v['items'] ?? v['data'] ?? v['results'];
    if (items is List) return items;
  }
  return [];
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return {};
}

int asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double asDouble(dynamic v, [double fallback = 0.0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

String asStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is int) return v == 1;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

String imgUrl(dynamic img) {
  if (img == null) return '';
  if (img is List && img.isNotEmpty) return img.first.toString();
  if (img is String) return img;
  return '';
}
