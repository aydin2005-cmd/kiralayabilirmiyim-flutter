import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';

class B2BPackagesScreen extends StatefulWidget {
  final bool canPurchase;

  const B2BPackagesScreen({
    super.key,
    required this.canPurchase,
  });

  @override
  State<B2BPackagesScreen> createState() => _B2BPackagesScreenState();
}

class _B2BPackagesScreenState extends State<B2BPackagesScreen> {
  final B2BApiClient api = B2BApiClient();

  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? lastPaymentId;
  Map<String, dynamic>? paymentStatus;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  void error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> loadProducts() async {
    setState(() => loading = true);

    try {
      final rows = await api.getList('/b2b/packages/products');
      if (mounted) {
        setState(() => products = rows);
      }
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> buy(Map<String, dynamic> product) async {
    final productId = product['product_id']?.toString();
    if (productId == null || productId.isEmpty) {
      error('Paket kimliği bulunamadı.');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await api.post(
        '/b2b/packages/checkout',
        {'product_id': productId},
      );

      final paymentId = response['payment_id']?.toString();
      final checkoutUrl = response['checkout_url']?.toString();

      if (paymentId == null || paymentId.isEmpty) {
        throw const B2BApiException('Ödeme kaydı oluşturulamadı.');
      }

      setState(() {
        lastPaymentId = paymentId;
        paymentStatus = response;
      });

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw const B2BApiException('PayTR ödeme sayfası alınamadı.');
      }

      final uri = Uri.parse(checkoutUrl);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        error('PayTR ödeme sayfası açılamadı.');
      }
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> checkPayment() async {
    final paymentId = lastPaymentId;
    if (paymentId == null) {
      return;
    }

    setState(() => loading = true);

    try {
      final status = await api.get(
        '/b2b/packages/payments/${Uri.encodeComponent(paymentId)}',
      );

      if (mounted) {
        setState(() => paymentStatus = status);
      }
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget productCard(Map<String, dynamic> product) {
    final currency = product['currency']?.toString() ?? 'TL';
    final credits = product['credit_count'] ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['name']?.toString() ?? '-',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: FlowColors.navyDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(product['description']?.toString() ?? ''),
            const SizedBox(height: 12),
            Text(
              '$credits sorgu',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text('Net: ${moneyText(product['price_amount'], currency)}'),
            Text('KDV: ${moneyText(product['vat_amount'], currency)}'),
            Text(
              'Toplam: ${moneyText(product['total_amount'], currency)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: FlowColors.green,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Geçerlilik: ${product['validity_days'] ?? '-'} gün',
              style: const TextStyle(color: FlowColors.muted),
            ),
            if (widget.canPurchase) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : () => buy(product),
                  icon: const Icon(Icons.credit_card_rounded),
                  label: const Text('Paketi Satın Al'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget paymentCard() {
    final status = paymentStatus;
    if (status == null || lastPaymentId == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PremiumCard(
        background: FlowColors.softGreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Son Ödeme',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: FlowColors.navyDark,
              ),
            ),
            const SizedBox(height: 8),
            Text('Ödeme ID: $lastPaymentId'),
            Text(
              'Ödeme: ${b2bStatusLabel(status['payment_status']?.toString())}',
            ),
            Text(
              'Paket: ${b2bStatusLabel(status['purchase_status']?.toString())}',
            ),
            if (status['invoice_status'] != null)
              Text('Fatura: ${status['invoice_status']}'),
            if (status['invoice_number'] != null)
              Text('Fatura No: ${status['invoice_number']}'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: loading ? null : checkPayment,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ödeme Durumunu Kontrol Et'),
            ),
            if (status['purchase_status'] == 'awaiting_activation') ...[
              const SizedBox(height: 8),
              const Text(
                'Ödeme tamamlandı. Paket, RiskMetriks yönetici aktivasyonundan sonra bakiyenize eklenecektir.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Kurumsal Paketler',
      children: [
        const FlowHeader(
          icon: Icons.shopping_bag_outlined,
          eyebrow: 'Paketler',
          title: 'Sorgu paketinizi seçin',
          subtitle:
              'Fiyatlar net, KDV ve toplam tutar ayrı gösterilir. Ödeme PayTR güvenli sayfasında tamamlanır.',
        ),
        const SizedBox(height: 18),
        paymentCard(),
        if (loading && products.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (products.isEmpty)
          const TrustNotice(
            icon: Icons.info_outline,
            text: 'Aktif kurumsal paket bulunmuyor.',
          )
        else
          ...products.map(productCard),
      ],
    );
  }
}
