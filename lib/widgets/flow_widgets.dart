import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlowColors {
  static const Color navy = Color(0xFF102E54);
  static const Color navyDark = Color(0xFF0B2545);
  static const Color teal = Color(0xFF0B8F87);
  static const Color green = Color(0xFF108A56);
  static const Color bg = Color(0xFFF4F8FC);
  static const Color border = Color(0xFFDCE5EF);
  static const Color muted = Color(0xFF64748B);
  static const Color softGreen = Color(0xFFE9F8F3);
  static const Color amberBg = Color(0xFFFFF7E6);
  static const Color amberBorder = Color(0xFFF4C76A);
}

class FlowScaffold extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Widget? bottom;
  final bool showBack;
  final EdgeInsets padding;
  final ScrollController? scrollController;

  const FlowScaffold({
    super.key,
    this.title,
    required this.children,
    this.bottom,
    this.showBack = true,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final scrollPadding = padding.copyWith(
      // Alt CTA butonu klavye açıkken de ekranda kalır. Listeye ekstra alt boşluk
      // vererek aktif input ve güven notu butonun altında kaybolmasın.
      bottom: padding.bottom + (bottom == null ? 24 : (keyboardOpen ? 120 : 110)),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: title == null && !showBack ? null : AppBar(title: title == null ? null : Text(title!), automaticallyImplyLeading: showBack),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            controller: scrollController,
            padding: scrollPadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.96),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, -4)),
                    ],
                  ),
                  child: bottom!,
                ),
              ),
            ),
    );
  }
}


String turkishUpper(String value) {
  return value
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ü', 'Ü')
      .replaceAll('ş', 'Ş')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .toUpperCase();
}

class FlowHeader extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final InlineSpan? richSubtitle;

  const FlowHeader({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.richSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFF073B4D), Color(0xFF123C69), Color(0xFF0B2545)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 58, height: 58, decoration: const BoxDecoration(color: FlowColors.softGreen, shape: BoxShape.circle), child: Icon(icon, color: FlowColors.green, size: 32)),
        const SizedBox(height: 16),
        Text(turkishUpper(eyebrow), style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 27, height: 1.06, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
        const SizedBox(height: 10),
        if (richSubtitle == null)
          Text(subtitle, style: const TextStyle(color: Color(0xFFE6F4F1), fontSize: 15.5, height: 1.38, fontWeight: FontWeight.w600))
        else
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFFE6F4F1), fontSize: 15.5, height: 1.38, fontWeight: FontWeight.w600),
              children: [richSubtitle!],
            ),
          ),
      ]),
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color background;
  final Color borderColor;
  final VoidCallback? onTap;
  const PremiumCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.background = Colors.white, this.borderColor = FlowColors.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: card);
  }
}

class TrustNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color borderColor;
  final Color iconColor;
  const TrustNotice({super.key, required this.icon, required this.text, this.background = FlowColors.softGreen, this.borderColor = const Color(0xFFBFE8DD), this.iconColor = FlowColors.green});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(18)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.38, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
      ]),
    );
  }
}

class FlowTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  const FlowTextField({super.key, required this.controller, required this.label, this.helper, this.keyboardType, this.maxLength, this.obscureText = false, this.textCapitalization = TextCapitalization.none, this.inputFormatters, this.prefixText});
  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      // Klavye + sabit CTA butonu kadar alan bırakır; böylece alan odaklanınca
      // otomatik kaydırma tüm form ekranlarında daha güvenilir çalışır.
      scrollPadding: EdgeInsets.only(bottom: keyboardBottom + 150),
      decoration: InputDecoration(labelText: label, helperText: helper, counterText: maxLength == null ? null : '', prefixText: prefixText),
    );
  }
}

class FlowStepList extends StatelessWidget {
  final List<String> items;
  final int activeIndex;
  const FlowStepList({super.key, required this.items, required this.activeIndex});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (i) {
        final active = i <= activeIndex;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? FlowColors.green : const Color(0xFFE2E8F0)), child: Icon(active ? Icons.check_rounded : Icons.more_horiz, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(items[i], style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w700, color: active ? FlowColors.navyDark : FlowColors.muted))),
          ]),
        );
      }),
    );
  }
}
