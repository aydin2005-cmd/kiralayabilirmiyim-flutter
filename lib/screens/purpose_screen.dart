import 'package:flutter/material.dart';
import '../models/application_type.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/flow_widgets.dart';
import 'home_rental_form_screen.dart';
import 'car_rental_form_screen.dart';

class PurposeScreen extends StatefulWidget {
  const PurposeScreen({super.key});
  @override
  State<PurposeScreen> createState() => _PurposeScreenState();
}

class _PurposeScreenState extends State<PurposeScreen> {
  final api = ApiClient();
  bool loading = false;

  Future<void> select(ApplicationType type) async {
    setState(() => loading = true);
    try {
      AppState.instance.applicationType = type.apiValue;
      final response =
          await api.post('/applications', {'application_type': type.apiValue});
      final id = response['id']?.toString();
      if (id == null || id.isEmpty)
        throw ApiException('Başvuru oluşturulamadı.');
      AppState.instance.applicationId = id;
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => type == ApplicationType.homeRental
                  ? const HomeRentalFormScreen()
                  : const CarRentalFormScreen()));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget option(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return PremiumCard(
      onTap: loading ? null : onTap,
      child: Row(children: [
        Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
                color: FlowColors.softGreen, shape: BoxShape.circle),
            child: Icon(icon, color: FlowColors.teal, size: 32)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: FlowColors.navyDark)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  color: FlowColors.muted,
                  height: 1.35,
                  fontWeight: FontWeight.w600)),
        ])),
        loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right_rounded, color: FlowColors.navy),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(title: 'Başvuru Türü', children: [
      const FlowHeader(
          icon: Icons.route_outlined,
          eyebrow: 'Başvuru türü',
          title: 'Hangi başvuru için rapor almak istiyorsunuz?',
          subtitle:
              'Ev veya araç kiralama başvurunuz için Findeks raporunuz ve beyan ettiğiniz tutar birlikte değerlendirilir.'),
      const SizedBox(height: 22),
      option(
          icon: Icons.home_work_outlined,
          title: 'Ev Kiralama',
          subtitle:
              'Aylık kira tutarına göre finansal değerlendirme raporu oluşturulur.',
          onTap: () => select(ApplicationType.homeRental)),
      const SizedBox(height: 14),
      option(
          icon: Icons.directions_car_filled_outlined,
          title: 'Araç Kiralama',
          subtitle:
              'Günlük bedel ve kiralama süresine göre toplam tutar değerlendirilir.',
          onTap: () => select(ApplicationType.carRental)),
    ]);
  }
}
