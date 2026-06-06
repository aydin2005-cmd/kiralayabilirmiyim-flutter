import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../services/payment_flow.dart';
import '../services/legal_links.dart';
import '../widgets/primary_button.dart';
import 'analysis_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool loading = false;

  String get _amountText => '${_formatAmount(AppState.instance.serviceFeeAmount)} ${AppState.instance.serviceFeeCurrency}';

  static String _formatAmount(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
  String loadingMessage = 'Ödeme kontrol ediliyor...';
  final api = ApiClient();

  Future<void> pay() async {
    setState(() {
      loading = true;
      loadingMessage = 'Ödeme başlatılıyor...';
    });
    try {
      final ok = await PaymentFlow.startAndWait(
        context: context,
        api: api,
        onStatus: (message) {
          if (mounted) setState(() => loadingMessage = message);
        },
      );

      if (!ok) {
        throw ApiException('Ödeme tamamlanamadı.');
      }

      if (!mounted) return;
      if (!AppState.instance.markPaymentSuccessHandled()) return;
      await _showPaymentSuccessSheet();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
    } catch (e) {
      _showError(_friendlyPaymentError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> checkPaymentStatusManually() async {
    setState(() {
      loading = true;
      loadingMessage = 'Ödeme durumu kontrol ediliyor...';
    });
    try {
      final paid = await PaymentFlow.checkCurrentStatus(api: api);
      if (!paid) {
        throw ApiException('Ödeme sonucu henüz alınamadı. Ödemeyi tamamladıysanız birkaç saniye sonra tekrar kontrol edin.');
      }
      if (!mounted) return;
      if (!AppState.instance.markPaymentSuccessHandled()) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
        return;
      }
      await _showPaymentSuccessSheet();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
    } catch (e) {
      _showError(_friendlyPaymentError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _friendlyPaymentError(Object error) {
    final text = error.toString();
    if (text.toLowerCase().contains('clientexception') ||
        text.toLowerCase().contains('socketexception') ||
        text.toLowerCase().contains('connection') ||
        text.toLowerCase().contains('timed out')) {
      return 'Ödeme sonucu kontrol edilemedi. Ödemeyi tamamladıysanız birkaç saniye sonra “Ödemeyi Kontrol Et ve Devam Et” düğmesine basınız.';
    }
    return text;
  }

  Future<void> _showPaymentSuccessSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_rounded, size: 58, color: Color(0xFF087A4A)),
                SizedBox(height: 14),
                Text('Ödeme başarılı', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF123C69))),
                SizedBox(height: 8),
                Text('Tam raporunuz açılıyor.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF475569), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme')),
      body: Stack(
        children: [
          SafeArea(
            minimum: const EdgeInsets.all(20),
            child: Column(
              children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Raporunuzu açın ve paylaşın', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(_amountText, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    const Text('Rapor oluşturma ve paylaşım hizmeti', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    const Text('Ödeme sonrası tam rapor, PDF ve paylaşım linki erişime açılır.'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        _LegalChip(label: 'Ön Bilgilendirme', url: LegalLinks.onBilgilendirme),
                        _LegalChip(label: 'Kullanım Şartları', url: LegalLinks.kullanimSartlari),
                        _LegalChip(label: 'Cayma Hakkı', url: LegalLinks.caymaHakki),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Destek: destek@kiralayabilirmiyim.com', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            const Spacer(),
                PrimaryButton(text: '$_amountText Öde, Raporu Aç', loading: loading, onPressed: pay),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: loading ? null : checkPaymentStatusManually,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Ödemeyi Kontrol Et ve Devam Et'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: const BorderSide(color: Color(0xFF0F766E), width: 1.4),
                    foregroundColor: const Color(0xFF0F766E),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.28),
                child: Center(
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0F766E))),
                        const SizedBox(height: 18),
                        Text(loadingMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF123C69))),
                        const SizedBox(height: 8),
                        const Text('Ödeme sayfasını tamamladıktan sonra uygulamaya dönün.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _LegalChip extends StatelessWidget {
  final String label;
  final String url;
  const _LegalChip({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.open_in_new_rounded, size: 16),
      label: Text(label),
      onPressed: () => LegalLinks.open(context, url),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)),
      side: const BorderSide(color: Color(0xFF99F6E4)),
      backgroundColor: const Color(0xFFF0FDFA),
    );
  }
}
