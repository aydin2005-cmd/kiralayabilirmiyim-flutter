import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final messages = const [
    'Rapor formatı kontrol ediliyor',
    'Kimlik bilgileri eşleştiriliyor',
    'Findeks göstergeleri okunuyor',
    'Son 4 ay ödeme hareketleri kontrol ediliyor',
    'Kiralama uygunluğu hesaplanıyor',
  ];
  int index = 0;
  bool failed = false;
  String? errorMessage;
  final api = ApiClient();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    timer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (mounted)
        setState(() => index = (index + 1).clamp(0, messages.length - 1));
    });
    final appId = AppState.instance.applicationId;
    if (appId == null) {
      setState(() {
        failed = true;
        errorMessage = 'Başvuru bulunamadı. Lütfen tekrar deneyin.';
      });
      return;
    }
    try {
      final response =
          await api.post('/analysis/start', {'application_id': appId});
      final analysisId = response['id']?.toString();
      if (analysisId == null || analysisId.isEmpty)
        throw ApiException('Analiz başlatılamadı.');
      AppState.instance.analysisId = analysisId;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ResultScreen()));
    } catch (e) {
      if (mounted)
        setState(() {
          failed = true;
          errorMessage = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return FlowScaffold(
          title: 'Değerlendirme',
          children: [
            const FlowHeader(
                icon: Icons.error_outline_rounded,
                eyebrow: 'İşlem tamamlanamadı',
                title: 'Değerlendirme tamamlanamadı',
                subtitle:
                    'Lütfen başvuru bilgilerini kontrol edip tekrar deneyin.'),
            const SizedBox(height: 20),
            PremiumCard(
                child: Text(errorMessage ?? 'Değerlendirme tamamlanamadı.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
          bottom: PrimaryButton(
              text: 'Geri Dön', onPressed: () => Navigator.pop(context)));
    }
    return FlowScaffold(
      showBack: false,
      children: [
        const FlowHeader(
            icon: Icons.auto_awesome_rounded,
            eyebrow: 'Değerlendiriliyor',
            title: 'Raporunuz kontrol ediliyor',
            subtitle:
                'Bu aşamada rapor formatı, kimlik eşleşmesi, rapor tarihi ve finansal göstergeler otomatik olarak kontrol edilir.'),
        const SizedBox(height: 24),
        PremiumCard(
            child: Column(children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
          const SizedBox(height: 22),
          FlowStepList(items: messages, activeIndex: index),
        ])),
      ],
    );
  }
}
