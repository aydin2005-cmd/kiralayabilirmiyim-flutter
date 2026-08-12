import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/flow_widgets.dart';
import 'identity_profile_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String challengeId;
  const OtpScreen(
      {super.key, required this.phoneNumber, required this.challengeId});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  final api = ApiClient();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      return _showError('Lütfen 6 haneli SMS kodunu girin.');
    }
    if (loading) return;

    setState(() => loading = true);
    try {
      final response = await api.post('/auth/otp/verify',
          {'challenge_id': widget.challengeId, 'code': code});
      final token = response['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw ApiException('Oturum başlatılamadı.');
      }
      await api.saveToken(token);
      AppState.instance.token = token;
      AppState.instance.userId = response['user_id']?.toString();
      TextInput.finishAutofillContext(shouldSave: false);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const IdentityProfileScreen()),
          (_) => false);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _handleCodeChanged(String value) {
    if (value.length == 6 && !loading) verify();
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'SMS Doğrulama',
      children: [
        FlowHeader(
            icon: Icons.pin_outlined,
            eyebrow: 'Doğrulama',
            title: 'SMS doğrulama kodunu girin',
            subtitle:
                '${widget.phoneNumber} numarasına gönderilen kodu girerek devam edin.'),
        const SizedBox(height: 22),
        PremiumCard(
          child: AutofillGroup(
            child: TextField(
              controller: codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _handleCodeChanged,
              onSubmitted: (_) => verify(),
              decoration: const InputDecoration(
                labelText: 'SMS kodu',
                helperText: '6 haneli doğrulama kodu',
                counterText: '',
              ),
            ),
          ),
        ),
      ],
      bottom:
          PrimaryButton(text: 'Doğrula', loading: loading, onPressed: verify),
    );
  }
}
