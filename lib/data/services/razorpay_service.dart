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
    required String type, // booking | subscription | order
    double? amount,
    int? bookingId,
    int? subscriptionId,
    int? orderId,
    int? geofenceId,
    bool useWallet = false, // spend wallet first; gateway charges the remainder
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
        useWallet: useWallet,
      );
      order = asMap(res);
    } on ApiError catch (e) {
      return RazorpayResult(false, message: e.message);
    } catch (_) {
      return RazorpayResult(false, message: 'Could not start the payment.');
    }
    // Wallet covered the full amount — already paid and fulfilled server-side.
    if (order['wallet_paid'] == true) {
      return RazorpayResult(true, message: 'Paid ₹${order['wallet_applied']} from your wallet');
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

  /// Tip a gardener for a completed visit. Same awaitable Checkout wrapper,
  /// against the dedicated tip ledger endpoints — the tip counts only after
  /// the backend verifies the signature (success here means verified).
  Future<RazorpayResult> payTip({required int bookingId, required int amountRupees}) async {
    Map<String, dynamic> order;
    try {
      final res = await _api.createTip(
        bookingId: bookingId,
        amountRupees: amountRupees,
        idempotencyKey: 'tip-$bookingId-${DateTime.now().millisecondsSinceEpoch}',
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
        await _api.verifyTip(
          razorpayOrderId: r.orderId ?? asStr(order['order_id']),
          razorpayPaymentId: r.paymentId ?? '',
          razorpaySignature: r.signature ?? '',
        );
        if (!completer.isCompleted) completer.complete(RazorpayResult(true, message: r.paymentId));
      } on ApiError catch (e) {
        if (!completer.isCompleted) completer.complete(RazorpayResult(false, message: e.message));
      } catch (_) {
        if (!completer.isCompleted) {
          completer.complete(RazorpayResult(false, message: 'We could not verify your payment. If money was deducted it will be refunded.'));
        }
      }
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      _api.cancelTip(razorpayOrderId: asStr(order['order_id'])).catchError((_) => null);
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
      'description': order['description'] ?? 'Tip your gardener',
      'prefill': order['prefill'] ?? {},
      'theme': {'color': '#03411A'},
    });

    final result = await completer.future;
    razorpay.clear();
    return result;
  }
}
