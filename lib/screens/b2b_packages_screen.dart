import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../services/b2b_payment_return_signal.dart';
import '../widgets/flow_widgets.dart';

typedef B2BCheckoutLauncher = Future<bool> Function(Uri uri);

class B2BPackagesScreen extends StatefulWidget {
  final bool canPurchase;
  final B2BApiClient? apiClient;
  final B2BCheckoutLauncher? checkoutLauncher;
  final int autoRetryCount;
  final Duration retryDelay;

  const B2BPackagesScreen({
    super.key,
    required this.canPurchase,
    this.apiClient,
    this.checkoutLauncher,
    this.autoRetryCount = 4,
    this.retryDelay = const Duration(seconds: 1),
  });

  @override
  State<B2BPackagesScreen> createState() => _B2BPackagesScreenState();
}

class _B2BPackagesScreenState extends State<B2BPackagesScreen>
    with WidgetsBindingObserver {
  late final B2BApiClient api;

  List<Map<String, dynamic>> products = [];
  bool loading = true;
  bool checkingPayment = false;
  String? lastPaymentId;
  Map<String, dynamic>? paymentStatus;
  String? paymentMessage;
  int _paymentCheckEpoch = 0;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
    WidgetsBinding.instance.addObserver(this);

    B2BPaymentReturnSignal.instance.addListener(
      _handlePaymentReturnSignal,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_recoverPaymentOnOpen()),
    );

    loadProducts();
  }

  @override
  void dispose() {
    _paymentCheckEpoch++;

    B2BPaymentReturnSignal.instance.removeListener(
      _handlePaymentReturnSignal,
    );

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && lastPaymentId != null) {
      _checkPaymentStatus(auto: true);
    }
  }

  void _handlePaymentReturnSignal() {
    final paymentId = B2BPaymentReturnSignal.instance.takePendingPaymentId();

    if (paymentId == null || paymentId.isEmpty) {
      return;
    }

    unawaited(
      _adoptPaymentId(
        paymentId,
        persist: true,
        message: 'Ödeme dönüşü alındı. Durum doğrulanıyor...',
      ),
    );
  }

  Future<void> _recoverPaymentOnOpen() async {
    final returnedPaymentId =
        B2BPaymentReturnSignal.instance.takePendingPaymentId();

    if (returnedPaymentId != null && returnedPaymentId.isNotEmpty) {
      await _adoptPaymentId(
        returnedPaymentId,
        persist: true,
        message: 'Ödeme dönüşü alındı. Durum doğrulanıyor...',
      );
      return;
    }

    final restoredPaymentId = await api.readPendingPaymentId();

    if (!mounted ||
        restoredPaymentId == null ||
        restoredPaymentId.isEmpty ||
        lastPaymentId != null) {
      return;
    }

    await _adoptPaymentId(
      restoredPaymentId,
      persist: false,
    );
  }

  Future<void> _adoptPaymentId(
    String paymentId, {
    required bool persist,
    String? message,
  }) async {
    final normalized = paymentId.trim();

    if (normalized.isEmpty) {
      return;
    }

    if (persist) {
      await api.savePendingPaymentId(
        normalized,
      );
    }

    if (!mounted) {
      return;
    }

    final changesPayment = lastPaymentId != normalized;

    if (changesPayment) {
      _paymentCheckEpoch++;
    }

    setState(() {
      if (changesPayment) {
        checkingPayment = false;
      }

      lastPaymentId = normalized;

      if (message != null) {
        paymentMessage = message;
      }
    });

    await _checkPaymentStatus(
      auto: true,
    );
  }

  void error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> _openCheckout(Uri uri) {
    final launcher = widget.checkoutLauncher;
    if (launcher != null) {
      return launcher(uri);
    }

    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
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

    if (checkingPayment) {
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

      await api.savePendingPaymentId(
        paymentId,
      );

      setState(() {
        lastPaymentId = paymentId;
        paymentStatus = response;
        paymentMessage =
            'Ödeme sonrası uygulamaya döndüğünüzde durum otomatik kontrol edilecek.';
      });

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw const B2BApiException('PayTR ödeme sayfası alınamadı.');
      }

      final uri = Uri.parse(checkoutUrl);
      final opened = await _openCheckout(uri);

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
    await _checkPaymentStatus(auto: false);
  }

  Future<void> _checkPaymentStatus({required bool auto}) async {
    final paymentId = lastPaymentId;
    if (paymentId == null || checkingPayment) {
      return;
    }

    final epoch = ++_paymentCheckEpoch;
    final attempts = auto ? widget.autoRetryCount + 1 : 1;

    if (mounted) {
      setState(() {
        checkingPayment = true;
        if (auto) {
          paymentMessage = 'Ödemeniz doğrulanıyor...';
        }
      });
    }

    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        final status = await api.get(
          '/b2b/packages/payments/${Uri.encodeComponent(paymentId)}',
        );

        if (!mounted || epoch != _paymentCheckEpoch) {
          return;
        }

        final finalAttempt = attempt == attempts - 1;
        final assessment = _paymentAssessment(
          status,
          finalAttempt: finalAttempt,
        );

        setState(() {
          paymentStatus = status;
          paymentMessage = assessment.message;
        });

        if (_isTerminalPaymentStatus(status)) {
          await api.clearPendingPaymentId();
        }

        if (!assessment.shouldRetry || finalAttempt) {
          break;
        }

        await Future.delayed(widget.retryDelay);

        if (!mounted || epoch != _paymentCheckEpoch) {
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        error('Ödeme durumu kontrol edilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted && epoch == _paymentCheckEpoch) {
        setState(() => checkingPayment = false);
      }
    }
  }

  _PaymentAssessment _paymentAssessment(
    Map<String, dynamic> status, {
    required bool finalAttempt,
  }) {
    final payment = status['payment_status']?.toString();
    final purchase = status['purchase_status']?.toString();

    if (payment == 'failed') {
      return const _PaymentAssessment('Ödeme tamamlanamadı.');
    }

    if (payment == 'cancelled' || purchase == 'cancelled') {
      return const _PaymentAssessment('Ödeme işlemi iptal edildi.');
    }

    if (payment == 'refunded' || purchase == 'refunded') {
      return const _PaymentAssessment('Ödeme iade edildi.');
    }

    if (payment == 'paid' && purchase == 'active') {
      return const _PaymentAssessment(
        'Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.',
      );
    }

    if (payment == 'paid' && purchase == 'awaiting_activation') {
      return _PaymentAssessment(
        finalAttempt
            ? 'Ödemeniz alındı. Paketinizin hesabınıza tanımlanması tamamlanıyor. Biraz sonra tekrar kontrol edebilirsiniz.'
            : 'Ödemeniz alındı. Paketiniz hesabınıza tanımlanıyor...',
        shouldRetry: !finalAttempt,
      );
    }

    if (payment == 'pending' || purchase == 'pending_payment') {
      return _PaymentAssessment(
        finalAttempt
            ? 'Ödemeniz henüz doğrulanmadı. Biraz sonra tekrar kontrol edebilirsiniz.'
            : 'Ödemeniz doğrulanıyor...',
        shouldRetry: !finalAttempt,
      );
    }

    if (payment == 'paid' &&
        (purchase == 'exhausted' || purchase == 'expired')) {
      return const _PaymentAssessment(
        'Ödemeniz alındı. Paket durumunuzu portal bakiyenizden kontrol edebilirsiniz.',
      );
    }

    return const _PaymentAssessment(
      'Ödeme durumunuz kontrol edildi. Biraz sonra tekrar deneyebilirsiniz.',
    );
  }

  bool _isTerminalPaymentStatus(
    Map<String, dynamic> status,
  ) {
    final payment = status['payment_status']?.toString();

    final purchase = status['purchase_status']?.toString();

    if (payment == 'failed' ||
        payment == 'cancelled' ||
        purchase == 'cancelled' ||
        payment == 'refunded' ||
        purchase == 'refunded') {
      return true;
    }

    return payment == 'paid' &&
        (purchase == 'active' ||
            purchase == 'exhausted' ||
            purchase == 'expired');
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
              '$credits kredi',
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
                  onPressed:
                      loading || checkingPayment ? null : () => buy(product),
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
            if (paymentMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                paymentMessage!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: loading || checkingPayment ? null : checkPayment,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ödeme Durumunu Kontrol Et'),
            ),
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
          title: 'Kredi paketinizi seçin',
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

class _PaymentAssessment {
  final String message;
  final bool shouldRetry;

  const _PaymentAssessment(
    this.message, {
    this.shouldRetry = false,
  });
}
