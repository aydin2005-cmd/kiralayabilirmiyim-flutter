import 'package:flutter/material.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';

class B2BApplicationsScreen extends StatefulWidget {
  const B2BApplicationsScreen({super.key});

  @override
  State<B2BApplicationsScreen> createState() => _B2BApplicationsScreenState();
}

class _B2BApplicationsScreenState extends State<B2BApplicationsScreen> {
  final B2BApiClient api = B2BApiClient();

  List<Map<String, dynamic>> applications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
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

  Widget applicationCard(Map<String, dynamic> item) {
    final reportAvailable = item['report_available'] == true;
    final completed = item['evaluation_completed'] == true;

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
              'Başvuru ID: ${item['application_id'] ?? '-'}',
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
            TrustNotice(
              icon: reportAvailable
                  ? Icons.picture_as_pdf_outlined
                  : Icons.schedule_outlined,
              text: reportAvailable
                  ? 'Sonuç raporu hazır. Mobil PDF görüntüleme bir sonraki geliştirme adımında eklenecek.'
                  : 'Sonuç raporu henüz görüntülenebilir durumda değil.',
              background:
                  reportAvailable ? FlowColors.softGreen : FlowColors.amberBg,
              borderColor: reportAvailable
                  ? const Color(0xFFBFE8DD)
                  : FlowColors.amberBorder,
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
