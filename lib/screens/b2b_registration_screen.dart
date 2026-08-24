import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../services/legal_links.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'b2b_activation_screen.dart';

class B2BRegistrationScreen extends StatefulWidget {
  final B2BApiClient? apiClient;

  const B2BRegistrationScreen({
    super.key,
    this.apiClient,
  });

  @override
  State<B2BRegistrationScreen> createState() => _B2BRegistrationScreenState();
}

class _B2BRegistrationScreenState extends State<B2BRegistrationScreen> {
  final legalNameController = TextEditingController();
  final taxNumberController = TextEditingController();
  final taxOfficeController = TextEditingController();
  final billingAddressController = TextEditingController();
  final contactEmailController = TextEditingController();
  final ownerPhoneController = TextEditingController();

  late final B2BApiClient api;
  bool loading = false;
  bool privacyNoticeAcknowledged = false;
  bool termsAccepted = false;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
  }

  @override
  void dispose() {
    legalNameController.dispose();
    taxNumberController.dispose();
    taxOfficeController.dispose();
    billingAddressController.dispose();
    contactEmailController.dispose();
    ownerPhoneController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String? _validateTaxNumber(String value) {
    final digits = value.trim();
    if (!RegExp(r'^\d{10}(\d)?$').hasMatch(digits)) {
      return 'Vergi numarası 10 veya 11 haneli olmalıdır.';
    }
    return null;
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi giriniz.';
    }
    return null;
  }

  String _rateLimitMessage(
    B2BApiException error,
    String fallback,
  ) {
    const generic =
        'Kurumsal işlem şu anda tamamlanamadı. Lütfen tekrar deneyin.';
    final raw = error.message.trim();
    final message = raw.isEmpty || raw == generic ? fallback : raw;
    final hint = formatRetryAfterHint(error.retryAfterSeconds);
    return hint == null ? message : '$message\n$hint';
  }

  String _registrationErrorMessage(Object error) {
    if (error is B2BApiException) {
      if (error.statusCode == 429) {
        return _rateLimitMessage(
          error,
          'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.',
        );
      }

      switch (error.message) {
        case 'Bu bilgilerle mevcut bir kurumsal hesap olabilir. Giriş yapmayı deneyin veya destek ile iletişime geçin.':
        case 'Geçerli bir Türkiye cep telefonu numarası giriniz.':
        case 'Vergi numarası 10 veya 11 haneli olmalıdır.':
          return error.message;
      }
    }

    return 'Kurumsal hesap oluşturulamadı. Lütfen tekrar deneyin.';
  }

  Future<void> submitRegistration() async {
    if (loading) {
      return;
    }

    final legalName = legalNameController.text.trim();
    final taxNumber = taxNumberController.text.trim();
    final taxOffice = taxOfficeController.text.trim();
    final billingAddress = billingAddressController.text.trim();
    final contactEmail = contactEmailController.text.trim();
    final ownerPhone = normalizeTurkeyMobile(ownerPhoneController.text);

    if (legalName.isEmpty) {
      _showMessage('Şirket / Ticari unvan giriniz.');
      return;
    }

    final taxError = _validateTaxNumber(taxNumber);
    if (taxError != null) {
      _showMessage(taxError);
      return;
    }

    if (taxOffice.isEmpty) {
      _showMessage('Vergi dairesi giriniz.');
      return;
    }

    if (billingAddress.isEmpty) {
      _showMessage('Fatura adresi giriniz.');
      return;
    }

    final emailError = _validateEmail(contactEmail);
    if (emailError != null) {
      _showMessage(emailError);
      return;
    }

    if (ownerPhone == null) {
      _showMessage('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    if (!privacyNoticeAcknowledged) {
      _showMessage(
        'KVKK Aydınlatma Metni’ni okuyup kabul etmeniz gerekir.',
      );
      return;
    }

    if (!termsAccepted) {
      _showMessage(
        'Kullanım Şartları’nı okuyup kabul etmeniz gerekir.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.registerSelfService(
        legalName: legalName,
        taxNumber: taxNumber,
        taxOffice: taxOffice,
        billingAddress: billingAddress,
        contactEmail: contactEmail,
        ownerPhone: ownerPhone,
        privacyNoticeAcknowledged: privacyNoticeAcknowledged,
        privacyNoticeVersion: B2BApiClient.b2bPrivacyNoticeVersion,
        termsAccepted: termsAccepted,
        termsVersion: B2BApiClient.b2bTermsVersion,
      );

      final success = response['success'] == true;
      final activationRequired = response['activation_required'] == true;
      final ownerPhoneE164 = response['owner_phone_e164']?.toString();
      final normalizedOwnerPhone =
          ownerPhoneE164 == null ? null : normalizeTurkeyMobile(ownerPhoneE164);

      if (!success ||
          !activationRequired ||
          ownerPhoneE164 == null ||
          ownerPhoneE164.isEmpty ||
          normalizedOwnerPhone == null) {
        throw const B2BApiException(
          'Kurumsal hesap oluşturulamadı. Lütfen tekrar deneyin.',
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kurumsal hesabınız oluşturuldu. Aktivasyonla devam edin.',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => B2BActivationScreen(
            initialPhone: normalizedOwnerPhone,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(_registrationErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Kurumsal Hesap Oluştur',
      bottom: PrimaryButton(
        text: 'Kurumsal Hesap Oluştur',
        loading: loading,
        onPressed: submitRegistration,
      ),
      children: [
        const FlowHeader(
          icon: Icons.add_business_outlined,
          eyebrow: 'Self Servis Kayıt',
          title: 'Kurumsal Hesap Oluştur',
          subtitle:
              'Kurumsal hesabınızı oluşturun, telefon doğrulamasının ardından paket satın alarak kullanmaya başlayın.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          child: Column(
            children: [
              FlowTextField(
                controller: legalNameController,
                label: 'Şirket / Ticari Unvan',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: taxNumberController,
                label: 'Vergi Numarası',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 11,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: taxOfficeController,
                label: 'Vergi Dairesi',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: billingAddressController,
                label: 'Fatura Adresi',
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: contactEmailController,
                label: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 14),
              FlowTextField(
                controller: ownerPhoneController,
                label: 'Yetkili Cep Telefonu',
                helper: 'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                prefixText: '+90 ',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                maxLength: 10,
                inputFormatters: const [
                  TurkeyMobileFieldFormatter(),
                ],
                onSubmitted: (_) => submitRegistration(),
              ),
              const SizedBox(height: 14),
              _LegalAcceptanceTile(
                value: privacyNoticeAcknowledged,
                text: 'KVKK Aydınlatma Metni’ni okudum ve kabul ediyorum.',
                linkText: 'KVKK Aydınlatma Metni’ni Aç',
                linkUrl: LegalLinks.kvkk,
                enabled: !loading,
                onChanged: (value) {
                  setState(
                    () => privacyNoticeAcknowledged = value,
                  );
                },
              ),
              const SizedBox(height: 10),
              _LegalAcceptanceTile(
                value: termsAccepted,
                text: 'Kullanım Şartları’nı okudum ve kabul ediyorum.',
                linkText: 'Kullanım Şartları’nı Aç',
                linkUrl: LegalLinks.terms,
                enabled: !loading,
                onChanged: (value) {
                  setState(
                    () => termsAccepted = value,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalAcceptanceTile extends StatelessWidget {
  final bool value;
  final String text;
  final String linkText;
  final String linkUrl;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _LegalAcceptanceTile({
    required this.value,
    required this.text,
    required this.linkText,
    required this.linkUrl,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: value,
            onChanged:
                enabled ? (checked) => onChanged(checked ?? false) : null,
            title: Text(
              text,
              style: const TextStyle(
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
              onPressed:
                  enabled ? () => LegalLinks.open(context, linkUrl) : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text(linkText),
            ),
          ),
        ],
      ),
    );
  }
}
