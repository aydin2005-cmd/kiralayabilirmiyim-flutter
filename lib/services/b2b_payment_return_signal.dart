import 'package:flutter/foundation.dart';

class B2BPaymentReturnSignal extends ChangeNotifier {
  B2BPaymentReturnSignal._();

  static final B2BPaymentReturnSignal instance = B2BPaymentReturnSignal._();

  String? _pendingPaymentId;

  void notifyPaymentReturn(
    String paymentId,
  ) {
    final normalized = paymentId.trim();

    if (normalized.isEmpty) {
      return;
    }

    _pendingPaymentId = normalized;
    notifyListeners();
  }

  String? takePendingPaymentId() {
    final paymentId = _pendingPaymentId;
    _pendingPaymentId = null;
    return paymentId;
  }
}
