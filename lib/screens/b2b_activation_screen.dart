import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../services/otp_autofill_coordinator.dart';
import '../services/sms_retriever_service.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'b2b_login_screen.dart';

class B2BActivationScreen extends StatefulWidget {
  final String? initialPhone;
  final B2BApiClient? apiClient;

  const B2BActivationScreen({
    super.key,
    this.initialPhone,
    this.apiClient,
  });

  @override
  State<B2BActivationScreen> createState() => _B2BActivationScreenState();
}

class _B2BActivationScreenState extends State<B2BActivationScreen> {
  late final TextEditingController phoneController;
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordAgainController = TextEditingController();
  late final B2BApiClient api;
  late final OtpAutofillCoordinator otpAutofill;

  String? challengeId;
  String? normalizedPhone;
  int codeLength = 6;
  bool loading = false;
  List<Map<String, dynamic>> organizationChoices = [];

  bool get selectingOrganization =>
      organizationChoices.isNotEmpty && challengeId != null;

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController(
      text: turkeyMobileFieldDigits(widget.initialPhone ?? ''),
    );
    api = widget.apiClient ?? B2BApiClient();
    otpAutofill = OtpAutofillCoordinator(
      controller: codeController,
      codeLength: () => codeLength,
      isActive: () =>
          mounted && !loading && challengeId != null && !selectingOrganization,
      canAutoSubmit: () {
        return mounted &&
            !loading &&
            challengeId != null &&
            !selectingOrganization &&
            passwordController.text.length >= 10 &&
            passwordController.text == passwordAgainController.text;
      },
      submit: verifyActivation,
      messages: SmsRetrieverService.instance.messages,
      takePendingMessage: SmsRetrieverService.instance.takePendingMessage,
      stopRetriever: SmsRetrieverService.instance.stop,
    );
  }

  @override
  void dispose() {
    otpAutofill.dispose();
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

  String _otpStartErrorMessage(Object error) {
    return _rateLimitedErrorMessage(
      error,
      'Çok fazla SMS kodu istendi. Lütfen daha sonra tekrar deneyin.',
    );
  }

  String _otpVerifyErrorMessage(Object error) {
    return _rateLimitedErrorMessage(
      error,
      'Çok fazla doğrulama denemesi yapıldı. Lütfen daha sonra tekrar deneyin.',
    );
  }

  String _rateLimitedErrorMessage(Object error, String fallback) {
    if (error is B2BApiException && error.statusCode == 429) {
      const generic =
          'Kurumsal işlem şu anda tamamlanamadı. Lütfen tekrar deneyin.';
      final raw = error.message.trim();
      final message = raw.isEmpty || raw == generic ? fallback : raw;
      final hint = formatRetryAfterHint(error.retryAfterSeconds);
      return hint == null ? message : '$message\n$hint';
    }

    return error.toString();
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
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .where(
          (item) =>
              (item['organization_id']?.toString() ?? '').isNotEmpty &&
              (item['organization_name']?.toString() ?? '').isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> startActivation() async {
    if (loading) {
      return;
    }

    final phone = normalizeTurkeyMobile(phoneController.text);
    if (phone == null) {
      _error('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    setState(() => loading = true);

    var smsRetrieverStarted = false;

    try {
      smsRetrieverStarted = await SmsRetrieverService.instance.start();

      final response = await api.post(
        '/b2b/auth/activate/start',
        {'phone_number': phone},
      );

      final id = response['challenge_id']?.toString();
      if (id == null || id.isEmpty) {
        throw const B2BApiException('Aktivasyon doğrulaması başlatılamadı.');
      }

      if (!mounted) {
        if (smsRetrieverStarted) {
          await SmsRetrieverService.instance.stop();
        }
        return;
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
        codeController.clear();
        loading = false;
      });

      otpAutofill.start();
    } catch (e) {
      if (smsRetrieverStarted) {
        await SmsRetrieverService.instance.stop();
      }

      _error(_otpStartErrorMessage(e));

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> verifyActivation() => _verifyActivation();

  Future<void> _verifyActivation({
    String? organizationId,
  }) async {
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

    if (loading) {
      return;
    }

    setState(() => loading = true);

    try {
      final body = <String, dynamic>{
        'challenge_id': id,
        'code': code,
        'password': password,
      };

      if (organizationId != null && organizationId.isNotEmpty) {
        body['organization_id'] = organizationId;
      }

      final response = await api.post(
        '/b2b/auth/activate/verify',
        body,
      );

      if (response['selection_required'] == true) {
        final choices = _organizationChoicesFrom(response);

        if (choices.isEmpty) {
          throw const B2BApiException(
            'Firma seçimi bilgisi alınamadı.',
          );
        }

        await SmsRetrieverService.instance.stop();

        if (!mounted) {
          return;
        }

        setState(() {
          organizationChoices = choices;
          loading = false;
        });

        return;
      }

      organizationChoices = const <Map<String, dynamic>>[];

      await SmsRetrieverService.instance.stop();
      TextInput.finishAutofillContext(shouldSave: false);

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
          builder: (_) => B2BLoginScreen(
            initialPhone: phone,
            apiClient: api,
          ),
        ),
      );
    } catch (e) {
      _error(_otpVerifyErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final started = challengeId != null;
    final choosingOrganization = selectingOrganization;

    return FlowScaffold(
      title: 'Kurumsal Aktivasyon',
      bottom: PrimaryButton(
        text: choosingOrganization
            ? 'Firma Seçin'
            : started
                ? 'Aktivasyonu Tamamla'
                : 'Aktivasyon Kodu Gönder',
        loading: loading,
        onPressed: choosingOrganization
            ? () => _error(
                  'Devam etmek için bir firma seçiniz.',
                )
            : started
                ? verifyActivation
                : startActivation,
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
                helper: 'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                prefixText: '+90 ',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: const [
                  TurkeyMobileFieldFormatter(),
                ],
              ),
              if (started) ...[
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
                  onSubmitted: (_) => verifyActivation(),
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
                if (choosingOrganization) ...[
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Firma Seçimi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Telefon numaranız doğrulandı. '
                      'Aktive etmek istediğiniz firmayı seçin.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...organizationChoices.map(
                    (organization) {
                      final organizationId =
                          organization['organization_id']?.toString() ?? '';
                      final organizationName =
                          organization['organization_name']?.toString() ?? '-';
                      final organizationRole =
                          organization['role']?.toString() ?? '';

                      return Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          key: ValueKey(
                            'b2b-activation-org-$organizationId',
                          ),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.business_outlined,
                          ),
                          title: Text(
                            organizationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: organizationRole.isEmpty
                              ? null
                              : Text('Rol: $organizationRole'),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                          onTap: loading || organizationId.isEmpty
                              ? null
                              : () => _verifyActivation(
                                    organizationId: organizationId,
                                  ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
