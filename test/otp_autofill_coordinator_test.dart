import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/services/otp_autofill_coordinator.dart';

void main() {
  test('retrieved SMS fills OTP controller and auto-submits once', () async {
    final stream = StreamController<String>.broadcast();
    final controller = TextEditingController();
    var submitCount = 0;

    final coordinator = OtpAutofillCoordinator(
      controller: controller,
      codeLength: () => 6,
      isActive: () => true,
      canAutoSubmit: () => true,
      submit: () async {
        submitCount++;
      },
      messages: stream.stream,
      takePendingMessage: () => null,
      stopRetriever: () async {},
      autoSubmitDelay: Duration.zero,
    );

    await coordinator.handleRetrievedSms(
      'Kiralayabilir Miyim dogrulama kodunuz: 123456',
    );
    await coordinator.handleRetrievedSms(
      'Kiralayabilir Miyim dogrulama kodunuz: 123456',
    );

    expect(controller.text, '123456');
    expect(submitCount, 1);

    coordinator.dispose();
    controller.dispose();
    await stream.close();
  });

  test('manual OTP entry still submits when code length is complete', () async {
    final stream = StreamController<String>.broadcast();
    final controller = TextEditingController();
    var submitCount = 0;

    final coordinator = OtpAutofillCoordinator(
      controller: controller,
      codeLength: () => 6,
      isActive: () => true,
      canAutoSubmit: () => true,
      submit: () async {
        submitCount++;
      },
      messages: stream.stream,
      takePendingMessage: () => null,
      stopRetriever: () async {},
      autoSubmitDelay: Duration.zero,
    );

    coordinator.handleCodeChanged('12345');
    await Future<void>.delayed(Duration.zero);
    expect(submitCount, 0);

    coordinator.handleCodeChanged('123456');
    await Future<void>.delayed(Duration.zero);
    expect(submitCount, 1);

    coordinator.dispose();
    controller.dispose();
    await stream.close();
  });

  test('wrong length SMS does not fill or submit', () async {
    final stream = StreamController<String>.broadcast();
    final controller = TextEditingController();
    var submitCount = 0;

    final coordinator = OtpAutofillCoordinator(
      controller: controller,
      codeLength: () => 6,
      isActive: () => true,
      canAutoSubmit: () => true,
      submit: () async {
        submitCount++;
      },
      messages: stream.stream,
      takePendingMessage: () => null,
      stopRetriever: () async {},
      autoSubmitDelay: Duration.zero,
    );

    await coordinator.handleRetrievedSms('Eski kod: 12345');

    expect(controller.text, isEmpty);
    expect(submitCount, 0);

    coordinator.dispose();
    controller.dispose();
    await stream.close();
  });

  test('dispose prevents later async auto-submit', () async {
    final stream = StreamController<String>.broadcast();
    final controller = TextEditingController();
    var submitCount = 0;
    var stopCount = 0;

    final coordinator = OtpAutofillCoordinator(
      controller: controller,
      codeLength: () => 6,
      isActive: () => true,
      canAutoSubmit: () => true,
      submit: () async {
        submitCount++;
      },
      messages: stream.stream,
      takePendingMessage: () => null,
      stopRetriever: () async {
        stopCount++;
      },
      autoSubmitDelay: const Duration(milliseconds: 20),
    );

    final pending = coordinator.handleRetrievedSms('Kod: 123456');
    coordinator.dispose();
    await pending;

    expect(controller.text, '123456');
    expect(submitCount, 0);
    expect(stopCount, 1);

    controller.dispose();
    await stream.close();
  });

  test('disposed coordinator ignores later SMS callbacks', () async {
    final stream = StreamController<String>.broadcast();
    final controller = TextEditingController();
    var submitCount = 0;

    final coordinator = OtpAutofillCoordinator(
      controller: controller,
      codeLength: () => 6,
      isActive: () => true,
      canAutoSubmit: () => true,
      submit: () async {
        submitCount++;
      },
      messages: stream.stream,
      takePendingMessage: () => null,
      stopRetriever: () async {},
      autoSubmitDelay: Duration.zero,
    );

    coordinator.dispose();
    await coordinator.handleRetrievedSms('Kod: 123456');

    expect(controller.text, isEmpty);
    expect(submitCount, 0);

    controller.dispose();
    await stream.close();
  });
}
