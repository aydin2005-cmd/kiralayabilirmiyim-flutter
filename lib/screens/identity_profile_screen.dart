import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'purpose_screen.dart';

class IdentityProfileScreen extends StatefulWidget {
  const IdentityProfileScreen({super.key});
  @override
  State<IdentityProfileScreen> createState() => _IdentityProfileScreenState();
}

class _IdentityProfileScreenState extends State<IdentityProfileScreen> {
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final tcknController = TextEditingController();
  final api = ApiClient();
  bool loading = false;

  bool isValidTckn(String value) {
    if (!RegExp(r'^\d{11}$').hasMatch(value) || value.startsWith('0')) return false;
    final d = value.split('').map(int.parse).toList();
    final odd = d[0]+d[2]+d[4]+d[6]+d[8];
    final even = d[1]+d[3]+d[5]+d[7];
    return d[9] == ((odd*7)-even)%10 && d[10] == d.take(10).reduce((a,b)=>a+b)%10;
  }

  Future<void> submit() async {
    final firstName = firstNameController.text.trim();
    final middleName = middleNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final tckn = tcknController.text.trim();
    if (firstName.length < 2 || lastName.length < 2) return _showError('Lütfen ad ve soyad bilgilerinizi girin.');
    if (!isValidTckn(tckn)) return _showError('Lütfen geçerli bir TCKN girin.');
    setState(() => loading = true);
    try {
      final payload = {
        'first_name': firstName,
        'middle_name': middleName.isEmpty ? null : middleName,
        'last_name': lastName,
        'tckn': tckn,
      };
      final response = await api.post('/users/profile', payload);
      AppState.instance.firstName = response['first_name']?.toString();
      AppState.instance.middleName = response['middle_name']?.toString();
      AppState.instance.lastName = response['last_name']?.toString();
      AppState.instance.tcknLast3 = response['tckn_last3']?.toString();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PurposeScreen()), (_) => false);
    } catch (e) { _showError(e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Kimlik Bilgileri',
      children: [
        const FlowHeader(icon: Icons.person_search_outlined, eyebrow: 'Rapor eşleştirme', title: 'Rapor sahibini doğrulayalım', subtitle: 'Bu bilgiler, yükleyeceğiniz Findeks raporundaki maskeli ad-soyad ve TCKN son 3 hane ile eşleştirilir.'),
        const SizedBox(height: 22),
        PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TrustNotice(icon: Icons.badge_outlined, text: 'Lütfen adınızı ve soyadınızı kimlik kartınızdaki ile aynı şekilde giriniz.'),
          const SizedBox(height: 14),
          FlowTextField(controller: firstNameController, label: 'Adınız', textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          FlowTextField(controller: middleNameController, label: 'Varsa 2. adınız', textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          FlowTextField(controller: lastNameController, label: 'Soyadınız', textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          FlowTextField(controller: tcknController, label: 'TCKN', keyboardType: TextInputType.number, maxLength: 11, obscureText: true, helper: 'TCKN açık şekilde raporda veya doğrulama ekranında gösterilmez.', inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ])),
        const SizedBox(height: 14),
        const TrustNotice(icon: Icons.shield_outlined, text: 'Ad, varsa 2. ad, soyad ve TCKN son 3 hane raporun size ait olduğunu doğrulamak için kullanılır. Paylaşılan raporlarda yalnızca maskeli bilgiler görünür.'),
      ],
      bottom: PrimaryButton(text: 'Devam Et', loading: loading, onPressed: submit),
    );
  }
}
