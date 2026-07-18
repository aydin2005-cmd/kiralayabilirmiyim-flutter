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
  String? paymentCompletedApplicationId;
  bool paymentSuccessHandled = false;

  bool get isCurrentApplicationPaymentCompleted {
    final currentApplicationId = applicationId;
    return paymentCompleted &&
        currentApplicationId != null &&
        paymentCompletedApplicationId == currentApplicationId;
  }

  void markCurrentApplicationPaymentCompleted() {
    final currentApplicationId = applicationId;
    if (currentApplicationId == null || currentApplicationId.isEmpty) {
      return;
    }

    paymentCompleted = true;
    paymentCompletedApplicationId = currentApplicationId;
  }

  void resetApplicationFlow() {
    applicationId = null;
    reportId = null;
    analysisId = null;
    resultType = null;
    applicationType = null;
    applicationAmount = null;
    paymentCompleted = false;
    paymentCompletedApplicationId = null;
    paymentSuccessHandled = false;
  }

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
  num serviceFeeAmount = 10;
  String serviceFeeCurrency = 'TL';
}
