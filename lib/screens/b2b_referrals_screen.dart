import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/b2b_api_client.dart';
import '../services/b2b_helpers.dart';
import '../widgets/flow_widgets.dart';

class B2BReferralsScreen extends StatefulWidget {
  const B2BReferralsScreen({super.key});

  @override
  State<B2BReferralsScreen> createState() => _B2BReferralsScreenState();
}

class _B2BReferralsScreenState extends State<B2BReferralsScreen> {
  final B2BApiClient api = B2BApiClient();
  final phoneController = TextEditingController();
  final labelController = TextEditingController();

  List<Map<String, dynamic>> referrals = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    phoneController.dispose();
    labelController.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _httpsReferralLink(String token) =>
      'https://kiralayabilirmiyim.com/basvuru/$token';

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final rows = await api.getList('/b2b/portal/referral-links');
      if (mounted) {
        setState(() => referrals = rows);
      }
    } catch (e) {
      message(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> create() async {
    final phone = normalizeTurkeyMobile(phoneController.text);
    if (phone == null) {
      message('Geçerli bir Türkiye cep telefonu numarası giriniz.');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await api.post(
        '/b2b/portal/referral-links',
        {
          'phone_number': phone,
          'label': labelController.text.trim().isEmpty
              ? null
              : labelController.text.trim(),
        },
      );

      phoneController.clear();
      labelController.clear();

      final token = result['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await Clipboard.setData(
          ClipboardData(
            text: _httpsReferralLink(token),
          ),
        );
        message(
          'Davet oluşturuldu; davet bağlantısı panoya kopyalandı.',
        );
      }

      await load();
    } catch (e) {
      message(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> revoke(String linkId) async {
    setState(() => loading = true);

    try {
      await api.post(
        '/b2b/portal/referral-links/${Uri.encodeComponent(linkId)}/revoke',
        {},
      );
      await load();
    } catch (e) {
      message(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> copyLink(Map<String, dynamic> item) async {
    final token = item['token']?.toString();
    if (token == null || token.isEmpty) {
      message('Davet tokenı bulunamadı.');
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: _httpsReferralLink(token),
      ),
    );
    message('Davet bağlantısı panoya kopyalandı.');
  }

  Widget referralCard(Map<String, dynamic> item) {
    final linkId = item['link_id']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['label']?.toString().trim().isNotEmpty == true
                  ? item['label'].toString()
                  : 'Aday Daveti',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: FlowColors.navyDark,
              ),
            ),
            const SizedBox(height: 5),
            Text('Telefon: ${item['invited_phone_e164'] ?? '-'}'),
            Text('Durum: ${b2bStatusLabel(status)}'),
            Text('Oluşturma: ${shortDate(item['created_at'])}'),
            if (item['expires_at'] != null)
              Text('Son tarih: ${shortDate(item['expires_at'])}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Davet Linkini Kopyala'),
                  onPressed: () => copyLink(item),
                ),
                if (linkId.isNotEmpty && status != 'revoked')
                  ActionChip(
                    avatar: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('İptal Et'),
                    onPressed: () => revoke(linkId),
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
      title: 'Aday Davetleri',
      children: [
        const FlowHeader(
          icon: Icons.link_outlined,
          eyebrow: 'Aday Daveti',
          title: 'Telefon numarasına bağlı davet oluşturun',
          subtitle:
              'Davet bağlantısı yalnız belirtilen doğrulanmış cep telefonu ile kurumsal başvuruya bağlanabilir.',
        ),
        const SizedBox(height: 18),
        PremiumCard(
          child: Column(
            children: [
              FlowTextField(
                controller: phoneController,
                label: 'Aday cep telefonu',
                helper: 'Başında 0 olmadan 5XXXXXXXXX formatında giriniz.',
                prefixText: '+90 ',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: const [
                  TurkeyMobileFieldFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              FlowTextField(
                controller: labelController,
                label: 'Açıklama / referans',
                helper: 'Örn: Göksu Villa - Ağustos 2026',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : create,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Davet Oluştur'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (loading && referrals.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (referrals.isEmpty)
          const TrustNotice(
            icon: Icons.info_outline,
            text: 'Henüz aday daveti oluşturulmamış.',
          )
        else
          ...referrals.map(referralCard),
      ],
    );
  }
}
