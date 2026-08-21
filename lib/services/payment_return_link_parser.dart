enum PaymentReturnScope {
  b2c,
  b2b,
}

class PaymentReturnLink {
  final PaymentReturnScope scope;
  final String? applicationId;
  final String? paymentId;

  const PaymentReturnLink({
    required this.scope,
    required this.applicationId,
    required this.paymentId,
  });
}

PaymentReturnLink? paymentReturnLinkFromUri(
  Uri uri,
) {
  if (uri.scheme != 'kiralayabilirmiyim' || uri.host != 'payment-result') {
    return null;
  }

  final rawScope = uri.queryParameters['scope']?.trim().toLowerCase();

  final PaymentReturnScope scope;

  if (rawScope == null || rawScope.isEmpty || rawScope == 'b2c') {
    scope = PaymentReturnScope.b2c;
  } else if (rawScope == 'b2b') {
    scope = PaymentReturnScope.b2b;
  } else {
    return null;
  }

  String? nonEmpty(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  return PaymentReturnLink(
    scope: scope,
    applicationId: nonEmpty(
      uri.queryParameters['application_id'],
    ),
    paymentId: nonEmpty(
      uri.queryParameters['payment_id'],
    ),
  );
}
