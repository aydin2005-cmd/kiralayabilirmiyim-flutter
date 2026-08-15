import 'package:flutter/material.dart';

import '../models/application_type.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'car_rental_form_screen.dart';
import 'home_rental_form_screen.dart';

class B2BReportConsentScreen extends StatefulWidget {
  final ApplicationType applicationType;

  const B2BReportConsentScreen({
    super.key,
    required this.applicationType,
  });

  @override
  State<B2BReportConsentScreen> createState() => _B2BReportConsentScreenState();
}

class _B2BReportConsentScreenState extends State<B2BReportConsentScreen> {
  final ApiClient api = ApiClient();

  bool accepted = false;
  bool loading = false;

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _continueToForm() {
    final Widget destination =
        widget.applicationType == ApplicationType.homeRental
            ? const HomeRentalFormScreen()
            : const CarRentalFormScreen();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => destination,
      ),
    );
  }

  Future<void> _continueCorporate() async {
    if (!accepted || loading) return;

    final state = AppState.instance;

    final token = state.b2bReferralToken;
    final applicationId = state.applicationId;
    final consentVersion = state.b2bConsentTextVersion;

    if (token == null ||
        token.isEmpty ||
        applicationId == null ||
        applicationId.isEmpty ||
        consentVersion == null ||
        consentVersion.isEmpty) {
      _showError(
        'Kurumsal başvuru bilgileri eksik. Davet bağlantısını yeniden açınız.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await api.post(
        '/b2b/referrals/${Uri.encodeComponent(token)}/bind',
        {
          'application_id': applicationId,
          'report_share_consent': true,
          'consent_text_version': consentVersion,
        },
      );

      // Bind başarıyla tamamlandıktan sonra
      // kurumsal ilişki backend'de kalıcıdır.
      // Tek kullanımlık davet client state'inde
      // yeniden tutulmaz.
      state.clearB2BReferralContext();

      if (!mounted) return;

      _continueToForm();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _continueIndividual() {
    if (loading) return;

    // Açık rıza verilmezse kurumsal bind
    // oluşturulmaz. Aynı application normal
    // B2C yolundan devam eder.
    AppState.instance.clearB2BReferralContext();

    _continueToForm();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    final organizationName =
        state.b2bOrganizationName ?? 'Kurumsal kiralama firması';

    final consentText = state.b2bConsentText ?? '';

    if (!state.hasPendingB2BCorporateFlow || consentText.isEmpty) {
      return FlowScaffold(
        title: 'Kurumsal Başvuru',
        children: const [
          FlowHeader(
            icon: Icons.warning_amber_rounded,
            eyebrow: 'Kurumsal başvuru',
            title: 'Davet bilgileri eksik',
            subtitle:
                'Kurumsal başvuru bilgileri bulunamadı. Bireysel olarak devam edebilirsiniz.',
          ),
        ],
        bottom: PrimaryButton(
          text: 'Bireysel Devam Et',
          onPressed: _continueIndividual,
        ),
      );
    }

    return FlowScaffold(
      title: 'Sonuç Raporu Paylaşımı',
      children: [
        FlowHeader(
          icon: Icons.verified_user_outlined,
          eyebrow: 'Açık rıza',
          title: 'Sonuç raporunuzun paylaşımı',
          subtitle:
              '$organizationName tarafından karşılanan kurumsal başvuruya devam etmek için aşağıdaki açık rızayı ayrıca vermeniz gerekir.',
        ),
        const SizedBox(height: 22),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Açık Rıza Metni',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: FlowColors.navyDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                consentText,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const TrustNotice(
                icon: Icons.picture_as_pdf_outlined,
                text:
                    'Bu onay yalnız Kiralayabilir Miyim Sonuç Raporu içindir. Yüklediğiniz ham Findeks Risk Raporu kuruma paylaşılmaz.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: CheckboxListTile(
            value: accepted,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: loading
                ? null
                : (value) {
                    setState(
                      () => accepted = value ?? false,
                    );
                  },
            title: const Text(
              'Yukarıdaki açık rıza metnini okudum ve Sonuç Raporumun belirtilen kurumla paylaşılmasına açık rıza veriyorum.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: FlowColors.navyDark,
              ),
            ),
          ),
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            text: 'Kurumsal Başvuruya Devam Et',
            loading: loading,
            onPressed: accepted ? _continueCorporate : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loading ? null : _continueIndividual,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text(
                'Bireysel devam et — Ücreti ben ödeyeceğim',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
