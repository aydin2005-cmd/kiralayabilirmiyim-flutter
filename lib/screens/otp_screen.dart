import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../services/sms_retriever_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'identity_profile_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String challengeId;
  final int codeLength;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.challengeId,
    this.codeLength = 6,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  final api = ApiClient();

  StreamSubscription<String>? _smsSubscription;

  int get _codeLength =>
      widget.codeLength >= 4 && widget.codeLength <= 10 ? widget.codeLength : 6;

  @override
  void initState() {
    super.initState();

    _smsSubscription = SmsRetrieverService.instance.messages.listen((message) {
      unawaited(_handleRetrievedSms(message));
    });

    final pendingMessage = SmsRetrieverService.instance.takePendingMessage();

    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_handleRetrievedSms(pendingMessage));
        }
      });
    }
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    unawaited(SmsRetrieverService.instance.stop());
    codeController.dispose();
    super.dispose();
  }

  Future<void> _handleRetrievedSms(String message) async {
    if (!mounted || loading) {
      return;
    }

    final code = SmsRetrieverService.extractCode(
      message,
      _codeLength,
    );

    if (code == null) {
      return;
    }

    if (codeController.text == code) {
      return;
    }

    codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );

    // Let the user briefly see that SMS Retriever filled the OTP
    // before automatic verification moves to the next screen.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted || loading || codeController.text.trim() != code) {
      return;
    }

    await verify();
  }

  Future<void> verify() async {
    final code = codeController.text.trim();

    if (code.length != _codeLength) {
      return _showError(
        'Lütfen $_codeLength haneli SMS kodunu girin.',
      );
    }

    if (loading) {
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.post(
        '/auth/otp/verify',
        {
          'challenge_id': widget.challengeId,
          'code': code,
        },
      );

      final token = response['access_token']?.toString();

      if (token == null || token.isEmpty) {
        throw ApiException('Oturum başlatılamadı.');
      }

      await api.saveToken(token);

      AppState.instance.token = token;
      AppState.instance.userId = response['user_id']?.toString();

      await SmsRetrieverService.instance.stop();

      TextInput.finishAutofillContext(shouldSave: false);

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const IdentityProfileScreen(),
        ),
        (_) => false,
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _handleCodeChanged(String value) {
    if (value.length == _codeLength && !loading) {
      unawaited(verify());
    }
  }

  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'SMS Doğrulama',
      children: [
        FlowHeader(
          icon: Icons.pin_outlined,
          eyebrow: 'Doğrulama',
          title: 'SMS doğrulama kodunu girin',
          subtitle:
              '${widget.phoneNumber} numarasına gönderilen kodu girerek devam edin.',
        ),
        const SizedBox(height: 22),
        PremiumCard(
          child: AutofillGroup(
            child: TextField(
              controller: codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: _codeLength,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: _handleCodeChanged,
              onSubmitted: (_) => verify(),
              decoration: InputDecoration(
                labelText: 'SMS kodu',
                helperText: '$_codeLength haneli doğrulama kodu',
                counterText: '',
              ),
            ),
          ),
        ),
      ],
      bottom: PrimaryButton(
        text: 'Doğrula',
        loading: loading,
        onPressed: verify,
      ),
    );
  }
}
