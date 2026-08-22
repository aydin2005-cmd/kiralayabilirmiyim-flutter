import 'package:flutter/material.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';

class B2BMembersScreen extends StatefulWidget {
  final String? currentMemberId;
  final B2BApiClient? apiClient;

  const B2BMembersScreen({
    super.key,
    this.currentMemberId,
    this.apiClient,
  });

  @override
  State<B2BMembersScreen> createState() => _B2BMembersScreenState();
}

class _B2BMembersScreenState extends State<B2BMembersScreen> {
  late final B2BApiClient api;
  final phoneController = TextEditingController();

  String inviteRole = 'viewer';
  List<Map<String, dynamic>> members = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = widget.apiClient ?? B2BApiClient();
    load();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final rows = await api.getList('/b2b/members');
      if (mounted) {
        setState(() => members = rows);
      }
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> invite() async {
    final phone = normalizeTurkeyMobile(phoneController.text);
    if (phone == null) {
      error('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    setState(() => loading = true);

    try {
      await api.post(
        '/b2b/members/invite',
        {
          'phone_number': phone,
          'role': inviteRole,
        },
      );

      phoneController.clear();
      await load();
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> changeRole(String memberId, String role) async {
    setState(() => loading = true);

    try {
      await api.patch(
        '/b2b/members/${Uri.encodeComponent(memberId)}/role',
        {'role': role},
      );
      await load();
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> disable(String memberId) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yetkili erişimini kapat'),
        content: const Text(
          'Bu kullanıcının kurumsal erişimi devre dışı bırakılacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devre Dışı Bırak'),
          ),
        ],
      ),
    );

    if (approved != true) {
      return;
    }

    setState(() => loading = true);

    try {
      await api.post(
        '/b2b/members/${Uri.encodeComponent(memberId)}/disable',
        {},
      );
      await load();
    } catch (e) {
      error(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget memberCard(Map<String, dynamic> member) {
    final memberId = member['member_id']?.toString() ?? '';
    final role = member['role']?.toString() ?? '';
    final status = member['status']?.toString() ?? '';
    final isSelf = memberId.isNotEmpty && memberId == widget.currentMemberId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member['phone_e164']?.toString() ?? '-',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: FlowColors.navyDark,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${b2bRoleLabel(role)} · ${b2bStatusLabel(status)}',
                  ),
                ),
                if (isSelf)
                  const Chip(
                    key: ValueKey('b2b-member-self-chip'),
                    label: Text('Siz'),
                  ),
              ],
            ),
            if (member['last_login_at'] != null)
              Text(
                'Son giriş: ${shortDate(member['last_login_at'])}',
                style: const TextStyle(color: FlowColors.muted),
              ),
            if (memberId.isNotEmpty &&
                !isSelf &&
                role != 'owner' &&
                status != 'disabled')
              Wrap(
                key: ValueKey('b2b-member-actions-$memberId'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) => changeRole(memberId, value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'admin',
                        child: Text('Yönetici yap'),
                      ),
                      PopupMenuItem(
                        value: 'operator',
                        child: Text('Operatör yap'),
                      ),
                      PopupMenuItem(
                        value: 'viewer',
                        child: Text('Görüntüleyici yap'),
                      ),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.manage_accounts_outlined, size: 18),
                      label: Text('Rol Değiştir'),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.block_outlined, size: 18),
                    label: const Text('Erişimi Kapat'),
                    onPressed: () => disable(memberId),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Ekip Üyeleri',
      children: [
        const FlowHeader(
          icon: Icons.group_outlined,
          eyebrow: 'Yetkililer',
          title: 'Kurumsal ekibinizi yönetin',
          subtitle:
              'Yeni kullanıcı davet edin, rollerini değiştirin veya erişimlerini kapatın.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          child: Column(
            children: [
              FlowTextField(
                controller: phoneController,
                label: 'Yeni yetkili cep telefonu',
                helper: 'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                prefixText: '+90 ',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: const [
                  TurkeyMobileFieldFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: inviteRole,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Yönetici'),
                  ),
                  DropdownMenuItem(
                    value: 'operator',
                    child: Text('Operatör'),
                  ),
                  DropdownMenuItem(
                    value: 'viewer',
                    child: Text('Görüntüleyici'),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => inviteRole = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : invite,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Yetkili Davet Et'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (loading && members.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          ...members.map(memberCard),
      ],
    );
  }
}
