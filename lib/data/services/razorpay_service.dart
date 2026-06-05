import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api.dart';

class RazorpayResult {
  final bool ok;
  final bool cancelled;
  final String? message;
  RazorpayResult(this.ok, {this.cancelled = false, this.message});
}

/// Wraps razorpay_flutter's event-based checkout into a single awaitable call.
/// Creates the order on the backend, opens Checkout, then verifies the signature
/// server-side (which fulfills the payment). One instance per payment.
class RazorpayService {
  final Api _api = Api();

  Future<RazorpayResult> pay({
    required String type, // wallet_topup | booking | subscription | order
    double? amount,
    int? bookingId,
    int? subscriptionId,
    int? orderId,
    int? geofenceId,
  }) async {
    Map<String, dynamic> order;
    try {
      final res = await _api.createRazorpayOrder(
        type: type,
        amount: amount,
        bookingId: bookingId,
        subscriptionId: subscriptionId,
        orderId: orderId,
        geofenceId: geofenceId,
      );
      order = asMap(res);
    } on ApiError catch (e) {
      return RazorpayResult(false, message: e.message);
    } catch (_) {
      return RazorpayResult(false, message: 'Could not start the payment.');
    }
    if (asStr(order['key_id']).isEmpty || asStr(order['order_id']).isEmpty) {
      return RazorpayResult(false, message: 'Payment is not configured. Please contact support.');
    }

    final completer = Completer<RazorpayResult>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) async {
      try {
        await _api.verifyRazorpayPayment(
          razorpayOrderId: r.orderId ?? asStr(order['order_id']),
          razorpayPaymentId: r.paymentId ?? '',
          razorpaySignature: r.signature ?? '',
        );
        if (!completer.isCompleted) completer.complete(RazorpayResult(true));
      } on ApiError catch (e) {
        if (!completer.isCompleted) completer.complete(RazorpayResult(false, message: e.message));
      } catch (_) {
        if (!completer.isCompleted) {
          completer.complete(RazorpayResult(false, message: 'We could not verify your payment. If money was deducted it will be refunded.'));
        }
      }
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      // No payment captured (user dismissed or it failed) → void the unpaid
      // order/booking/subscription so it isn't left lingering in "pending".
      _api.cancelRazorpayPayment(razorpayOrderId: asStr(order['order_id'])).catchError((_) => null);
      if (!completer.isCompleted) {
        completer.complete(RazorpayResult(false, cancelled: r.code == Razorpay.PAYMENT_CANCELLED, message: r.message ?? 'Payment failed'));
      }
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});

    razorpay.open({
      'key': order['key_id'],
      'order_id': order['order_id'],
      'amount': order['amount'],
      'currency': order['currency'] ?? 'INR',
      'name': order['name'] ?? 'GharKaMali',
      'description': order['description'] ?? '',
      'prefill': order['prefill'] ?? {},
      'theme': {'color': '#03411A'},
    });

    final result = await completer.future;
    razorpay.clear(); // free the native listeners
    return result;
  }
}
