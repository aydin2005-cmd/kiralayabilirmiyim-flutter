import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../services/otp_autofill_coordinator.dart';
import '../services/sms_retriever_service.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'b2b_password_reset_screen.dart';
import 'b2b_portal_screen.dart';

class B2BLoginScreen extends StatefulWidget {
  final String? initialPhone;
  final B2BApiClient? apiClient;

  const B2BLoginScreen({
    super.key,
    this.initialPhone,
    this.apiClient,
  });

  @override
  State<B2BLoginScreen> createState() => _B2BLoginScreenState();
}

class _B2BLoginScreenState extends State<B2BLoginScreen> {
  late final TextEditingController phoneController;
  final passwordController = TextEditingController();
  final codeController = TextEditingController();
  late final B2BApiClient api;
  late final OtpAutofillCoordinator otpAutofill;

  String? challengeId;
  int codeLength = 6;
  bool loading = false;
  List<Map<String, dynamic>> organizationChoices = [];
  int credentialRevision = 0;

  bool get selectingOrganization =>
      organizationChoices.isNotEmpty && challengeId == null;

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

  Future<void> _onCredentialChanged(String _) async {
    credentialRevision += 1;

    final hasCredentialBoundState = organizationChoices.isNotEmpty ||
        challengeId != null ||
        codeController.text.isNotEmpty;

    if (!hasCredentialBoundState) {
      return;
    }

    setState(() {
      organizationChoices = const <Map<String, dynamic>>[];
      challengeId = null;
      codeLength = 6;
      codeController.clear();
    });

    await SmsRetrieverService.instance.stop();
  }

  Future<void> startLogin() => _startLogin();

  Future<void> _startLogin({
    String? organizationId,
  }) async {
    if (loading) {
      return;
    }

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

    final requestCredentialRevision = credentialRevision;

    setState(() => loading = true);

    var smsRetrieverStarted = false;

    try {
      smsRetrieverStarted = await SmsRetrieverService.instance.start();

      final body = <String, dynamic>{
        'phone_number': phone,
        'password': password,
      };

      if (organizationId != null && organizationId.isNotEmpty) {
        body['organization_id'] = organizationId;
      }

      final response = await api.post(
        '/b2b/auth/login/start',
        body,
      );

      if (requestCredentialRevision != credentialRevision) {
        if (smsRetrieverStarted) {
          await SmsRetrieverService.instance.stop();
        }

        if (mounted) {
          setState(() => loading = false);
        }

        return;
      }

      if (response['selection_required'] == true) {
        final choices = _organizationChoicesFrom(response);

        if (choices.isEmpty) {
          throw const B2BApiException(
            'Firma seçimi bilgisi alınamadı.',
          );
        }

        if (smsRetrieverStarted) {
          await SmsRetrieverService.instance.stop();
          smsRetrieverStarted = false;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          challengeId = null;
          organizationChoices = choices;
          loading = false;
        });

        return;
      }

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
        organizationChoices = const <Map<String, dynamic>>[];
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
      _error(_otpVerifyErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _openPasswordReset() async {
    await SmsRetrieverService.instance.stop();

    if (!mounted) {
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => B2BPasswordResetScreen(
          initialPhone: phoneController.text,
          apiClient: api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitingOtp = challengeId != null;
    final choosingOrganization = selectingOrganization;

    return FlowScaffold(
      title: 'Kurumsal Giriş',
      bottom: PrimaryButton(
        text: choosingOrganization
            ? 'Firma Seçin'
            : waitingOtp
                ? 'SMS Kodunu Doğrula'
                : 'Giriş Kodu Gönder',
        loading: loading,
        onPressed: choosingOrganization
            ? () => _error(
                  'Devam etmek için bir firma seçiniz.',
                )
            : waitingOtp
                ? verifyLogin
                : startLogin,
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
                helper: 'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                prefixText: '+90 ',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: const [
                  TurkeyMobileFieldFormatter(),
                ],
                onChanged: _onCredentialChanged,
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: passwordController,
                label: 'Kurumsal şifre',
                obscureText: true,
                onChanged: _onCredentialChanged,
              ),
              if (!waitingOtp && !choosingOrganization)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading ? null : _openPasswordReset,
                    child: const Text('Şifremi Unuttum'),
                  ),
                ),
              if (choosingOrganization) ...[
                const SizedBox(height: 14),
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
                    'Birden fazla kurumsal kaydınız bulundu. '
                    'Devam etmek istediğiniz firmayı seçin.',
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
                          'b2b-login-org-$organizationId',
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
                            : () => _startLogin(
                                  organizationId: organizationId,
                                ),
                      ),
                    );
                  },
                ),
              ],
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
