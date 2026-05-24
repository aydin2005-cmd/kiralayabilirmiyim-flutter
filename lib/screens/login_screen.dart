import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  bool loading = false;
  final api = ApiClient();

  String? normalizedTurkeyMobile() {
    var digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return null;
    return '+90$digits';
  }

  Future<void> requestOtp() async {
    final phone = normalizedTurkeyMobile();
    if (phone == null) return _showError('Lütfen geçerli bir Türkiye cep telefonu numarası giriniz.');
    setState(() => loading = true);
    try {
      await api.post('/auth/request-otp', {'phone_number': phone});
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phone)));
    } catch (e) { _showError(e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Giriş',
      children: [
        const FlowHeader(icon: Icons.sms_outlined, eyebrow: 'Güvenli giriş', title: 'Cep telefonunuzu doğrulayalım', subtitle: 'Rapor ve paylaşım işlemleri için telefon doğrulaması yapılır.'),
        const SizedBox(height: 22),
        PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FlowTextField(
            controller: phoneController,
            label: 'Cep telefonu',
            keyboardType: TextInputType.phone,
            maxLength: 13,
            prefixText: '+90 ',
            helper: 'Numaranızı başında 0 olmadan giriniz. Örnek: 532 123 45 67',
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]'))],
          ),
          const SizedBox(height: 12),
          const TrustNotice(icon: Icons.info_outline_rounded, text: 'Demo backend için SMS kodu: 123456'),
        ])),
      ],
      bottom: PrimaryButton(text: 'SMS Kodu Gönder', loading: loading, onPressed: requestOtp),
    );
  }
}
