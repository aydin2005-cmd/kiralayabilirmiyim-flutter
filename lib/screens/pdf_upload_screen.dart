import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'consent_screen.dart';

class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key});
  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  File? selectedFile;
  bool loading = false;
  String loadingMessage = 'Findeks raporunuz yükleniyor';
  final api = ApiClient();

  Future<void> pickPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    if (!file.path.toLowerCase().endsWith('.pdf')) {
      return _showError('Yalnızca PDF dosyası yükleyebilirsiniz.');
    }

    setState(() => selectedFile = file);
  }

  Future<void> upload() async {
    if (selectedFile == null) {
      return _showError('Lütfen orijinal Findeks PDF raporunuzu seçin.');
    }

    final appId = AppState.instance.applicationId;
    if (appId == null) {
      return _showError('Başvuru bulunamadı. Lütfen tekrar deneyin.');
    }

    setState(() {
      loading = true;
      loadingMessage = 'Findeks raporunuz yükleniyor';
    });

    try {
      final response =
          await api.uploadPdf('/reports/upload', selectedFile!, appId);
      final reportId = response['id']?.toString();

      if (reportId == null || reportId.isEmpty) {
        throw ApiException('Rapor kaydı oluşturulamadı.');
      }

      AppState.instance.reportId = reportId;

      var status = response['validation_status']?.toString().toLowerCase();

      if (status == 'valid') {
        if (!mounted) return;
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ConsentScreen()));
        return;
      }

      setState(() {
        loadingMessage = 'Findeks raporunuz doğrulanıyor';
      });

      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 2));

        final statusResponse =
            await api.get('/reports/$reportId/validation-status');
        status = statusResponse['validation_status']?.toString().toLowerCase();

        if (status == 'valid') {
          if (!mounted) return;
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ConsentScreen()));
          return;
        }

        if (status == 'invalid' || status == 'failed' || status == 'rejected') {
          final error = statusResponse['validation_error']?.toString();
          throw ApiException(
            error == null || error.isEmpty
                ? 'Rapor doğrulanamadı. Lütfen resmi ve güncel Findeks PDF raporunu yükleyiniz.'
                : error,
          );
        }
      }

      throw ApiException(
          'Rapor doğrulama işlemi beklenenden uzun sürdü. Lütfen kısa bir süre sonra tekrar deneyiniz.');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final fileName = selectedFile?.path.split(Platform.pathSeparator).last;

    return Stack(
      children: [
        FlowScaffold(
          title: 'Findeks Raporu',
          children: [
            const FlowHeader(
              icon: Icons.picture_as_pdf_outlined,
              eyebrow: 'Belge yükleme',
              title: 'Findeks Risk Raporunuzu yükleyin',
              subtitle:
                  'PDF formatındaki resmi Findeks risk raporu kabul edilir. Rapor tarihi en fazla 15 gün eski olmalıdır.',
            ),
            const SizedBox(height: 22),
            PremiumCard(
              onTap: loading ? null : pickPdf,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFF1F2), shape: BoxShape.circle),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFBE123C), size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName == null
                              ? 'PDF seçmek için dokunun'
                              : fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: FlowColors.navyDark),
                        ),
                        if (fileName != null) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'PDF seçildi. Değerlendirmeye devam edebilirsiniz.',
                            style: TextStyle(
                                color: FlowColors.green,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.upload_file_rounded, color: FlowColors.teal),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const TrustNotice(
              icon: Icons.rule_rounded,
              text:
                  'Fotoğraf, ekran görüntüsü, taranmış belge veya düzenlenmiş dosya kabul edilmez. Rapor sahibinin maskeli bilgileri başvuru bilgileriyle eşleştirilir.',
            ),
            const SizedBox(height: 12),
            const TrustNotice(
              icon: Icons.history_toggle_off_rounded,
              text:
                  'Findeks rapor tarihi 15 günden eskiyse değerlendirme oluşturulmaz.',
              background: FlowColors.amberBg,
              borderColor: FlowColors.amberBorder,
              iconColor: Color(0xFFB45309),
            ),
          ],
          bottom: PrimaryButton(
              text: 'Devam Et',
              loading: loading,
              onPressed: loading ? null : upload),
        ),
        if (loading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.38),
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 28,
                          offset: Offset(0, 12))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 46,
                        height: 46,
                        child: CircularProgressIndicator(
                            strokeWidth: 3.4, color: FlowColors.teal),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        loadingMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: FlowColors.navyDark),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Rapor doğrulanıyor ve değerlendirme hazırlanıyor. Lütfen bekleyin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: FlowColors.muted,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
