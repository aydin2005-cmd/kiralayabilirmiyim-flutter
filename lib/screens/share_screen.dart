import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final api = ApiClient();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final scrollController = ScrollController();
  final linksKey = GlobalKey();
  bool includeFindeksPdf = false;
  bool findeksConsent = false;
  bool loading = false;
  String? shareUrl;
  String? pdfUrl;
  String? verificationUrl;
  String? verificationCode;
  String? error;


  Future<void> copyToClipboard(String? value, String label) async {
    if (value == null || value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopyalandı.')),
    );
  }

  Future<void> openExternalLink(String value) async {
    if (value.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Linkiniz açılıyor, lütfen bekleyiniz...')),
    );
    try {
      final opened = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link açılamadı. Lütfen bağlantıyı kopyalayıp tarayıcıda deneyiniz.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link açılamadı. Lütfen bağlantıyı kopyalayıp tarayıcıda deneyiniz.')),
      );
    }
  }

  Widget linkRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final linkValue = value;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        border: Border.all(color: const Color(0xFFD9E2EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SelectableText(linkValue, style: const TextStyle(color: Color(0xFF123C69), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => openExternalLink(linkValue),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Aç'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => copyToClipboard(linkValue, label),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Kopyala'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> createShare() async {
    if (includeFindeksPdf && !findeksConsent) {
      setState(() => error = 'Findeks risk raporunuzu paylaşmak için açık rıza onayını vermeniz gerekir.');
      return;
    }

    if (!AppState.instance.paymentCompleted) {
      setState(() => error = 'Ödeme tamamlanmadan paylaşım linki oluşturulamaz.');
      return;
    }

    setState(() { loading = true; error = null; });
    try {
      final appId = AppState.instance.applicationId;
      if (appId == null) throw ApiException('Başvuru bulunamadı.');

      final response = await api.post('/shares', {
        'application_id': appId,
        'recipient_type': 'landlord',
        'recipient_name': nameController.text.trim().isEmpty ? null : nameController.text.trim(),
        'recipient_phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        'include_findeks_pdf': includeFindeksPdf,
        'findeks_pdf_consent_given': includeFindeksPdf ? findeksConsent : false,
      });

      shareUrl = response['url']?.toString();
      pdfUrl = response['pdf_url']?.toString() ?? (shareUrl == null ? null : '${shareUrl!}/pdf');
      verificationUrl = response['verification_url']?.toString();
      verificationCode = response['verification_code']?.toString();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) {
      setState(() => loading = false);
      if (shareUrl != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLinks());
      }
    }
  }

  void _scrollToLinks() {
    final linkContext = linksKey.currentContext;
    if (linkContext == null) return;
    Scrollable.ensureVisible(
      linkContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonucu Paylaş'),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            const Text(
              'Paylaşılacak Belgeler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  const CheckboxListTile(
                    value: true,
                    onChanged: null,
                    title: Text('Kiralayabilir Miyim Sonuç Raporu'),
                    subtitle: Text('Bu belge paylaşımın ana raporudur.'),
                  ),
                  CheckboxListTile(
                    value: includeFindeksPdf,
                    onChanged: (v) => setState(() {
                      includeFindeksPdf = v ?? false;
                      if (!includeFindeksPdf) findeksConsent = false;
                    }),
                    title: const Text('Findeks Risk Raporumu da paylaşmak istiyorum'),
                    subtitle: const Text('Bu belge detaylı finansal bilgiler içerebilir. Yalnızca açık onayınızla ve rapor tarihinden itibaren en fazla 16 gün süreyle paylaşılır.'),
                  ),
                  if (includeFindeksPdf)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          border: Border.all(color: const Color(0xFFF4C76A)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Findeks risk raporu; kredi limitleri, borçlar, ödeme geçmişi, gecikme bilgileri ve finans kuruluşu detayları gibi hassas finansal bilgiler içerebilir. Bu belgeyi yalnızca paylaşmak istediğiniz kişi veya kurumla paylaşmanız önerilir. Findeks PDF, onay vermeniz halinde rapor tarihinden itibaren en fazla 16 gün süreyle erişilebilir olur; paylaşım iptal edilir veya süre dolarsa erişim kapatılır.',
                              style: TextStyle(fontSize: 13),
                            ),
                            CheckboxListTile(
                              value: findeksConsent,
                              onChanged: (v) => setState(() => findeksConsent = v ?? false),
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Yüklediğim Findeks risk raporunun, bu paylaşım linkine erişen kişi veya kurum tarafından rapor tarihinden itibaren en fazla 16 gün süreyle görüntülenebilmesini kabul ediyorum.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF8),
                border: Border.all(color: const Color(0xFFBFE8DD)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ödeme sonrası tam sonuç raporu, PDF sonuç raporu ve paylaşım linki erişime açılır. Orijinal Findeks PDF yalnızca ayrıca onay verirseniz ve en fazla 16 gün süreyle paylaşılır.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
            const SizedBox(height: 18),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Alıcı adı / kurum adı (isteğe bağlı)')),
            const SizedBox(height: 12),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Alıcı telefon / e-posta (isteğe bağlı)')),
            const SizedBox(height: 20),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (shareUrl != null) ...[
              Container(key: linksKey, child: linkRow('Web sonuç raporu linki', shareUrl)),
              linkRow('PDF sonuç raporu linki', pdfUrl),
              linkRow('Rapor doğrulama linki', verificationUrl),
              if (verificationCode != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0FBF8), border: Border.all(color: const Color(0xFFBFE8DD)), borderRadius: BorderRadius.circular(12)),
                  child: Text('Doğrulama kodu: $verificationCode', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF075E47))),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  border: Border.all(color: const Color(0xFFF4C76A)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Yerel test notu: Web/PDF ve doğrulama linklerini Windows bilgisayarınızdaki tarayıcıda açın. Doğrulama sayfası sınırlı rapor bilgisi gösterir. Orijinal Findeks PDF yalnızca kullanıcı ayrıca onay verdiyse paylaşılır.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (shareUrl == null)
              PrimaryButton(text: loading ? 'Oluşturuluyor...' : 'Paylaşım Linki Oluştur', onPressed: loading ? null : createShare),
          ],
        ),
      ),
    );
  }
}
