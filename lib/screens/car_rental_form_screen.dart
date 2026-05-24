import 'package:flutter/material.dart';
import '../data/turkey_locations.dart';
import '../data/vehicle_segments.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'pdf_upload_screen.dart';

class CarRentalFormScreen extends StatefulWidget {
  const CarRentalFormScreen({super.key});
  @override
  State<CarRentalFormScreen> createState() => _CarRentalFormScreenState();
}

class _CarRentalFormScreenState extends State<CarRentalFormScreen> {
  final dailyController = TextEditingController();
  final durationController = TextEditingController();
  final depositController = TextEditingController();
  String? selectedCity;
  String? selectedVehicleSegment;
  bool loading = false;
  final api = ApiClient();

  Future<void> submit() async {
    if (dailyController.text.isEmpty || durationController.text.isEmpty || selectedVehicleSegment == null || selectedCity == null) return _showError('Lütfen zorunlu alanları doldurun.');
    final id = AppState.instance.applicationId;
    if (id == null) return _showError('Başvuru bulunamadı. Lütfen tekrar deneyin.');
    setState(() => loading = true);
    try {
      final dailyAmount = num.tryParse(dailyController.text) ?? 0;
      final rentalDays = int.tryParse(durationController.text) ?? 1;
      await api.patch('/applications/$id/rental-details', {'daily_rental_amount': dailyAmount, 'rental_duration_days': rentalDays, 'vehicle_class': selectedVehicleSegment, 'city': selectedCity, 'deposit_amount': num.tryParse(depositController.text)});
      AppState.instance.applicationAmount = dailyAmount * rentalDays;
      AppState.instance.applicationType = 'car_rental';
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfUploadScreen()));
    } catch (e) { _showError(e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Araç Kiralama',
      children: [
        const FlowHeader(icon: Icons.directions_car_filled_outlined, eyebrow: 'Tutar bilgisi', title: 'Kiralama bedelini hesaplayalım', subtitle: 'Günlük bedel ve süreye göre toplam kiralama tutarı değerlendirmeye alınır.'),
        const SizedBox(height: 22),
        PremiumCard(child: Column(children: [
          FlowTextField(controller: dailyController, label: 'Günlük kiralama bedeli', keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          FlowTextField(controller: durationController, label: 'Kiralama süresi (gün)', keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(value: selectedVehicleSegment, decoration: const InputDecoration(labelText: 'Araç segmenti', helperText: 'Segment karar sonucunu değiştirmez; rapor bilgisi için alınır.'), items: VehicleSegments.items.map((segment) => DropdownMenuItem(value: segment.code, child: Text(segment.displayText))).toList(), onChanged: (value) => setState(() => selectedVehicleSegment = value)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(value: selectedCity, decoration: const InputDecoration(labelText: 'Şehir'), items: TurkeyLocations.cities.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(), onChanged: (value) => setState(() => selectedCity = value)),
          const SizedBox(height: 14),
          FlowTextField(controller: depositController, label: 'Depozito / provizyon (opsiyonel)', keyboardType: TextInputType.number),
        ])),
        const SizedBox(height: 14),
        const TrustNotice(icon: Icons.info_outline_rounded, text: 'Araç kiralama değerlendirmesinde tutar, günlük bedel x kiralama süresi olarak hesaplanır.'),
      ],
      bottom: PrimaryButton(text: 'Devam Et', loading: loading, onPressed: submit),
    );
  }
}
