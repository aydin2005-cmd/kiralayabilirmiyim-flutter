import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';

class B2BPasswordResetScreen extends StatefulWidget {
  final String? initialPhone;
  final B2BApiClient? apiClient;

  const B2BPasswordResetScreen({
    super.key,
    this.initialPhone,
    this.apiClient,
  });

  @override
  State<B2BPasswordResetScreen> createState() =>
      _B2BPasswordResetScreenState();
}

class _B2BPasswordResetScreenState extends State<B2BPasswordResetScreen> {
  late final B2BApiClient api;
  late final TextEditingController phoneController;
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordAgainController = TextEditingController();

  String? challengeId;
  int codeLength = 6;
  bool loading = false;
  List<Map<String, dynamic>> organizationChoices = [];

  bool get waitingForCode => challengeId != null;
  bool get selectingOrganization => organizationChoices.isNotEmpty;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
    phoneController = TextEditingController(
      text: turkeyMobileFieldDigits(widget.initialPhone ?? ''),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    passwordController.dispose();
    passwordAgainController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  List<Map<String, dynamic>> _organizationChoicesFrom(
    Map<String, dynamic> response,
  ) {
    final rawOrganizations = response['organizations'];

    if (rawOrganizations is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawOrganizations
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              (item['organization_id']?.toString() ?? '').isNotEmpty &&
              (item['organization_name']?.toString() ?? '').isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> startReset() async {
    if (loading) {
      return;
    }

    final phone = normalizeTurkeyMobile(phoneController.text);
    if (phone == null) {
      _message('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.postPublic(
        '/b2b/auth/password-reset/start',
        {
          'phone_number': phone,
        },
      );

      final id = response['challenge_id']?.toString();
      if (id == null || id.isEmpty) {
        throw const B2BApiException(
          'Şifre yenileme doğrulaması başlatılamadı.',
        );
      }

      final parsedCodeLength = int.tryParse('${response['code_length']}');
      final resolvedCodeLength = parsedCodeLength != null &&
              parsedCodeLength >= 4 &&
              parsedCodeLength <= 10
          ? parsedCodeLength
          : 6;

      final testCode = response['test_otp_code']?.toString().trim();

      if (!mounted) {
        return;
      }

      setState(() {
        challengeId = id;
        codeLength = resolvedCodeLength;
        organizationChoices = const <Map<String, dynamic>>[];
        codeController.text =
            testCode == null || testCode.isEmpty ? '' : testCode;
      });

      _message(
        'Hesabınız uygunsa doğrulama kodu cep telefonunuza gönderildi.',
      );
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> verifyReset({
    String? organizationId,
  }) async {
    if (loading) {
      return;
    }

    if (selectingOrganization &&
        (organizationId == null || organizationId.isEmpty)) {
      _message('Şifresini yenilemek istediğiniz kurumu seçiniz.');
      return;
    }

    final id = challengeId;
    if (id == null) {
      _message('Önce şifre yenileme kodu isteyin.');
      return;
    }

    final code = codeController.text.trim();
    if (code.length != codeLength) {
      _message('$codeLength haneli SMS kodunu giriniz.');
      return;
    }

    final newPassword = passwordController.text;
    final passwordAgain = passwordAgainController.text;

    if (newPassword.length < 10) {
      _message('Yeni şifre en az 10 karakter olmalıdır.');
      return;
    }

    if (newPassword != passwordAgain) {
      _message('Yeni şifreler birbiriyle aynı olmalıdır.');
      return;
    }

    setState(() => loading = true);

    try {
      final payload = <String, dynamic>{
        'challenge_id': id,
        'code': code,
        'new_password': newPassword,
      };

      if (organizationId != null && organizationId.isNotEmpty) {
        payload['organization_id'] = organizationId;
      }

      final response = await api.postPublic(
        '/b2b/auth/password-reset/verify',
        payload,
      );

      if (response['selection_required'] == true) {
        final choices = _organizationChoicesFrom(response);
        if (choices.isEmpty) {
          throw const B2BApiException(
            'Kurum seçimi bilgisi alınamadı.',
          );
        }

        if (!mounted) {
          return;
        }

        setState(() {
          organizationChoices = choices;
        });

        _message(
          'Telefon doğrulandı. Şifresini yenilemek istediğiniz kurumu seçiniz.',
        );
        return;
      }

      if (response['success'] != true) {
        throw const B2BApiException(
          'Şifre yenileme işlemi tamamlanamadı.',
        );
      }

      TextInput.finishAutofillContext(shouldSave: false);

      if (!mounted) {
        return;
      }

      final organizationName =
          response['organization_name']?.toString().trim();
      final prefix = organizationName == null || organizationName.isEmpty
          ? 'Kurumsal şifreniz'
          : '$organizationName şifreniz';

      _message(
        '$prefix yenilendi. Yeni şifrenizle giriş yapabilirsiniz.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void resetPhoneStep() {
    setState(() {
      challengeId = null;
      organizationChoices = const <Map<String, dynamic>>[];
      codeController.clear();
      passwordController.clear();
      passwordAgainController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Şifremi Unuttum',
      bottom: PrimaryButton(
        text: selectingOrganization
            ? 'Kurum Seçiniz'
            : waitingForCode
                ? 'Şifreyi Yenile'
                : 'SMS Kodu Gönder',
        loading: loading,
        onPressed: selectingOrganization
            ? () => _message(
                  'Şifresini yenilemek istediğiniz kurumu seçiniz.',
                )
            : waitingForCode
                ? verifyReset
                : startReset,
      ),
      children: [
        const FlowHeader(
          icon: Icons.lock_reset_rounded,
          eyebrow: 'Kurumsal Hesap',
          title: 'Kurumsal şifrenizi yenileyin',
          subtitle:
              'Telefon doğrulamasından sonra yeni şifrenizi belirleyebilirsiniz. Aynı telefon birden fazla kurumda kayıtlıysa hangi kurumun şifresini yenilemek istediğinizi seçersiniz.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          child: Column(
            children: [
              FlowTextField(
                controller: phoneController,
                label: 'Yetkili cep telefonu',
                helper: 'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                prefixText: '+90 ',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                enabled: !waitingForCode && !loading,
                inputFormatters: const [
                  TurkeyMobileFieldFormatter(),
                ],
              ),
              if (waitingForCode) ...[
                const SizedBox(height: 14),
                FlowTextField(
                  controller: codeController,
                  label: 'SMS doğrulama kodu',
                  keyboardType: TextInputType.number,
                  maxLength: codeLength,
                  enabled: !selectingOrganization && !loading,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 14),
                FlowTextField(
                  controller: passwordController,
                  label: 'Yeni kurumsal şifre',
                  obscureText: true,
                  enabled: !selectingOrganization && !loading,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 14),
                FlowTextField(
                  controller: passwordAgainController,
                  label: 'Yeni kurumsal şifre tekrar',
                  obscureText: true,
                  enabled: !selectingOrganization && !loading,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => verifyReset(),
                ),
                if (selectingOrganization) ...[
                  const SizedBox(height: 18),
                  const TrustNotice(
                    icon: Icons.business_outlined,
                    text:
                        'Telefon numaranız birden fazla kurumsal hesapta kayıtlı. Yalnızca seçtiğiniz kurumun şifresi değiştirilecektir.',
                    background: FlowColors.tealSoft,
                    borderColor: FlowColors.teal,
                  ),
                  const SizedBox(height: 12),
                  ...organizationChoices.map((organization) {
                    final organizationId =
                        organization['organization_id']?.toString() ?? '';
                    final organizationName =
                        organization['organization_name']?.toString() ?? '-';
                    final role = organization['role']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loading || organizationId.isEmpty
                              ? null
                              : () => verifyReset(
                                    organizationId: organizationId,
                                  ),
                          icon: const Icon(Icons.business_rounded),
                          label: Text(
                            '$organizationName · ${b2bRoleLabel(role)}',
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: loading ? null : resetPhoneStep,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Telefon numarasını değiştir'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
