class AppState {
  static final AppState instance = AppState._internal();
  AppState._internal();

  String? token;
  String? userId;
  String? firstName;
  String? middleName;
  String? lastName;
  String? tcknLast3;

  String? b2bReferralToken;
  String? b2bOrganizationName;
  String? b2bConsentTextVersion;
  String? b2bConsentText;
  bool b2bCorporateSelected = false;

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

  bool get hasPendingB2BCorporateFlow {
    return b2bCorporateSelected &&
        b2bReferralToken != null &&
        b2bReferralToken!.isNotEmpty &&
        b2bConsentTextVersion != null &&
        b2bConsentTextVersion!.isNotEmpty &&
        b2bConsentText != null &&
        b2bConsentText!.isNotEmpty;
  }

  void configureB2BReferral({
    required String referralToken,
    required String organizationName,
    required String consentTextVersion,
    required String consentText,
  }) {
    b2bReferralToken = referralToken;
    b2bOrganizationName = organizationName;
    b2bConsentTextVersion = consentTextVersion;
    b2bConsentText = consentText;
    b2bCorporateSelected = false;
  }

  void selectB2BCorporateFlow() {
    b2bCorporateSelected = true;
  }

  void clearB2BReferralContext() {
    b2bReferralToken = null;
    b2bOrganizationName = null;
    b2bConsentTextVersion = null;
    b2bConsentText = null;
    b2bCorporateSelected = false;
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
