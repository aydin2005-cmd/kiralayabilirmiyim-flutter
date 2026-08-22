import 'package:flutter/material.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';
import 'b2b_applications_screen.dart';
import 'b2b_entry_screen.dart';
import 'b2b_login_screen.dart';
import 'b2b_members_screen.dart';
import 'b2b_packages_screen.dart';
import 'b2b_referrals_screen.dart';

class B2BPortalScreen extends StatefulWidget {
  final B2BApiClient? apiClient;

  const B2BPortalScreen({
    super.key,
    this.apiClient,
  });

  @override
  State<B2BPortalScreen> createState() => _B2BPortalScreenState();
}

class _B2BPortalScreenState extends State<B2BPortalScreen> {
  late final B2BApiClient api;

  Map<String, dynamic>? me;
  Map<String, dynamic>? credits;
  bool loading = true;
  String? error;

  String get role => me?['role']?.toString() ?? '';
  bool get canManage => role == 'owner' || role == 'admin';
  bool get canManageReferrals => canManage || role == 'operator';

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final meResponse = await api.get('/b2b/auth/me');
      final creditResponse = await api.get('/b2b/portal/credits');

      if (!mounted) {
        return;
      }

      setState(() {
        me = meResponse;
        credits = creditResponse;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _clearSession() async {
    try {
      await api.post('/b2b/auth/logout', {});
    } catch (_) {
      // Local token must still be cleared if server-side logout cannot finish.
    }

    await api.clearToken();
  }

  Future<void> logout() async {
    await _clearSession();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const B2BEntryScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> switchOrganization() async {
    final phone =
        me?['phone_e164']?.toString() ?? me?['phone_number']?.toString() ?? '';

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yetkili telefon bilgisi alınamadı. '
            'Lütfen oturumu kapatıp tekrar giriş yapın.',
          ),
        ),
      );
      return;
    }

    await _clearSession();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => B2BLoginScreen(
          initialPhone: turkeyMobileFieldDigits(phone),
          apiClient: api,
        ),
      ),
      (route) => false,
    );
  }

  Widget tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        ).then((_) => load()),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: FlowColors.teal, size: 32),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: FlowColors.navyDark,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null || me == null) {
      return FlowScaffold(
        title: 'Kurumsal Portal',
        children: [
          const FlowHeader(
            icon: Icons.error_outline_rounded,
            eyebrow: 'Kurumsal Portal',
            title: 'Portal bilgileri alınamadı',
            subtitle:
                'Kurumsal oturumunuzu ve internet bağlantınızı kontrol edin.',
          ),
          const SizedBox(height: 16),
          TrustNotice(
            icon: Icons.info_outline,
            text: error ?? 'Kurumsal oturum bulunamadı.',
            background: FlowColors.amberBg,
            borderColor: FlowColors.amberBorder,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: load,
            child: const Text('Tekrar Dene'),
          ),
          TextButton(
            onPressed: logout,
            child: const Text('Kurumsal Oturumu Kapat'),
          ),
        ],
      );
    }

    final organizationName = me?['organization_name']?.toString() ?? '-';
    final usable = credits?['usable_credits'] ?? 0;
    final awaiting = credits?['awaiting_activation_credits'] ?? 0;

    return FlowScaffold(
      title: 'Kurumsal Portal',
      children: [
        FlowHeader(
          icon: Icons.business_center_outlined,
          eyebrow: 'Kurumsal Portal',
          title: organizationName,
          subtitle:
              '${b2bRoleLabel(role)} olarak giriş yaptınız. Paket ve aday süreçlerinizi buradan yönetin.',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: PremiumCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: FlowColors.green,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$usable',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: FlowColors.navyDark,
                      ),
                    ),
                    const Text('Kullanılabilir Kredi'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      color: FlowColors.teal,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$awaiting',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: FlowColors.navyDark,
                      ),
                    ),
                    const Text('Aktivasyon Bekleyen'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        tile(
          icon: Icons.shopping_bag_outlined,
          title: 'Paketler',
          subtitle: canManage
              ? 'Paketleri inceleyin, satın alın ve ödeme durumunu takip edin.'
              : 'Kurumsal paketleri ve fiyatları görüntüleyin.',
          destination: B2BPackagesScreen(canPurchase: canManage),
        ),
        if (canManage)
          tile(
            icon: Icons.group_outlined,
            title: 'Ekip Üyeleri',
            subtitle: 'Yetkili davet edin, rolleri yönetin ve erişimi kapatın.',
            destination: B2BMembersScreen(
              currentMemberId: me?['member_id']?.toString(),
              apiClient: api,
            ),
          ),
        if (canManageReferrals)
          tile(
            icon: Icons.link_outlined,
            title: 'Aday Davetleri',
            subtitle:
                'Telefon numarasına bağlı başvuru bağlantıları oluşturun.',
            destination: const B2BReferralsScreen(),
          ),
        tile(
          icon: Icons.fact_check_outlined,
          title: 'Başvurular',
          subtitle:
              'Kurumsal davetlerle gelen başvuruları ve sonuç durumlarını izleyin.',
          destination: const B2BApplicationsScreen(),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Bakiyeyi Yenile'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('b2b-switch-organization'),
          onPressed: switchOrganization,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Kurumu Değiştir'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Kurumsal Oturumu Kapat'),
        ),
      ],
    );
  }
}
