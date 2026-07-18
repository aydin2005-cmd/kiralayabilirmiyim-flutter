import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/flow_widgets.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _navy = Color(0xFF123C69);
  static const _teal = Color(0xFF0F766E);
  static const _green = Color(0xFF087A4A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFD9E2EC);

  final ApiClient api = ApiClient();

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final response = await api.get('/applications/my');
      final data = response['data'];

      final loadedItems = data is List
          ? data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        items = loadedItems;
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

  String _applicationLabel(dynamic value) {
    switch (value?.toString()) {
      case 'home_rental':
        return 'Ev Kiralama';
      case 'car_rental':
        return 'Araç Kiralama';
      default:
        return 'Kiralama Başvurusu';
    }
  }

  String _statusLabel(dynamic value) {
    switch (value?.toString()) {
      case 'valid':
        return 'Finansal değerlendirme geçerli';
      case 'expired':
        return 'Finansal değerlendirme süresi doldu';
      case 'payment_pending':
        return 'Ödeme bekleniyor';
      case 'preparing':
        return 'Rapor hazırlanıyor';
      default:
        return 'Durum bilgisi bekleniyor';
    }
  }

  IconData _statusIcon(dynamic value) {
    switch (value?.toString()) {
      case 'valid':
        return Icons.verified_outlined;
      case 'expired':
        return Icons.history_rounded;
      case 'payment_pending':
        return Icons.credit_card_outlined;
      case 'preparing':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _statusColor(dynamic value) {
    switch (value?.toString()) {
      case 'valid':
        return _green;
      case 'expired':
        return const Color(0xFFB45309);
      case 'payment_pending':
        return _teal;
      case 'preparing':
        return _muted;
      default:
        return _navy;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Belirtilmedi';

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return 'Belirtilmedi';

    return DateFormat('dd.MM.yyyy').format(parsed.toLocal());
  }

  String _paymentLabel(Map<String, dynamic> item) {
    if (item['payment_completed'] == true) {
      return 'Ödeme tamamlandı';
    }

    if (item['payment_required'] == true) {
      return 'Ödeme bekleniyor';
    }

    final resultType = item['result_type']?.toString();

    if (resultType == 'negative') {
      return 'Ödeme gerekmiyor';
    }

    return 'Ödeme durumu yok';
  }

  String _findeksLabel(dynamic value) {
    switch (value?.toString()) {
      case 'available':
        return 'Orijinal Findeks PDF erişilebilir';
      case 'expired':
        return 'Orijinal Findeks PDF saklama süresi doldu';
      case 'processing':
        return 'Findeks PDF işleniyor';
      case 'not_available':
        return 'Orijinal Findeks PDF artık saklanmıyor';
      case 'not_uploaded':
        return 'Findeks PDF yüklenmedi';
      default:
        return 'Findeks PDF durumu belirtilmedi';
    }
  }

  void _openReport(Map<String, dynamic> item) {
    final applicationId = item['id']?.toString();
    final analysisId = item['analysis_id']?.toString();

    if (applicationId == null ||
        applicationId.isEmpty ||
        analysisId == null ||
        analysisId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu raporun kayıt bilgileri eksik.'),
        ),
      );
      return;
    }

    AppState.instance.applicationId = applicationId;
    AppState.instance.analysisId = analysisId;
    AppState.instance.applicationType = item['application_type']?.toString();
    AppState.instance.paymentSuccessHandled = false;

    final paymentCompleted = item['payment_completed'] == true;
    AppState.instance.paymentCompleted = paymentCompleted;
    AppState.instance.paymentCompletedApplicationId =
        paymentCompleted ? applicationId : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          applicationId: applicationId,
          analysisId: analysisId,
          openedFromHistory: true,
          reportDate: item['report_date']?.toString(),
          financialValid: item['financial_valid'] is bool
              ? item['financial_valid'] as bool
              : null,
          financialValidUntil: item['financial_valid_until']?.toString(),
          shareAccessAvailable: item['share_access_available'] is bool
              ? item['share_access_available'] as bool
              : null,
          shareAccessExpiresAt: item['share_access_expires_at']?.toString(),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? _muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $value',
              style: TextStyle(
                color: color ?? const Color(0xFF334155),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final status = item['history_status']?.toString();
    final statusColor = _statusColor(status);
    final canOpen = item['can_open_report'] == true &&
        item['analysis_id']?.toString().isNotEmpty == true;

    final financialValidUntil = _formatDate(item['financial_valid_until']);
    final shareAccessExpiresAt = _formatDate(item['share_access_expires_at']);
    final findeksExpiresAt = _formatDate(item['findeks_pdf_expires_at']);

    return PremiumCard(
      onTap: canOpen ? () => _openReport(item) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _statusIcon(status),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _applicationLabel(item['application_type']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                canOpen
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: canOpen ? _navy : _muted,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            height: 1,
            color: _border,
          ),
          _detailRow(
            Icons.calendar_today_outlined,
            'Rapor tarihi',
            _formatDate(item['report_date']),
          ),
          _detailRow(
            Icons.event_available_outlined,
            'Finansal geçerlilik sonu',
            financialValidUntil,
            color: item['financial_valid'] == true
                ? _green
                : const Color(0xFFB45309),
          ),
          _detailRow(
            Icons.link_rounded,
            'Paylaşım ve doğrulama erişimi',
            item['share_access_available'] == true
                ? '$shareAccessExpiresAt tarihine kadar'
                : 'Sona erdi ($shareAccessExpiresAt)',
            color: item['share_access_available'] == true ? _teal : _muted,
          ),
          _detailRow(
            Icons.payments_outlined,
            'Ödeme',
            _paymentLabel(item),
          ),
          _detailRow(
            Icons.picture_as_pdf_outlined,
            'Findeks PDF',
            '${_findeksLabel(item['findeks_pdf_status'])}'
                '${findeksExpiresAt == 'Belirtilmedi' ? '' : ' · $findeksExpiresAt'}',
          ),
          if (!canOpen) ...[
            const SizedBox(height: 12),
            Text(
              status == 'expired'
                  ? 'Bu kayıt finansal geçerlilik süresi dolduğu ve ödeme tamamlanmadığı için açılamaz.'
                  : 'Rapor tamamlandığında buradan açılabilir.',
              style: const TextStyle(
                color: _muted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlarım'),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: _muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  )
                : items.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 52,
                              color: _muted,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Henüz bir değerlendirme raporunuz bulunmuyor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _navy,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _historyCard(items[index]),
                        ),
                      ),
      ),
    );
  }
}
