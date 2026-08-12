import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SmsRetrieverService {
  SmsRetrieverService._() {
    _installMethodHandler();
  }

  static final SmsRetrieverService instance = SmsRetrieverService._();

  static const MethodChannel _channel = MethodChannel(
    'com.riskmetriks.kiralayabilirmiyim/sms_retriever',
  );

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  String? _pendingMessage;
  bool _handlerInstalled = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<String> get messages => _messageController.stream;

  void _installMethodHandler() {
    if (_handlerInstalled) {
      return;
    }

    _handlerInstalled = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'smsRetrieved':
          final message = call.arguments?.toString();

          if (message != null && message.trim().isNotEmpty) {
            if (_messageController.hasListener) {
              _pendingMessage = null;
              _messageController.add(message);
            } else {
              _pendingMessage = message;
            }
          }
          break;

        case 'smsRetrieverTimeout':
          break;
      }
    });
  }

  Future<bool> start() async {
    if (!_isAndroid) {
      return false;
    }

    _pendingMessage = null;

    try {
      final started = await _channel.invokeMethod<bool>('startSmsRetriever');
      return started ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('stopSmsRetriever');
    } on MissingPluginException {
      // Android bridge yoksa manuel OTP akışı devam eder.
    } on PlatformException {
      // Retriever hatası manuel OTP girişini engellememeli.
    }
  }

  String? takePendingMessage() {
    final message = _pendingMessage;
    _pendingMessage = null;
    return message;
  }

  static String? extractCode(
    String message,
    int codeLength,
  ) {
    if (codeLength < 4 || codeLength > 10) {
      return null;
    }

    final pattern = RegExp(
      '(?:^|\\D)(\\d{$codeLength})(?:\\D|\$)',
    );

    return pattern.firstMatch(message)?.group(1);
  }
}
