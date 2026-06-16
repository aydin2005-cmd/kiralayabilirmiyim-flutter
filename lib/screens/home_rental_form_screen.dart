import 'package:flutter/material.dart';
import '../data/turkey_locations.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'pdf_upload_screen.dart';

class HomeRentalFormScreen extends StatefulWidget {
  const HomeRentalFormScreen({super.key});
  @override
  State<HomeRentalFormScreen> createState() => _HomeRentalFormScreenState();
}

class _HomeRentalFormScreenState extends State<HomeRentalFormScreen> {
  final rentController = TextEditingController();
  final depositController = TextEditingController();
  String? selectedCity;
  String? selectedDistrict;
  final districtFieldKey = GlobalKey();
  bool loading = false;
  final api = ApiClient();

  Future<void> submit() async {
    if (rentController.text.isEmpty ||
        selectedCity == null ||
        selectedDistrict == null)
      return _showError('Lütfen zorunlu alanları doldurun.');
    final id = AppState.instance.applicationId;
    if (id == null)
      return _showError('Başvuru bulunamadı. Lütfen tekrar deneyin.');
    setState(() => loading = true);
    try {
      final monthlyRent = num.tryParse(rentController.text) ?? 0;
      await api.patch('/applications/$id/rental-details', {
        'monthly_rent_amount': monthlyRent,
        'city': selectedCity,
        'district': selectedDistrict,
        'deposit_amount': num.tryParse(depositController.text)
      });
      AppState.instance.applicationAmount = monthlyRent;
      AppState.instance.applicationType = 'home_rental';
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PdfUploadScreen()));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 5)));

  @override
  Widget build(BuildContext context) {
    final districtItems = TurkeyLocations.districtsFor(selectedCity);
    return FlowScaffold(
      title: 'Ev Kiralama',
      children: [
        const FlowHeader(
            icon: Icons.home_work_outlined,
            eyebrow: 'Tutar bilgisi',
            title: 'Aylık kira tutarınızı belirtin',
            subtitle:
                'Kira tutarı, Findeks raporundaki finansal göstergelerle birlikte değerlendirmeye alınır.'),
        const SizedBox(height: 22),
        PremiumCard(
            child: Column(children: [
          FlowTextField(
              controller: rentController,
              label: 'Aylık kira tutarı (TL)',
              keyboardType: TextInputType.number,
              helper: 'Örnek: 35000'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
              value: selectedCity,
              isExpanded: true,
              menuMaxHeight: 320,
              decoration: const InputDecoration(labelText: 'İl'),
              items: TurkeyLocations.cities
                  .map((city) =>
                      DropdownMenuItem(value: city, child: Text(city)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value;
                  selectedDistrict = null;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final ctx = districtFieldKey.currentContext;
                  if (ctx != null) {
                    Scrollable.ensureVisible(ctx,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        alignment: 0.25);
                  }
                });
              }),
          const SizedBox(height: 14),
          Container(
              key: districtFieldKey,
              child: DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  isExpanded: true,
                  menuMaxHeight: 320,
                  decoration: const InputDecoration(labelText: 'İlçe'),
                  items: districtItems
                      .map((district) => DropdownMenuItem(
                          value: district, child: Text(district)))
                      .toList(),
                  onChanged: selectedCity == null
                      ? null
                      : (value) => setState(() => selectedDistrict = value))),
          const SizedBox(height: 14),
          FlowTextField(
              controller: depositController,
              label: 'Depozito tutarı (varsa)',
              keyboardType: TextInputType.number),
        ])),
        const SizedBox(height: 14),
        const TrustNotice(
            icon: Icons.info_outline_rounded,
            text:
                'Kira tutarı yalnızca otomatik finansal ön değerlendirme için kullanılır; nihai kiralama kararı ev sahibi veya ilgili kuruma aittir.'),
      ],
      bottom:
          PrimaryButton(text: 'Devam Et', loading: loading, onPressed: submit),
    );
  }
}
