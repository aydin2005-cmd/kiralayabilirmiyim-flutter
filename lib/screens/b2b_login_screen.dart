import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../services/otp_autofill_coordinator.dart';
import '../services/sms_retriever_service.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'b2b_portal_screen.dart';

class B2BLoginScreen extends StatefulWidget {
  final String? initialPhone;

  const B2BLoginScreen({
    super.key,
    this.initialPhone,
  });

  @override
  State<B2BLoginScreen> createState() => _B2BLoginScreenState();
}

class _B2BLoginScreenState extends State<B2BLoginScreen> {
  late final TextEditingController phoneController;
  final passwordController = TextEditingController();
  final codeController = TextEditingController();
  final B2BApiClient api = B2BApiClient();
  late final OtpAutofillCoordinator otpAutofill;

  String? challengeId;
  int codeLength = 6;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController(text: widget.initialPhone ?? '');
    otpAutofill = OtpAutofillCoordinator(
      controller: codeController,
      codeLength: () => codeLength,
      isActive: () => mounted && !loading && challengeId != null,
      canAutoSubmit: () => mounted && !loading && challengeId != null,
      submit: verifyLogin,
      messages: SmsRetrieverService.instance.messages,
      takePendingMessage: SmsRetrieverService.instance.takePendingMessage,
      stopRetriever: SmsRetrieverService.instance.stop,
    );
  }

  @override
  void dispose() {
    otpAutofill.dispose();
    phoneController.dispose();
    passwordController.dispose();
    codeController.dispose();
    super.dispose();
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> startLogin() async {
    final phone = normalizeTurkeyMobile(phoneController.text);
    final password = passwordController.text;

    if (phone == null) {
      _error('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    if (password.isEmpty) {
      _error('Kurumsal şifrenizi giriniz.');
      return;
    }

    setState(() => loading = true);

    var smsRetrieverStarted = false;

    try {
      smsRetrieverStarted = await SmsRetrieverService.instance.start();

      final response = await api.post(
        '/b2b/auth/login/start',
        {
          'phone_number': phone,
          'password': password,
        },
      );

      final id = response['challenge_id']?.toString();
      if (id == null || id.isEmpty) {
        throw const B2BApiException('Kurumsal giriş başlatılamadı.');
      }

      if (!mounted) {
        if (smsRetrieverStarted) {
          await SmsRetrieverService.instance.stop();
        }
        return;
      }

      setState(() {
        challengeId = id;
        final parsedCodeLength = int.tryParse('${response['code_length']}');
        codeLength = parsedCodeLength != null &&
                parsedCodeLength >= 4 &&
                parsedCodeLength <= 10
            ? parsedCodeLength
            : 6;
        codeController.clear();
        loading = false;
      });

      otpAutofill.start();
    } catch (e) {
      if (smsRetrieverStarted) {
        await SmsRetrieverService.instance.stop();
      }

      _error(e.toString());

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> verifyLogin() async {
    final id = challengeId;
    final code = codeController.text.trim();

    if (id == null) {
      _error('Önce giriş SMS kodu isteyin.');
      return;
    }

    if (code.length != codeLength) {
      _error('$codeLength haneli SMS kodunu giriniz.');
      return;
    }

    if (loading) {
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.post(
        '/b2b/auth/login/verify',
        {
          'challenge_id': id,
          'code': code,
        },
      );

      final token = response['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw const B2BApiException('Kurumsal oturum başlatılamadı.');
      }

      await api.saveToken(token);
      await SmsRetrieverService.instance.stop();
      TextInput.finishAutofillContext(shouldSave: false);

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const B2BPortalScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingOtp = challengeId != null;

    return FlowScaffold(
      title: 'Kurumsal Giriş',
      bottom: PrimaryButton(
        text: waitingOtp ? 'SMS Kodunu Doğrula' : 'Giriş Kodu Gönder',
        loading: loading,
        onPressed: waitingOtp ? verifyLogin : startLogin,
      ),
      children: [
        const FlowHeader(
          icon: Icons.login_rounded,
          eyebrow: 'Güvenli Kurumsal Giriş',
          title: 'Firmanızın portalına giriş yapın',
          subtitle:
              'Telefon ve şifreniz doğrulandıktan sonra SMS koduyla ikinci doğrulama yapılır.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          child: Column(
            children: [
              FlowTextField(
                controller: phoneController,
                label: 'Yetkili cep telefonu',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                ],
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: passwordController,
                label: 'Kurumsal şifre',
                obscureText: true,
              ),
              if (waitingOtp) ...[
                const SizedBox(height: 14),
                FlowTextField(
                  controller: codeController,
                  label: 'SMS doğrulama kodu',
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: codeLength,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: otpAutofill.handleCodeChanged,
                  onSubmitted: (_) => verifyLogin(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
