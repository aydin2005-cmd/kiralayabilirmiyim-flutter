import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_state.dart';
import '../services/payment_flow.dart';
import '../widgets/primary_button.dart';
import 'share_screen.dart';
import 'purpose_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const _navy = Color(0xFF123C69);
  static const _teal = Color(0xFF0F766E);
  static const _green = Color(0xFF087A4A);
  static const _lightGreen = Color(0xFFF0FBF8);
  static const _border = Color(0xFFD9E2EC);

  String resultType = '';
  String? summaryText;
  String? recommendationText;
  bool shareable = false;
  bool fullReportLocked = false;
  bool paymentCompleted = false;
  bool loading = true;
  bool paymentProcessing = false;
  String? errorMessage;
  List<dynamic> explanationItems = [];
  Map<String, dynamic> displayMetrics = {};
  Map<String, dynamic> financialSummary = {};
  Map<String, dynamic> findeksScoreVisual = {};
  Map<String, dynamic> paymentHabit = {};
  Map<String, dynamic> reportPersonalization = {};
  Map<String, dynamic> pricingInfo = {};
  final api = ApiClient();

  @override
  void initState() {
    super.initState();
    loadResult();
  }

  Future<void> loadResult() async {
    try {
      final id = AppState.instance.analysisId;
      if (id == null) throw ApiException('Analiz sonucu bulunamadı.');

      final response = await api.get('/analysis/$id/result');
      resultType = response['result_type']?.toString() ?? '';
      summaryText = response['summary_text']?.toString();
      recommendationText = response['recommendation_text']?.toString();
      shareable = response['shareable'] == true && resultType == 'positive';
      explanationItems = response['explanation_items'] is List ? response['explanation_items'] as List<dynamic> : [];
      displayMetrics = response['display_metrics'] is Map<String, dynamic> ? response['display_metrics'] as Map<String, dynamic> : {};
      financialSummary = response['financial_summary'] is Map<String, dynamic> ? response['financial_summary'] as Map<String, dynamic> : {};
      findeksScoreVisual = response['findeks_score_visual'] is Map<String, dynamic> ? response['findeks_score_visual'] as Map<String, dynamic> : {};
      paymentHabit = response['payment_habit'] is Map<String, dynamic> ? response['payment_habit'] as Map<String, dynamic> : {};
      reportPersonalization = response['report_personalization'] is Map<String, dynamic> ? response['report_personalization'] as Map<String, dynamic> : {};
      pricingInfo = response['pricing_info'] is Map<String, dynamic> ? response['pricing_info'] as Map<String, dynamic> : {};
      final feeRaw = pricingInfo['service_fee_amount'];
      if (feeRaw is num) {
        AppState.instance.serviceFeeAmount = feeRaw;
      } else if (feeRaw != null) {
        AppState.instance.serviceFeeAmount = num.tryParse(feeRaw.toString().replaceAll(',', '.')) ?? AppState.instance.serviceFeeAmount;
      }
      AppState.instance.serviceFeeCurrency = pricingInfo['service_fee_currency']?.toString() ?? AppState.instance.serviceFeeCurrency;
      fullReportLocked = response['full_report_locked'] == true || pricingInfo['full_report_locked_until_payment'] == true;
      paymentCompleted = pricingInfo['payment_completed'] == true || AppState.instance.paymentCompleted;
      AppState.instance.resultType = resultType;
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  bool get _isPositive => resultType == 'positive' && shareable;

  String get _negativeTitle => 'Değerlendirme tamamlandı';

  String get _negativeBody {
    final main = 'Bu başvuru için olumlu sonuç oluşmadı';
    if (recommendationText != null && recommendationText!.isNotEmpty) {
      return '$main\n\nRapor başarıyla incelendi. Ancak mevcut finansal göstergeler ve beyan edilen tutar dikkate alındığında paylaşılabilir olumlu sonuç oluşmamıştır.';
    }
    return '$main\n\nRapor başarıyla incelendi. Ancak mevcut finansal göstergeler ve beyan edilen tutar dikkate alındığında paylaşılabilir olumlu sonuç oluşmamıştır.';
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      if (value.abs() >= 1000) {
        return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
      }
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    }
    return value.toString();
  }

  String _formatTl(dynamic value) => value == null ? '-' : '${_formatValue(value)} TL';
  String _formatPaymentAmount(dynamic value) => value == null ? '-' : _formatValue(value);

  String _applicationTypeLabel() {
    final raw = AppState.instance.applicationType ?? displayMetrics['application_type']?.toString() ?? financialSummary['application_type']?.toString();
    if (raw == 'car_rental') return 'Araç Kiralama';
    return 'Ev Kiralama';
  }

  String _amountTitle() => _applicationTypeLabel() == 'Araç Kiralama' ? 'Beyan Edilen Kiralama Tutarı' : 'Beyan Edilen Kira Tutarı';

  bool get _isCarRental => _applicationTypeLabel() == 'Araç Kiralama';

  String get _amountSubject => _isCarRental ? 'Beyan edilen kiralama tutarı' : 'Beyan edilen kira tutarı';

  dynamic _applicationAmount() => financialSummary['application_amount'] ?? displayMetrics['application_amount'] ?? AppState.instance.applicationAmount;
  dynamic _capacityIndicator() => financialSummary['average_limit_per_institution'] ?? displayMetrics['average_limit_per_institution'];


  Map<String, dynamic> _profileMap(String key) {
    final value = reportPersonalization[key];
    if (value is Map<String, dynamic>) return value;
    final fromMetrics = displayMetrics['${key}_category'];
    if (fromMetrics is Map<String, dynamic>) return fromMetrics;
    return {};
  }

  String _profileLabel(String key, String fallback) {
    final map = _profileMap(key);
    final value = map['label']?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String _profileComment(String key, String fallback) {
    final map = _profileMap(key);
    final value = map['comment']?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String _debtRatioText() {
    final raw = displayMetrics['debt_limit_ratio_percent'] ?? financialSummary['debt_limit_ratio_percent'] ?? displayMetrics['debt_limit_ratio'];
    if (raw == null) return '';
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString().replaceAll(',', '.'));
    if (n == null) return '';
    final pct = n <= 1 ? n * 100 : n;
    return '%${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}';
  }

  int? _scoreAsInt() {
    final raw = findeksScoreVisual['score'] ?? displayMetrics['findeks_score'];
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _scoreBandLabel(int score) {
    if (score <= 969) return 'En Riskli';
    if (score <= 1149) return 'Orta Riskli';
    if (score <= 1469) return 'Az Riskli';
    if (score <= 1719) return 'İyi';
    return 'Çok İyi';
  }

  double _scorePosition(int score) {
    final clamped = score.clamp(1, 1900);
    final bands = [
      [1, 969],
      [970, 1149],
      [1150, 1469],
      [1470, 1719],
      [1720, 1900],
    ];
    for (var i = 0; i < bands.length; i++) {
      final start = bands[i][0];
      final end = bands[i][1];
      if (clamped >= start && clamped <= end) {
        final within = end == start ? 0.5 : (clamped - start) / (end - start);
        return ((i + within) / bands.length).clamp(0.02, 0.98);
      }
    }
    return 0.98;
  }

  String? _firstNonEmpty(List<dynamic> keys) {
    for (final key in keys) {
      final value = key?.toString();
      if (value != null && value.trim().isNotEmpty && value.trim() != 'null') return value.trim();
    }
    return null;
  }

  String? _formatDisplayDate(String? value) {
    if (value == null || value.trim().isEmpty) return value;
    final text = value.trim();
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    }
    return text;
  }

  Map<String, dynamic> _applicantIdentity() {
    final fromMetrics = displayMetrics['applicant_identity'];
    if (fromMetrics is Map<String, dynamic>) return fromMetrics;
    final fromFinancial = financialSummary['applicant_identity'];
    if (fromFinancial is Map<String, dynamic>) return fromFinancial;

    final first = AppState.instance.firstName;
    final middle = AppState.instance.middleName;
    final last = AppState.instance.lastName;
    final tcknLast3 = AppState.instance.tcknLast3;
    return {
      'masked_full_name': _maskedName(first, last, middle),
      'masked_tckn': _maskedTckn(tcknLast3),
      'identity_match_status': 'Doğrulandı',
    };
  }

  String _normalizeName(String? value) {
    final upper = (value ?? '').trim().toUpperCase();
    return upper.replaceAll(RegExp(r'[^A-ZÇĞİÖŞÜ]'), '');
  }

  String _maskPart(String? value, int minStars) {
    final norm = _normalizeName(value);
    if (norm.isEmpty) return '-';
    final prefix = norm.length >= 2 ? norm.substring(0, 2) : norm.substring(0, 1);
    final starCount = (norm.length - prefix.length) > minStars ? (norm.length - prefix.length) : minStars;
    return '$prefix${List.filled(starCount, '*').join()}';
  }

  String _maskedName(String? first, String? last, [String? middle]) {
    final parts = <String>[];
    final f = _maskPart(first, 5);
    if (f != '-') parts.add(f);
    final middleParts = (middle ?? '').trim().split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty);
    for (final part in middleParts) {
      final masked = _maskPart(part, 3);
      if (masked != '-') parts.add(masked);
    }
    final l = _maskPart(last, 3);
    if (l != '-') parts.add(l);
    return parts.isEmpty ? '-' : parts.join(' ');
  }

  String _maskedTckn(String? last3) {
    final digits = (last3 ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 3) return '-';
    return '********${digits.substring(digits.length - 3)}';
  }

  Widget _applicantIdentityCard() {
    final identity = _applicantIdentity();
    final name = identity['masked_full_name']?.toString() ?? '-';
    final tckn = identity['masked_tckn']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Başvuru Sahibi Bilgileri', style: TextStyle(fontSize: 16, color: _navy, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _inlineData('Ad Soyad', name)),
          const SizedBox(width: 10),
          Expanded(child: _inlineData('TCKN', tckn)),
        ]),
        const SizedBox(height: 10),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_outlined, color: _green, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('Kimlik bilgileri Findeks raporundaki maskeli alanlarla uyumlu bulunmuştur.', style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54, fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }

  Widget _heroCard({required bool locked}) {
    final artIcon = _isCarRental ? Icons.directions_car_filled_outlined : Icons.house_outlined;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF073B4D), Color(0xFF123C69), Color(0xFF0B2545)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -18,
            child: Icon(artIcon, size: 120, color: Colors.white.withOpacity(0.10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE9F8F3),
                      boxShadow: [BoxShadow(color: _green.withOpacity(0.28), blurRadius: 24, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.verified_rounded, color: _green, size: 42),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text(
                        'EVET,',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -0.8),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'KİRALAYABİLİRSİNİZ',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -0.8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Findeks finansal göstergeleriniz, beyan edilen kira tutarı için olumlu görünmektedir.',
                        style: TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFE9F8F3), borderRadius: BorderRadius.circular(999)),
                        child: const Text('✓ Sonuç: Kiralama için uygun', style: TextStyle(color: Color(0xFF075E47), fontWeight: FontWeight.w900, fontSize: 12.5)),
                      ),
                    ]),
                  ),
                ],
              ),
              if (locked) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                  child: const Text(
                    'Olumlu sonuç raporunuz hazır. Tam rapor, PDF ve paylaşım linki ödeme sonrasında açılacaktır.',
                    style: TextStyle(color: Colors.white, height: 1.35, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickSummaryCards() {
    final today = DateTime.now();
    final valid = today.add(const Duration(days: 15));
    final reportDate = _formatDisplayDate(_firstNonEmpty([
          displayMetrics['report_date'],
          financialSummary['report_date'],
          pricingInfo['report_date'],
        ])) ?? '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';
    final validDate = _formatDisplayDate(_firstNonEmpty([
          displayMetrics['valid_until'],
          displayMetrics['validity_date'],
          financialSummary['valid_until'],
          pricingInfo['valid_until'],
        ])) ?? '${valid.day.toString().padLeft(2, '0')}.${valid.month.toString().padLeft(2, '0')}.${valid.year}';

    final items = [
      _SummaryItem(_isCarRental ? Icons.directions_car_filled_outlined : Icons.home_work_outlined, 'Kiralama Türü', _applicationTypeLabel()),
      _SummaryItem(Icons.payments_outlined, _amountTitle(), _formatTl(_applicationAmount())),
      _SummaryItem(Icons.calendar_month_outlined, 'Rapor Oluşturma Tarihi', reportDate),
      _SummaryItem(Icons.event_available_outlined, 'Geçerlilik Tarihi', validDate),
    ];

    return Column(
      children: [
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: items.map((e) => _summaryTile(e)).toList(),
        ),
      ],
    );
  }

  Widget _summaryTile(_SummaryItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(color: Color(0xFFE9F8F3), shape: BoxShape.circle),
          child: Icon(item.icon, color: _teal, size: 26),
        ),
        const SizedBox(height: 10),
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(item.value, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
        ),
      ]),
    );
  }

  Future<void> _startPaymentFromResult() async {
    setState(() => paymentProcessing = true);
    try {
      final ok = await PaymentFlow.startAndWait(
        context: context,
        api: api,
        onStatus: (_) {},
      );

      if (!ok) {
        throw ApiException('Ödeme tamamlanamadı.');
      }

      if (!mounted) return;
      if (!AppState.instance.markPaymentSuccessHandled()) {
        await loadResult();
        return;
      }
      await _showPaymentSuccessSheet();
      if (!mounted) return;
      await loadResult();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => paymentProcessing = false);
    }
  }


  Future<void> _checkPaymentStatusFromResult() async {
    setState(() => paymentProcessing = true);
    try {
      final paid = await PaymentFlow.checkCurrentStatus(api: api);
      if (!paid) {
        throw ApiException('Ödeme sonucu henüz alınamadı. Ödemeyi tamamladıysanız birkaç saniye sonra tekrar kontrol edin.');
      }
      if (!mounted) return;
      if (!AppState.instance.markPaymentSuccessHandled()) {
        await loadResult();
        return;
      }
      await _showPaymentSuccessSheet();
      if (!mounted) return;
      await loadResult();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => paymentProcessing = false);
    }
  }

  Future<void> _showPaymentSuccessSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_rounded, size: 58, color: _green),
                SizedBox(height: 14),
                Text('Ödeme başarılı', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
                SizedBox(height: 8),
                Text('Tam raporunuz açılıyor.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF475569), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _paymentProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.28),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3, color: _teal)),
                SizedBox(height: 18),
                Text('Ödeme kontrol ediliyor...', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _navy)),
                SizedBox(height: 8),
                Text('Lütfen bu ekrandan ayrılmayın.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedPositiveReport() {
    final amount = pricingInfo['service_fee_amount'] ?? AppState.instance.serviceFeeAmount;
    final currency = pricingInfo['service_fee_currency']?.toString() ?? 'TL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(locked: true),
        _applicantIdentityCard(),
        _quickSummaryCards(),
        const SizedBox(height: 16),
        _sectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rapor oluşturma ve paylaşım hizmet bedeli', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
            const SizedBox(height: 8),
            Text('${_formatPaymentAmount(amount)} $currency', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _green)),
            const SizedBox(height: 10),
            const Text(
              'Ödeme sonrası tam rapor, PDF ve paylaşım linki erişime açılır.',
              style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF075E47), fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          text: '${_formatPaymentAmount(amount)} $currency Öde, Raporu Aç',
          loading: paymentProcessing,
          onPressed: paymentProcessing ? null : _startPaymentFromResult,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: paymentProcessing ? null : _checkPaymentStatusFromResult,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Ödemeyi Kontrol Et ve Devam Et'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            side: const BorderSide(color: _teal, width: 1.4),
            foregroundColor: _teal,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _navy)),
      );

  Widget _positiveReasons() {
    final rawReasons = reportPersonalization['positive_reasons'];
    final reasons = rawReasons is List && rawReasons.isNotEmpty
        ? rawReasons.map((e) => e.toString()).take(6).toList()
        : [
            'Yasal takip kaydı görülmedi',
            'Ödeme düzeniniz ${_paymentOrderLabel().toLowerCase()} seviyede',
            'Mevcut borç yükünüz ${_debtLoadLabel().toLowerCase()} seviyede',
            'Finansal kapasite göstergeniz ${_capacityLabel().toLowerCase()} seviyede',
            '${_isCarRental ? 'Kiralama tutarı' : 'Kira tutarı'} finansal göstergelerle ${_rentAlignmentLabel().toLowerCase()}',
            'Diğer finansal kontrol noktaları da olumlu sonuçlandı',
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Neden Olumlu Değerlendirildi?'),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: reasons.map((r) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFBFEFD), border: Border.all(color: const Color(0xFFCFEDE5)), borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Color(0xFFDFF7EC), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: _green, size: 21),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(r, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25, fontSize: 12.5))),
          ]),
        )).toList(),
      ),
    ]);
  }

  String _paymentOrderLabel() {
    final fromProfile = reportPersonalization['payment_order'];
    if (fromProfile is Map<String, dynamic> && (fromProfile['label']?.toString().trim().isNotEmpty ?? false)) return fromProfile['label'].toString();
    return paymentHabit['label']?.toString().trim().isNotEmpty == true ? paymentHabit['label'].toString() : 'Olumlu';
  }

  String _debtLoadLabel() => _profileLabel('debt_load', 'Uygun');
  String _capacityLabel() => _profileLabel('financial_capacity', 'Olumlu');
  String _rentAlignmentLabel() => _profileLabel('rent_alignment', 'Uyumlu');

  Widget _findeksIndicators() {
    final score = _scoreAsInt();
    final label = score == null ? '-' : _scoreBandLabel(score);
    final habit = _paymentOrderLabel();
    final debtText = _debtRatioText();
    final debtValue = debtText.isEmpty ? _debtLoadLabel() : '${_debtLoadLabel()} ($debtText)';
    final capacityValue = _capacityIndicator() == null ? _capacityLabel() : '${_capacityLabel()} / ${_formatTl(_capacityIndicator())}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Findeks Finansal Göstergeleri'),
      Row(children: [
        Expanded(child: _metricCard(Icons.speed_rounded, 'Findeks Notu', score == null ? '-' : '$score / $label')),
        const SizedBox(width: 10),
        Expanded(child: _metricCard(Icons.star_rounded, 'Ödeme Düzeni', habit)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _metricCard(Icons.pie_chart_outline_rounded, 'Mevcut Borç Yükü', debtValue)),
        const SizedBox(width: 10),
        Expanded(child: _metricCard(Icons.trending_up_rounded, 'Finansal Kapasite', capacityValue)),
      ]),
      if (score != null) ...[
        const SizedBox(height: 14),
        _findeksScale(score),
      ],
    ]);
  }


  Widget _categoryProfile() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Kişisel Finansal Profil'),
      _categoryPanel(
        icon: Icons.star_rounded,
        title: 'Ödeme Düzeni',
        selected: _paymentOrderLabel(),
        options: const [
          _CategoryOption('Mükemmel'),
          _CategoryOption('Çok İyi'),
          _CategoryOption('İyi'),
          _CategoryOption('Kabul Edilebilir'),
        ],
      ),
      const SizedBox(height: 12),
      _categoryPanel(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Mevcut Borç Yükü',
        selected: _debtLoadLabel(),
        options: const [
          _CategoryOption('Çok Düşük Borçluluk'),
          _CategoryOption('Düşük Borçluluk'),
          _CategoryOption('Orta Düzey Borçluluk'),
          _CategoryOption('Yüksek Ama Kabul Edilebilir Borçluluk', warning: true),
        ],
      ),
      const SizedBox(height: 12),
      _categoryPanel(
        icon: Icons.trending_up_rounded,
        title: 'Finansal Kapasite',
        selected: _capacityLabel(),
        options: const [
          _CategoryOption('Mükemmel'),
          _CategoryOption('Çok İyi'),
          _CategoryOption('İyi'),
          _CategoryOption('Kabul Edilebilir', warning: true),
        ],
      ),
      const SizedBox(height: 12),
      _categoryPanel(
        icon: _isCarRental ? Icons.directions_car_filled_outlined : Icons.home_work_outlined,
        title: _isCarRental ? 'Kiralama Tutarı Uyumu' : 'Kira Tutarı Uyumu',
        selected: _rentAlignmentLabel(),
        options: const [
          _CategoryOption('Mükemmel Uyumlu'),
          _CategoryOption('Çok İyi Uyumlu'),
          _CategoryOption('Uyumlu'),
          _CategoryOption('Kabul Edilebilir'),
        ],
      ),
    ]);
  }

  Widget _categoryPanel({required IconData icon, required String title, required String selected, required List<_CategoryOption> options}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBEE9DD), width: 1.8),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: Color(0xFFE9F8F3), shape: BoxShape.circle),
            child: Icon(icon, color: _teal, size: 29),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _navy))),
        ]),
        const SizedBox(height: 12),
        ...options.map((option) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _categoryOption(option.label, _labelMatches(option.label, selected), option.warning),
        )),
      ]),
    );
  }

  bool _labelMatches(String a, String b) => _normalizeCategoryLabel(a) == _normalizeCategoryLabel(b);

  String _normalizeCategoryLabel(String value) => value.toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  Widget _categoryOption(String label, bool selected, bool warning) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? (warning ? const Color(0xFFFFF3E0) : const Color(0xFFE9F8F3)) : const Color(0xFFF8FAFC),
        border: Border.all(color: selected ? (warning ? const Color(0xFFF59E0B) : const Color(0xFF20A978)) : const Color(0xFFDDE7F1), width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected ? [BoxShadow(color: warning ? const Color(0x22F59E0B) : const Color(0x22108A56), blurRadius: 12, offset: const Offset(0, 6))] : null,
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: selected ? (warning ? const Color(0xFF7C2D12) : const Color(0xFF064E3B)) : const Color(0xFF334155))),
        ])),
        const SizedBox(width: 10),
        Container(
          width: selected ? 50 : 32,
          height: selected ? 50 : 32,
          decoration: BoxDecoration(
            color: selected ? (warning ? const Color(0xFFF59E0B) : _green) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? (warning ? const Color(0xFFF59E0B) : _green) : const Color(0xFFC8D5E3)),
            boxShadow: selected ? [BoxShadow(color: warning ? const Color(0x33F59E0B) : const Color(0x33108A56), blurRadius: 12, offset: const Offset(0, 5))] : null,
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 34) : null,
        ),
      ]),
    );
  }

  Widget _metricCard(IconData icon, String title, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: Color(0xFFE9F8F3), shape: BoxShape.circle),
          child: Icon(icon, color: _teal, size: 28),
        ),
        const SizedBox(height: 10),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 16, color: _navy, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _findeksScale(int score) {
    final pos = _scorePosition(score);
    final label = _scoreBandLabel(score);
    return _sectionCard(
      padding: const EdgeInsets.fromLTRB(12, 96, 12, 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final markerX = (w * pos).clamp(0.0, w).toDouble();
        final maxBubbleLeft = w > 110 ? w - 110 : 0.0;
        final bubbleLeft = (markerX - 55).clamp(0.0, maxBubbleLeft).toDouble();
        final stemLeft = (markerX - 1.5).clamp(0.0, w - 3).toDouble();
        final arrowLeft = (markerX - 11).clamp(0.0, w - 22).toDouble();
        return Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Row(children: const [
              _Band(label: 'En Riskli', color: Color(0xFFA12A2A)),
              _Band(label: 'Orta Riskli', color: Color(0xFFD46A1F)),
              _Band(label: 'Az Riskli', color: Color(0xFFD8A723)),
              _Band(label: 'İyi', color: Color(0xFF7FA83B)),
              _Band(label: 'Çok İyi', color: Color(0xFF218C61)),
            ]),
            Positioned(
              left: bubbleLeft,
              top: -86,
              child: SizedBox(
                width: 110,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _green, width: 2),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 5))],
                  ),
                  child: Column(children: [
                    const Text('Sizin Yeriniz', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('$score / $label', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _navy, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: stemLeft,
              top: -43,
              child: Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [BoxShadow(color: Color(0x22008A55), blurRadius: 6)],
                ),
              ),
            ),
            Positioned(
              left: arrowLeft,
              top: -18,
              child: const Icon(Icons.arrow_drop_down, size: 22, color: _green),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Findeks notu bu kiralama başvurusu için olumlu aralıktadır.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]);
      }),
    );
  }

  Widget _rentEvaluation() {
    final amount = _applicationAmount();
    final capacity = _capacityIndicator();
    if (amount == null && capacity == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(_isCarRental ? 'Kiralama Tutarı Değerlendirmesi' : 'Kira Tutarı Değerlendirmesi'),
      _sectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _inlineData(_isCarRental ? 'Beyan edilen kiralama tutarı' : 'Beyan edilen kira tutarı', _formatTl(amount))),
            const SizedBox(width: 10),
            Expanded(child: _inlineData('Finansal kapasite göstergesi', _formatTl(capacity))),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_rounded, color: _green, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('${_rentAlignmentLabel()}: ${_profileComment('rent_alignment', '$_amountSubject, raporda görülen finansal kapasite göstergeleriyle uyumlu görünmektedir.')}', style: const TextStyle(height: 1.35, fontWeight: FontWeight.w700, color: Color(0xFF075E47)))),
          ]),
        ]),
      ),
    ]);
  }

  Widget _inlineData(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
      ]),
    );
  }

  Widget _financialSummary() {
    final institutionCount = financialSummary['institution_count'] ?? displayMetrics['institution_count'];
    final totalLimits = financialSummary['total_limits'] ?? displayMetrics['total_limits'];
    final totalDebts = financialSummary['total_debts'] ?? displayMetrics['total_debts'];
    final capacity = _capacityIndicator();

    if (institutionCount == null && totalLimits == null && totalDebts == null && capacity == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Finansal Özet Göstergeleri'),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          _summaryTile(_SummaryItem(Icons.account_balance_outlined, 'Kredi Veren Kurum Sayısı', _formatValue(institutionCount))),
          _summaryTile(_SummaryItem(Icons.account_balance_wallet_outlined, 'Toplam Finansal Limit', _formatTl(totalLimits))),
          _summaryTile(_SummaryItem(Icons.credit_card_outlined, 'Toplam Mevcut Borç', _formatTl(totalDebts))),
          _summaryTile(_SummaryItem(Icons.trending_up_rounded, 'Finansal Kapasite Göstergesi', _formatTl(capacity))),
        ],
      ),
    ]);
  }

  Widget _verification() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Rapor Doğrulama'),
      _sectionCard(
        child: const Column(children: [
          _VerificationRow(icon: Icons.verified_user_outlined, text: 'Rapor sahibi doğrulandı'),
          _VerificationRow(icon: Icons.event_available_outlined, text: 'Rapor güncel'),
          _VerificationRow(icon: Icons.person_search_outlined, text: 'Başvuru bilgileriyle uyumlu'),
          _VerificationRow(icon: Icons.picture_as_pdf_outlined, text: 'PDF format kontrolü yapıldı'),
        ]),
      ),
    ]);
  }

  Widget _disclaimer() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF7F9FC), border: Border.all(color: _border), borderRadius: BorderRadius.circular(16)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Önemli Bilgilendirme', style: TextStyle(fontWeight: FontWeight.w900, color: _navy)),
        SizedBox(height: 6),
        Text(
          'Bu rapor, başvuru sahibinin kendi rızasıyla yüklediği Findeks risk raporu ve beyan ettiği kira tutarı esas alınarak oluşturulmuş otomatik bir finansal ön değerlendirmedir. Garanti, kefalet veya ödeme taahhüdü içermez. Kiralama kararının nihai takdiri kiraya veren kişi veya kuruma aittir.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
        ),
      ]),
    );
  }

  Widget _negativeResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF4C76A)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFFFF7E6), shape: BoxShape.circle), child: const Icon(Icons.fact_check_outlined, size: 40, color: Color(0xFFD46A1F)))),
        const SizedBox(height: 16),
        Center(child: Text(_negativeTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _navy))),
        const SizedBox(height: 6),
        const Center(child: Text('Bu başvuru için olumlu sonuç oluşmadı', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF334155)))),
        const SizedBox(height: 14),
        const Text('Rapor başarıyla incelendi. Ancak mevcut finansal göstergeler ve beyan edilen tutar dikkate alındığında paylaşılabilir olumlu sonuç oluşmamıştır.', style: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFF8FBFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)), child: const Text('Bu sonuç teknik bir hata değildir. Değerlendirme, yüklenen rapordaki veriler ve beyan edilen tutar üzerinden otomatik olarak yapılmıştır.', style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF334155), fontWeight: FontWeight.w700))),
        _disclaimer(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (errorMessage != null) {
      return Scaffold(appBar: AppBar(title: const Text('Sonuç')), body: SafeArea(minimum: const EdgeInsets.all(14), child: Center(child: Text(errorMessage!, textAlign: TextAlign.center))));
    }

    if (_isPositive && fullReportLocked && !paymentCompleted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sonuç')),
        body: Stack(
          children: [
            SafeArea(
              minimum: const EdgeInsets.all(14),
              child: ListView(
                children: [
                  _lockedPositiveReport(),
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: paymentProcessing ? null : () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PurposeScreen()), (_) => false),
                    child: const Text('Ana Sayfaya Dön'),
                  ),
                ],
              ),
            ),
            if (paymentProcessing) _paymentProcessingOverlay(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sonuç')),
      body: SafeArea(
        minimum: const EdgeInsets.all(14),
        child: ListView(children: [
          if (_isPositive) ...[
            _heroCard(locked: false),
            const SizedBox(height: 28),
            _applicantIdentityCard(),
            const SizedBox(height: 28),
            _quickSummaryCards(),
            const SizedBox(height: 28),
            _positiveReasons(),
            const SizedBox(height: 32),
            _findeksIndicators(),
            const SizedBox(height: 32),
            _categoryProfile(),
            const SizedBox(height: 32),
            _rentEvaluation(),
            const SizedBox(height: 32),
            _financialSummary(),
            const SizedBox(height: 32),
            _verification(),
            const SizedBox(height: 28),
            _disclaimer(),
            const SizedBox(height: 20),
            PrimaryButton(text: 'Paylaşım Linki Oluştur', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareScreen()))),
            const SizedBox(height: 10),
          ] else ...[
            _negativeResult(),
            const SizedBox(height: 20),
          ],
          OutlinedButton(
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PurposeScreen()), (_) => false),
            child: const Text('Ana Sayfaya Dön'),
          ),
        ]),
      ),
    );
  }
}

class _CategoryOption {
  final String label;
  final bool warning;
  const _CategoryOption(this.label, {this.warning = false});
}

class _SummaryItem {
  final IconData icon;
  final String title;
  final String value;
  _SummaryItem(this.icon, this.title, this.value);
}

class _Band extends StatelessWidget {
  final String label;
  final Color color;
  const _Band({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 38,
        alignment: Alignment.center,
        color: color,
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _VerificationRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, color: _ResultScreenState._green, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
