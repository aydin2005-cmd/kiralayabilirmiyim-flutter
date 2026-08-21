import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/services/payment_return_link_parser.dart';

void main() {
  test(
    'legacy payment-result link remains B2C compatible',
    () {
      final result = paymentReturnLinkFromUri(
        Uri.parse(
          'kiralayabilirmiyim://payment-result'
          '?application_id=app-1'
          '&payment_id=payment-1',
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.scope,
        PaymentReturnScope.b2c,
      );
      expect(
        result.applicationId,
        'app-1',
      );
      expect(
        result.paymentId,
        'payment-1',
      );
    },
  );

  test(
    'explicit B2B payment return is separated from B2C',
    () {
      final result = paymentReturnLinkFromUri(
        Uri.parse(
          'kiralayabilirmiyim://payment-result'
          '?scope=b2b'
          '&payment_id=payment-b2b-1',
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.scope,
        PaymentReturnScope.b2b,
      );
      expect(
        result.applicationId,
        isNull,
      );
      expect(
        result.paymentId,
        'payment-b2b-1',
      );
    },
  );

  test(
    'unrelated URI is ignored',
    () {
      expect(
        paymentReturnLinkFromUri(
          Uri.parse(
            'kiralayabilirmiyim://b2b-referral'
            '?token=abc',
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'unknown payment scope is rejected',
    () {
      expect(
        paymentReturnLinkFromUri(
          Uri.parse(
            'kiralayabilirmiyim://payment-result'
            '?scope=unexpected'
            '&payment_id=payment-1',
          ),
        ),
        isNull,
      );
    },
  );
}
