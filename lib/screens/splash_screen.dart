import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import '../services/legal_links.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      showBack: false,
      children: [
        const SizedBox(height: 22),
        const FlowHeader(
          icon: Icons.verified_user_rounded,
          eyebrow: 'KİRALAYABİLİR MİYİM?',
          title: 'Kiralama İçin Ön Değerlendirme',
          subtitle: '',
          richSubtitle: TextSpan(
            style: TextStyle(
              color: Color(0xFFE6F4F1),
              fontSize: 15.5,
              height: 1.38,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(text: 'Findeks Raporunuzu yükleyin. '),
              TextSpan(
                text:
                    'Kiralama başvurunuza özel geliştirilen Finansal Değerlendirme Raporunuzu alın. ',
              ),
              TextSpan(text: 'İstediğinizle paylaşın.'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const TrustNotice(
            icon: Icons.lock_outline_rounded,
            text:
                'Finansal bilgileriniz yalnızca değerlendirme ve sizin onayladığınız paylaşım akışı için kullanılır.'),
        const SizedBox(height: 12),
        const TrustNotice(
            icon: Icons.payments_outlined,
            text:
                'Ön değerlendirme ücretsizdir. Ödeme sonrası tam rapor, PDF ve paylaşım linki erişime açılır.'),
        const SizedBox(height: 12),
        const TrustNotice(
            icon: Icons.qr_code_rounded,
            text:
                'Paylaşılan sonuç raporu QR kod ve doğrulama kodu ile kontrol edilebilir.'),
        const SizedBox(height: 12),
        PremiumCard(
          background: const Color(0xFFF8FAFC),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RiskMetriks AŞ altyapısıyla',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: FlowColors.navyDark)),
            const SizedBox(height: 6),
            const Text(
                'Kiralayabilir Miyim, RiskMetriks AŞ tarafından geliştirilen finansal değerlendirme ve rapor paylaşım hizmetidir.',
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => LegalLinks.open(context, LegalLinks.home),
              icon: const Icon(Icons.language_rounded, size: 18),
              label: const Text('Web sitesini aç'),
              style: TextButton.styleFrom(
                  foregroundColor: FlowColors.teal,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ],
      bottom: PrimaryButton(
        text: 'Başla',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      ),
    );
  }
}
