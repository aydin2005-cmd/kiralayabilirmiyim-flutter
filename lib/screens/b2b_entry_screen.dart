import 'package:flutter/material.dart';

import '../services/b2b_api_client.dart';
import '../widgets/flow_widgets.dart';
import '../widgets/primary_button.dart';
import 'b2b_activation_screen.dart';
import 'b2b_login_screen.dart';
import 'b2b_portal_screen.dart';
import 'b2b_registration_screen.dart';

class B2BEntryScreen extends StatefulWidget {
  final B2BApiClient? apiClient;

  const B2BEntryScreen({
    super.key,
    this.apiClient,
  });

  @override
  State<B2BEntryScreen> createState() => _B2BEntryScreenState();
}

class _B2BEntryScreenState extends State<B2BEntryScreen> {
  late final B2BApiClient api;
  bool checking = true;
  bool sessionAvailable = false;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await api.getToken();

    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => checking = false);
      }
      return;
    }

    try {
      await api.get('/b2b/auth/me');
      if (mounted) {
        setState(() {
          sessionAvailable = true;
          checking = false;
        });
      }
    } catch (_) {
      await api.clearToken();
      if (mounted) {
        setState(() {
          sessionAvailable = false;
          checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Kurumsal',
      children: [
        const FlowHeader(
          icon: Icons.business_center_outlined,
          eyebrow: 'Kurumsal Portal',
          title: 'Firmanız için Kiralayabilir Miyim',
          subtitle:
              'Paketlerinizi, bakiyenizi, ekip üyelerinizi ve aday davetlerinizi tek ekrandan yönetin.',
        ),
        const SizedBox(height: 18),
        if (checking)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (sessionAvailable) ...[
            PrimaryButton(
              text: 'Kurumsal Portala Devam Et',
              icon: Icons.dashboard_outlined,
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const B2BPortalScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          PremiumCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const B2BRegistrationScreen(),
              ),
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.add_business_outlined,
                color: FlowColors.green,
                size: 34,
              ),
              title: Text(
                'Kurumsal Hesap Oluştur',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: FlowColors.navyDark,
                ),
              ),
              subtitle: Text(
                'Firmanız için self servis kayıt başlatın.',
              ),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const B2BLoginScreen(),
              ),
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.login_rounded,
                color: FlowColors.teal,
                size: 34,
              ),
              title: Text(
                'Kurumsal Giriş',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: FlowColors.navyDark,
                ),
              ),
              subtitle: Text(
                'Telefon, şifre ve SMS doğrulamasıyla giriş yapın.',
              ),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const B2BActivationScreen(),
              ),
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.verified_user_outlined,
                color: FlowColors.green,
                size: 34,
              ),
              title: Text(
                'İlk Aktivasyon',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: FlowColors.navyDark,
                ),
              ),
              subtitle: Text(
                'RiskMetriks tarafından kurumsal yetkili olarak davet edildiyseniz hesabınızı aktive edin.',
              ),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 14),
          const TrustNotice(
            icon: Icons.security_outlined,
            text:
                'Kurumsal oturum, aday hesabınızdan ayrı ve güvenli bir oturum anahtarıyla saklanır.',
          ),
        ],
      ],
    );
  }
}
