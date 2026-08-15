import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class B2BReferralChoiceScreen extends StatefulWidget {
  final String referralToken;

  const B2BReferralChoiceScreen({
    super.key,
    required this.referralToken,
  });

  @override
  State<B2BReferralChoiceScreen> createState() =>
      _B2BReferralChoiceScreenState();
}

class _B2BReferralChoiceScreenState extends State<B2BReferralChoiceScreen> {
  final ApiClient api = ApiClient();

  Map<String, dynamic>? referral;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await api.get(
        '/b2b/referrals/${Uri.encodeComponent(widget.referralToken)}',
      );

      if (!mounted) return;

      setState(() {
        referral = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _value(
    String key, [
    String fallback = '',
  ]) {
    final value = referral?[key]?.toString().trim();

    if (value == null || value.isEmpty) {
      return fallback;
    }

    return value;
  }

  void _corporate() {
    final data = referral;

    if (data == null) return;

    AppState.instance.configureB2BReferral(
      referralToken: widget.referralToken,
      organizationName: _value(
        'organization_name',
      ),
      consentTextVersion: _value(
        'consent_text_version',
      ),
      consentText: _value(
        'consent_text',
      ),
    );

    AppState.instance.selectB2BCorporateFlow();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  void _individual() {
    AppState.instance.clearB2BReferralContext();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return PremiumCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: FlowColors.softGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: FlowColors.teal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: FlowColors.navyDark,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: const TextStyle(
                      color: FlowColors.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: FlowColors.navy,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const FlowScaffold(
        showBack: false,
        children: [
          SizedBox(height: 80),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (error != null || referral == null) {
      return FlowScaffold(
        showBack: false,
        title: 'Kurumsal Başvuru',
        children: [
          const FlowHeader(
            icon: Icons.link_off_rounded,
            eyebrow: 'Başvuru bağlantısı',
            title: 'Davet bağlantısı kullanılamıyor',
            subtitle:
                'Bağlantının süresi dolmuş, iptal edilmiş veya daha önce kullanılmış olması mümkündür.',
          ),
          const SizedBox(height: 20),
          if (error != null)
            PremiumCard(
              child: Text(
                error!,
                style: const TextStyle(
                  color: FlowColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
        bottom: PrimaryButton(
          text: 'Tekrar Dene',
          onPressed: _load,
        ),
      );
    }

    final organizationName = _value(
      'organization_name',
      'Kurumsal kiralama firması',
    );

    return FlowScaffold(
      showBack: false,
      title: 'Başvuru',
      children: [
        FlowHeader(
          icon: Icons.business_center_outlined,
          eyebrow: 'Davetli başvuru',
          title: organizationName,
          subtitle: 'Başvurunuza nasıl devam etmek istediğinizi seçin.',
        ),
        const SizedBox(height: 22),
        _option(
          icon: Icons.business_rounded,
          title: _value(
            'corporate_option_title',
            'Kurumsal başvuruya devam et',
          ),
          description: _value(
            'corporate_option_description',
            'Başvuru ücretiniz kurum tarafından karşılanır. Sonuç raporu, ayrıca vereceğiniz açık rıza sonrasında kurumla paylaşılır.',
          ),
          onTap: _corporate,
        ),
        const SizedBox(height: 14),
        _option(
          icon: Icons.person_outline_rounded,
          title: _value(
            'individual_option_title',
            'Bireysel devam et — Ücreti ben ödeyeceğim',
          ),
          description: _value(
            'individual_option_description',
            'Sonuç raporunuz kuruma otomatik paylaşılmaz. Olumlu sonuçlanırsa hizmet ücretini kendiniz ödersiniz.',
          ),
          onTap: _individual,
        ),
        const SizedBox(height: 16),
        const TrustNotice(
          icon: Icons.info_outline_rounded,
          text:
              'Kurumsal seçeneği seçmeniz açık rıza anlamına gelmez. Sonuç raporunun kurumla paylaşılması için açık rızanız daha sonra ayrıca alınacaktır.',
        ),
      ],
    );
  }
}
