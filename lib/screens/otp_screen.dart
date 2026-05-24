import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'identity_profile_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  final api = ApiClient();
  Future<void> verify() async {
    final code = codeController.text.trim();
    if (code.length < 4) return _showError('Lütfen SMS kodunu girin.');
    setState(() => loading = true);
    try {
      final response = await api.post('/auth/verify-otp', {'phone_number': widget.phoneNumber, 'code': code});
      final token = response['access_token']?.toString();
      if (token == null || token.isEmpty) throw ApiException('Oturum başlatılamadı.');
      await api.saveToken(token);
      AppState.instance.token = token;
      AppState.instance.userId = response['user_id']?.toString();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const IdentityProfileScreen()), (_) => false);
    } catch (e) { _showError(e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }
  void _showError(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'SMS Doğrulama',
      children: [
        FlowHeader(icon: Icons.pin_outlined, eyebrow: 'Doğrulama', title: 'Gelen kodu girin', subtitle: '${widget.phoneNumber} numarasına gönderilen SMS kodu ile devam edin.'),
        const SizedBox(height: 22),
        PremiumCard(child: FlowTextField(controller: codeController, label: 'SMS kodu', keyboardType: TextInputType.number)),
      ],
      bottom: PrimaryButton(text: 'Doğrula', loading: loading, onPressed: verify),
    );
  }
}
