import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/legal_links.dart';
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
  bool kvkkNoticeAccepted = false;
  final api = ApiClient();

  String? normalizedTurkeyMobile() {
    var digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12)
      digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 11)
      digits = digits.substring(1);
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return null;
    return '+90$digits';
  }

  Future<void> requestOtp() async {
    final phone = normalizedTurkeyMobile();
    if (phone == null)
      return _showError(
          'Lütfen geçerli bir Türkiye cep telefonu numarası giriniz.');

    if (!kvkkNoticeAccepted) {
      return _showError(
          'SMS kodu gönderebilmek için Kişisel Verilerin İşlenmesine İlişkin Aydınlatma Metni’ni okuyup onaylamanız gerekir.');
    }

    setState(() => loading = true);
    try {
      final response = await api.post('/auth/otp/start',
          {'phone_number': phone, 'kvkk_notice_accepted': kvkkNoticeAccepted});
      final challengeId = response['challenge_id']?.toString();
      if (challengeId == null || challengeId.isEmpty)
        throw ApiException('Doğrulama kaydı oluşturulamadı.');
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  OtpScreen(phoneNumber: phone, challengeId: challengeId)));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Giriş',
      children: [
        const FlowHeader(
            icon: Icons.sms_outlined,
            eyebrow: 'Güvenli giriş',
            title: 'Telefonunuzu doğrulayalım',
            subtitle:
                'Başvurunun size ait olduğunu doğrulamak ve rapor linklerinizi güvenli yönetmek için telefon doğrulaması yapılır.'),
        const SizedBox(height: 22),
        PremiumCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FlowTextField(
            controller: phoneController,
            label: 'Cep telefonu',
            keyboardType: TextInputType.phone,
            maxLength: 13,
            prefixText: '+90 ',
            helper: 'Numaranızın başında 0 olmadan giriniz.',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]'))
            ],
          ),
          const SizedBox(height: 12),
          const TrustNotice(
              icon: Icons.info_outline_rounded,
              text: 'Telefonunuza SMS doğrulama kodu gönderilecektir.'),
        ])),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: kvkkNoticeAccepted,
                  onChanged: loading
                      ? null
                      : (value) =>
                          setState(() => kvkkNoticeAccepted = value ?? false),
                  title: const Text(
                    'KVKK Aydınlatma Metni’ni okudum, onaylıyorum.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: FlowColors.navyDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: loading
                        ? null
                        : () => LegalLinks.open(context, LegalLinks.kvkk),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('KVKK Aydınlatma Metni’ni Aç'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            text: 'SMS Kodu Gönder',
            loading: loading,
            onPressed: requestOtp,
          ),
        ],
      ),
    );
  }
}
