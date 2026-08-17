import 'dart:async';

import 'package:flutter/widgets.dart';

import 'sms_retriever_service.dart';

class OtpAutofillCoordinator {
  OtpAutofillCoordinator({
    required this.controller,
    required this.codeLength,
    required this.isActive,
    required this.canAutoSubmit,
    required this.submit,
    required this.messages,
    required this.takePendingMessage,
    required this.stopRetriever,
    this.autoSubmitDelay = const Duration(milliseconds: 800),
  });

  final TextEditingController controller;
  final int Function() codeLength;
  final bool Function() isActive;
  final bool Function() canAutoSubmit;
  final Future<void> Function() submit;
  final Stream<String> messages;
  final String? Function() takePendingMessage;
  final Future<void> Function() stopRetriever;
  final Duration autoSubmitDelay;

  StreamSubscription<String>? _smsSubscription;
  bool _disposed = false;
  String? _lastAutoSubmittedCode;

  void start() {
    if (_disposed) {
      return;
    }

    final previousSubscription = _smsSubscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    _smsSubscription = messages.listen((message) {
      unawaited(handleRetrievedSms(message));
    });

    final pendingMessage = takePendingMessage();
    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          unawaited(handleRetrievedSms(pendingMessage));
        }
      });
    }
  }

  Future<void> handleRetrievedSms(String message) async {
    if (_disposed || !isActive()) {
      return;
    }

    final code = SmsRetrieverService.extractCode(
      message,
      codeLength(),
    );

    if (code == null || controller.text == code) {
      return;
    }

    controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );

    await Future<void>.delayed(autoSubmitDelay);

    if (_disposed ||
        !isActive() ||
        !canAutoSubmit() ||
        controller.text.trim() != code) {
      return;
    }

    await _submitAutoDetectedCode(code);
  }

  void handleCodeChanged(String value) {
    final code = value.trim();

    if (_disposed ||
        !isActive() ||
        !canAutoSubmit() ||
        code.length != codeLength()) {
      return;
    }

    unawaited(submit());
  }

  Future<void> _submitAutoDetectedCode(String code) async {
    if (_lastAutoSubmittedCode == code) {
      return;
    }

    _lastAutoSubmittedCode = code;
    await submit();
  }

  void dispose() {
    _disposed = true;
    final previousSubscription = _smsSubscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    unawaited(stopRetriever());
  }
}
