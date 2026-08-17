import 'package:flutter/material.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../services/corporate_pdf_opener.dart';
import '../widgets/flow_widgets.dart';

class B2BApplicationsScreen extends StatefulWidget {
  final B2BApiClient? apiClient;
  final CorporatePdfOpener? pdfOpener;

  const B2BApplicationsScreen({
    super.key,
    this.apiClient,
    this.pdfOpener,
  });

  @override
  State<B2BApplicationsScreen> createState() => _B2BApplicationsScreenState();
}

class _B2BApplicationsScreenState extends State<B2BApplicationsScreen> {
  late final B2BApiClient api;
  late final CorporatePdfOpener pdfOpener;

  List<Map<String, dynamic>> applications = [];
  bool loading = true;
  String? openingReportForApplicationId;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
    pdfOpener = widget.pdfOpener ?? const CorporatePdfOpener();
    load();
  }

  void error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final rows = await api.getList('/b2b/portal/applications');
      if (mounted) {
        setState(() => applications = rows);
      }
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _friendlyPdfError(Object error) {
    if (error is B2BApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Kurumsal oturumunuz doğrulanamadı. Lütfen tekrar giriş yapın.';
      }

      if (error.statusCode == 404 || error.statusCode == 410) {
        return 'Sonuç raporu artık görüntülenebilir durumda değil.';
      }
    }

    if (error is CorporatePdfOpenException) {
      return error.message;
    }

    return 'Sonuç raporu açılamadı. Lütfen tekrar deneyin.';
  }

  Future<void> openReport(Map<String, dynamic> item) async {
    final applicationId = (item['application_id'] ?? '').toString();
    final endpoint = (item['report_pdf_endpoint'] ?? '').toString().trim();

    if (openingReportForApplicationId != null) return;

    if (applicationId.isEmpty || endpoint.isEmpty) {
      error('Sonuç raporu henüz görüntülenebilir durumda değil.');
      return;
    }

    setState(() => openingReportForApplicationId = applicationId);

    try {
      final bytes = await api.getBytes(endpoint);

      await pdfOpener.open(
        bytes: bytes,
        applicationId: applicationId,
      );
    } catch (e) {
      if (!mounted) return;
      error(_friendlyPdfError(e));

      if (e is B2BApiException &&
          (e.statusCode == 404 || e.statusCode == 410)) {
        await load();
      }
    } finally {
      if (mounted && openingReportForApplicationId == applicationId) {
        setState(() => openingReportForApplicationId = null);
      }
    }
  }

  Widget applicationCard(Map<String, dynamic> item) {
    final reportAvailable = item['report_available'] == true;
    final completed = item['evaluation_completed'] == true;
    final applicationId = (item['application_id'] ?? '').toString();
    final openingThisReport = openingReportForApplicationId == applicationId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['referral_label']?.toString().trim().isNotEmpty == true
                  ? item['referral_label'].toString()
                  : 'Kurumsal Başvuru',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: FlowColors.navyDark,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              'Başvuru No: ${item['application_id'] ?? '-'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text('Bağlanma: ${shortDate(item['bound_at'])}'),
            Text('Tür: ${item['application_type'] ?? '-'}'),
            Text('Durum: ${item['application_status'] ?? '-'}'),
            Text(
              'Değerlendirme: ${completed ? 'Tamamlandı' : 'Bekliyor'}',
            ),
            if (item['decision'] != null)
              Text(
                'Karar: ${item['decision']}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            const SizedBox(height: 8),
            if (reportAvailable)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: openingReportForApplicationId == null
                      ? () => openReport(item)
                      : null,
                  icon: openingThisReport
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    openingThisReport
                        ? 'Rapor Açılıyor...'
                        : 'Sonuç Raporunu Görüntüle',
                  ),
                ),
              )
            else
              const TrustNotice(
                icon: Icons.schedule_outlined,
                text: 'Sonuç raporu henüz görüntülenebilir durumda değil.',
                background: FlowColors.amberBg,
                borderColor: FlowColors.amberBorder,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Kurumsal Başvurular',
      children: [
        const FlowHeader(
          icon: Icons.fact_check_outlined,
          eyebrow: 'Başvurular',
          title: 'Aday sonuçlarını takip edin',
          subtitle:
              'Kurumsal davetlerle bağlanan başvuruların durum ve sonuç bilgilerini görüntüleyin.',
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Listeyi Yenile'),
        ),
        const SizedBox(height: 14),
        if (loading && applications.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (applications.isEmpty)
          const TrustNotice(
            icon: Icons.info_outline,
            text: 'Henüz kurumsal başvuru bulunmuyor.',
          )
        else
          ...applications.map(applicationCard),
      ],
    );
  }
}
