import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
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
  final billingAddressController = TextEditingController();
  final ownerPhoneController = TextEditingController();

  late final B2BApiClient api;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
  }

  @override
  void dispose() {
    legalNameController.dispose();
    taxNumberController.dispose();
    billingAddressController.dispose();
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

  String _registrationErrorMessage(Object error) {
    if (error is B2BApiException) {
      switch (error.message) {
        case 'Bu vergi numarası ile kayıtlı bir kurum bulunmaktadır.':
        case 'Bu telefon numarası başka bir kurumsal kullanıcıda kayıtlıdır.':
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
    final billingAddress = billingAddressController.text.trim();
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

    if (billingAddress.isEmpty) {
      _showMessage('Fatura adresi giriniz.');
      return;
    }

    if (ownerPhone == null) {
      _showMessage('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.registerSelfService(
        legalName: legalName,
        taxNumber: taxNumber,
        billingAddress: billingAddress,
        ownerPhone: ownerPhone,
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
                controller: billingAddressController,
                label: 'Fatura Adresi',
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
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
            ],
          ),
        ),
      ],
    );
  }
}
