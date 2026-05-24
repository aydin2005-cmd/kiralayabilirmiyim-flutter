class AppState {
  static final AppState instance = AppState._internal();
  AppState._internal();

  String? token;
  String? userId;
  String? firstName;
  String? middleName;
  String? lastName;
  String? tcknLast3;
  String? applicationId;
  String? reportId;
  String? analysisId;
  String? resultType;
  bool paymentCompleted = false;
  bool paymentSuccessHandled = false;

  void resetPaymentSuccessHandling() {
    paymentSuccessHandled = false;
  }

  bool markPaymentSuccessHandled() {
    if (paymentSuccessHandled) return false;
    paymentSuccessHandled = true;
    return true;
  }
  String? applicationType;
  num? applicationAmount;
  num serviceFeeAmount = 9;
  String serviceFeeCurrency = 'TL';
}

