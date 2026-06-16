import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../services/legal_links.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'analysis_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool processingConsent = false;
  bool disclaimerConsent = false;
  bool retention90Consent = false;
  bool anonymizedDataConsent = false;
  bool loading = false;
  final api = ApiClient();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _nudgeConsentListDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (_scrollController.offset + 135).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> submit() async {
    if (!processingConsent || !disclaimerConsent)
      return _showError(
          'Devam etmek için zorunlu bilgilendirme ve veri işleme onaylarını kabul etmelisiniz.');
    final appId = AppState.instance.applicationId;
    if (appId == null)
      return _showError('Başvuru bulunamadı. Lütfen tekrar deneyin.');
    setState(() => loading = true);
    try {
      await api.post('/consents', {
        'application_id': appId,
        'processing_consent': processingConsent,
        'disclaimer_consent': disclaimerConsent,
        'retention_90_consent': retention90Consent,
        'anonymized_data_consent': anonymizedDataConsent
      });
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Widget consentTile(String title, String subtitle, bool value,
      ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) {
        onChanged(v);
        _nudgeConsentListDown();
      },
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(height: 1.3)),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget legalLinkRow(List<MapEntry<String, String>> links) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: links.map((entry) {
          return TextButton.icon(
            onPressed: () => LegalLinks.open(context, entry.value),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(entry.key),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: FlowColors.teal,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Bilgilendirme ve Onaylar',
      scrollController: _scrollController,
      children: [
        const FlowHeader(
            icon: Icons.privacy_tip_outlined,
            eyebrow: 'Açık bilgilendirme',
            title: 'Bilgilendirme ve zorunlu onaylar',
            subtitle:
                'Devam etmek için aydınlatma metinlerini okumanız ve değerlendirme için gerekli onayları vermeniz gerekir.'),
        const SizedBox(height: 22),
        PremiumCard(
            child: Column(children: [
          consentTile(
              'KVKK Aydınlatma Metni’ni okudum, onaylıyorum.',
              'Findeks Risk Raporunuzdaki finansal göstergeler, kimlik eşleştirme bilgileri ve başvuru tutarı değerlendirme amacıyla analiz edilir.',
              processingConsent,
              (v) => setState(() => processingConsent = v ?? false)),
          legalLinkRow(const [
            MapEntry('KVKK Aydınlatma Metni', LegalLinks.kvkk),
          ]),
          const Divider(),
          consentTile(
              'Otomatik ön değerlendirme niteliğini ve kullanım şartlarını okudum, onaylıyorum.',
              'Bu rapor garanti, kefalet veya ödeme taahhüdü değildir; nihai karar ilgili kişi veya kuruma aittir.',
              disclaimerConsent,
              (v) => setState(() => disclaimerConsent = v ?? false)),
          legalLinkRow(const [
            MapEntry('Kullanım Şartları', LegalLinks.kullanimSartlari),
            MapEntry('Ön Bilgilendirme', LegalLinks.onBilgilendirme),
          ]),
          const Divider(),
        ])),
        const SizedBox(height: 14),
        const TrustNotice(
            icon: Icons.shield_outlined,
            text:
                'Paylaşılabilir rapor oluşturulsa bile Findeks PDF’in üçüncü kişilerle paylaşılması ayrıca ve açıkça sizin tercihinize bağlıdır.'),
        const SizedBox(height: 10),
        PremiumCard(
          background: const Color(0xFFF8FAFC),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Destek',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: FlowColors.navyDark)),
            const SizedBox(height: 6),
            const Text(
                'Sorularınız için bilgi@riskmetriks.com adresinden bize ulaşabilirsiniz.',
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            legalLinkRow(
                const [MapEntry('İletişim Sayfası', LegalLinks.iletisim)]),
          ]),
        ),
      ],
      bottom: PrimaryButton(
          text: 'Değerlendirmeyi Başlat', loading: loading, onPressed: submit),
    );
  }
}
