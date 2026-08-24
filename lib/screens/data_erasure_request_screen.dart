import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';

class DataErasureRequestScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const DataErasureRequestScreen({
    super.key,
    this.apiClient,
  });

  @override
  State<DataErasureRequestScreen> createState() =>
      _DataErasureRequestScreenState();
}

class _DataErasureRequestScreenState
    extends State<DataErasureRequestScreen> {
  late final ApiClient api;
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  bool loading = false;
  bool waitingOtp = false;
  bool completed = false;
  String? challengeId;
  int codeLength = 6;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? ApiClient();
  }

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String? _normalizedTurkeyMobile() {
    var digits = phoneController.text.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (digits.startsWith('90') && digits.length == 12) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) {
      return null;
    }

    return '+90$digits';
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _startVerification() async {
    final phone = _normalizedTurkeyMobile();

    if (phone == null) {
      _showError(
        'Lütfen geçerli bir Türkiye cep telefonu numarası giriniz.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.post(
        '/auth/data-erasure/start',
        {
          'phone_number': phone,
        },
      );

      final id = response['challenge_id']?.toString() ?? '';
      if (id.isEmpty) {
        throw ApiException(
          'Doğrulama kaydı oluşturulamadı.',
        );
      }

      final returnedLength = int.tryParse(
        response['code_length']?.toString() ?? '',
      );

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      setState(() {
        challengeId = id;
        codeLength = returnedLength != null &&
                returnedLength >= 4 &&
                returnedLength <= 10
            ? returnedLength
            : 6;
        waitingOtp = true;
        otpController.clear();
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _verifyRequest() async {
    final id = challengeId;
    final code = otpController.text.trim();

    if (id == null || id.isEmpty) {
      _showError('Doğrulama kaydı bulunamadı.');
      return;
    }

    if (!RegExp('^\\d{$codeLength}\$').hasMatch(code)) {
      _showError(
        'Lütfen $codeLength haneli SMS kodunu giriniz.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await api.post(
        '/auth/data-erasure/verify',
        {
          'challenge_id': id,
          'code': code,
        },
      );

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      setState(() {
        completed = true;
        waitingOtp = false;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _changePhone() {
    setState(() {
      waitingOtp = false;
      challengeId = null;
      otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return FlowScaffold(
        title: 'Veri Silme Talebi',
        children: const [
          FlowHeader(
            icon: Icons.verified_user_outlined,
            eyebrow: 'Doğrulama tamamlandı',
            title: 'Talebiniz doğrulandı',
            subtitle:
                'Telefon doğrulamanız tamamlandı. Talebiniz destek ekibimiz tarafından güvenli veri silme prosedürü kapsamında değerlendirilecektir.',
          ),
          SizedBox(height: 18),
          TrustNotice(
            icon: Icons.privacy_tip_outlined,
            text:
                'Bu ekran, sistemimizde size ait bir kayıt bulunup bulunmadığı konusunda bilgi vermez. Yasal olarak saklanması gereken kayıtlar yürürlükteki saklama politikalarına göre korunabilir.',
          ),
        ],
      );
    }

    return FlowScaffold(
      title: 'Veri Silme Talebi',
      children: [
        FlowHeader(
          icon: waitingOtp
              ? Icons.sms_outlined
              : Icons.delete_outline_rounded,
          eyebrow: waitingOtp
              ? 'Telefon doğrulama'
              : 'Kişisel veriler',
          title: waitingOtp
              ? 'SMS kodunu girin'
              : 'Veri silme talebinizi doğrulayın',
          subtitle: waitingOtp
              ? 'Telefonunuza gönderilen doğrulama kodunu girerek talebinizi doğrulayın.'
              : 'Güvenliğiniz için veri silme talepleri, ilgili telefon numarasına gönderilen SMS kodu ile doğrulanır.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!waitingOtp)
                FlowTextField(
                  key: const ValueKey(
                    'data-erasure-phone-field',
                  ),
                  controller: phoneController,
                  label: 'Cep telefonu',
                  helper:
                      'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                  prefixText: '+90 ',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  autofillHints: const [
                    AutofillHints.telephoneNumber,
                  ],
                )
              else
                FlowTextField(
                  key: const ValueKey(
                    'data-erasure-otp-field',
                  ),
                  controller: otpController,
                  label: 'SMS doğrulama kodu',
                  keyboardType: TextInputType.number,
                  maxLength: codeLength,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      codeLength,
                    ),
                  ],
                  autofillHints: const [
                    AutofillHints.oneTimeCode,
                  ],
                  onSubmitted: (_) {
                    if (!loading) {
                      _verifyRequest();
                    }
                  },
                ),
              const SizedBox(height: 12),
              const TrustNotice(
                icon: Icons.info_outline_rounded,
                text:
                    'Telefon doğrulaması yalnızca talebi yapan kişinin yetkisini kontrol eder; bu aşamada hiçbir veri silinmez.',
              ),
              if (waitingOtp) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: loading ? null : _changePhone,
                  child: const Text(
                    'Telefon numarasını değiştir',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: PrimaryButton(
        text: waitingOtp
            ? 'Talebi Doğrula'
            : 'SMS Kodu Gönder',
        loading: loading,
        onPressed: waitingOtp
            ? _verifyRequest
            : _startVerification,
      ),
    );
  }
}
