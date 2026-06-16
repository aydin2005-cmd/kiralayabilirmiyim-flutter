import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'screens/analysis_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/app_state.dart';
import 'services/payment_flow.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const KiralayabilirMiyimApp());
}

class KiralayabilirMiyimApp extends StatefulWidget {
  const KiralayabilirMiyimApp({super.key});

  @override
  State<KiralayabilirMiyimApp> createState() => _KiralayabilirMiyimAppState();
}

class _KiralayabilirMiyimAppState extends State<KiralayabilirMiyimApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ApiClient _api = ApiClient();
  StreamSubscription<Uri>? _linkSub;
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleDeepLink(initial);
      }
    } catch (_) {
      // Deep link support is best-effort; manual payment status check remains available.
    }
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (_) {},
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'kiralayabilirmiyim' || uri.host != 'payment-result')
      return;
    final appId = uri.queryParameters['application_id'];
    if (appId != null && appId.isNotEmpty) {
      AppState.instance.applicationId = appId;
    }

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ödeme durumunuz kontrol ediliyor...')),
    );

    try {
      var paid = false;
      for (var i = 0; i < 5; i++) {
        try {
          paid = await PaymentFlow.checkCurrentStatus(api: _api);
          if (paid) break;
        } catch (e) {
          final text = e.toString().toLowerCase();
          if (!text.contains('clientexception') &&
              !text.contains('socketexception') &&
              !text.contains('connection') &&
              !text.contains('timed out')) {
            rethrow;
          }
        }
        await Future.delayed(const Duration(milliseconds: 900));
      }
      if (!paid) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Ödeme sonucu henüz ulaşmadı. Kısa süre sonra tekrar kontrol edin.')),
        );
        return;
      }
      if (!context.mounted) return;
      if (!AppState.instance.markPaymentSuccessHandled()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödeme başarılı. Tam rapor açılıyor.')),
      );
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AnalysisScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      final text = e.toString();
      final friendly = text.toLowerCase().contains('clientexception') ||
              text.toLowerCase().contains('socketexception')
          ? 'Ödeme sonucu kontrol ediliyor. Lütfen birkaç saniye sonra tekrar deneyiniz.'
          : text;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendly)));
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Kiralayabilir Miyim?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
