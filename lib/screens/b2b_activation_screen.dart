import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'b2b_login_screen.dart';

class B2BActivationScreen extends StatefulWidget {
  const B2BActivationScreen({super.key});

  @override
  State<B2BActivationScreen> createState() => _B2BActivationScreenState();
}

class _B2BActivationScreenState extends State<B2BActivationScreen> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordAgainController = TextEditingController();
  final B2BApiClient api = B2BApiClient();

  String? challengeId;
  String? normalizedPhone;
  int codeLength = 6;
  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    passwordController.dispose();
    passwordAgainController.dispose();
    super.dispose();
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> startActivation() async {
    final phone = normalizeTurkeyMobile(phoneController.text);
    if (phone == null) {
      _error('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.post(
        '/b2b/auth/activate/start',
        {'phone_number': phone},
      );

      final id = response['challenge_id']?.toString();
      if (id == null || id.isEmpty) {
        throw const B2BApiException('Aktivasyon doğrulaması başlatılamadı.');
      }

      setState(() {
        normalizedPhone = phone;
        challengeId = id;
        final parsedCodeLength = int.tryParse('${response['code_length']}');
        codeLength = parsedCodeLength != null &&
                parsedCodeLength >= 4 &&
                parsedCodeLength <= 10
            ? parsedCodeLength
            : 6;
      });
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> verifyActivation() async {
    final id = challengeId;
    final phone = normalizedPhone;
    final code = codeController.text.trim();
    final password = passwordController.text;
    final passwordAgain = passwordAgainController.text;

    if (id == null || phone == null) {
      _error('Önce aktivasyon SMS kodu isteyin.');
      return;
    }

    if (code.length != codeLength) {
      _error('$codeLength haneli SMS kodunu giriniz.');
      return;
    }

    if (password.length < 10) {
      _error('Şifre en az 10 karakter olmalıdır.');
      return;
    }

    if (password != passwordAgain) {
      _error('Şifreler aynı değil.');
      return;
    }

    setState(() => loading = true);

    try {
      await api.post(
        '/b2b/auth/activate/verify',
        {
          'challenge_id': id,
          'code': code,
          'password': password,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kurumsal hesabınız aktive edildi. Şimdi giriş yapabilirsiniz.',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => B2BLoginScreen(initialPhone: phone),
        ),
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
    final started = challengeId != null;

    return FlowScaffold(
      title: 'Kurumsal Aktivasyon',
      bottom: PrimaryButton(
        text: started ? 'Aktivasyonu Tamamla' : 'Aktivasyon Kodu Gönder',
        loading: loading,
        onPressed: started ? verifyActivation : startActivation,
      ),
      children: [
        const FlowHeader(
          icon: Icons.verified_user_outlined,
          eyebrow: 'İlk Aktivasyon',
          title: 'Kurumsal hesabınızı aktive edin',
          subtitle:
              'RiskMetriks tarafından yetkili olarak kaydedilen telefon numaranızı doğrulayın ve kurumsal şifrenizi oluşturun.',
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
              if (started) ...[
                const SizedBox(height: 14),
                FlowTextField(
                  controller: codeController,
                  label: 'SMS doğrulama kodu',
                  keyboardType: TextInputType.number,
                  maxLength: codeLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 14),
                FlowTextField(
                  controller: passwordController,
                  label: 'Yeni kurumsal şifre',
                  obscureText: true,
                  helper: 'En az 10 karakter.',
                ),
                const SizedBox(height: 14),
                FlowTextField(
                  controller: passwordAgainController,
                  label: 'Şifre tekrar',
                  obscureText: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
