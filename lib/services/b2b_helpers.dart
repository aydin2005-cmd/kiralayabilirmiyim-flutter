import 'package:flutter/services.dart';

String? normalizeTurkeyMobile(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('90') && digits.length == 12) {
    digits = digits.substring(2);
  }

  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }

  if (!RegExp(r'^5\d{9}$').hasMatch(digits)) {
    return null;
  }

  return '+90$digits';
}

String turkeyMobileFieldDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('90') && digits.length >= 12) {
    digits = digits.substring(2);
  }

  if (digits.startsWith('0') && digits.length >= 11) {
    digits = digits.substring(1);
  }

  if (digits.isNotEmpty && !digits.startsWith('5')) {
    return '';
  }

  if (digits.length > 10) {
    digits = digits.substring(0, 10);
  }

  return digits;
}

class TurkeyMobileFieldFormatter extends TextInputFormatter {
  const TurkeyMobileFieldFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = turkeyMobileFieldDigits(newValue.text);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

String b2bRoleLabel(String? role) {
  switch (role) {
    case 'owner':
      return 'Firma Sahibi';
    case 'admin':
      return 'Yönetici';
    case 'operator':
      return 'Operatör';
    case 'viewer':
      return 'Görüntüleyici';
    default:
      return role ?? '-';
  }
}

String b2bStatusLabel(String? status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'invited':
      return 'Davetli';
    case 'disabled':
      return 'Devre Dışı';
    case 'awaiting_activation':
      return 'Aktivasyon Bekliyor';
    case 'pending_payment':
      return 'Ödeme Bekliyor';
    case 'paid':
      return 'Ödendi';
    case 'pending':
      return 'Bekliyor';
    case 'failed':
      return 'Başarısız';
    case 'cancelled':
      return 'İptal Edildi';
    case 'refunded':
      return 'İade Edildi';
    case 'exhausted':
      return 'Tükendi';
    case 'expired':
      return 'Süresi Doldu';
    default:
      return status ?? '-';
  }
}

String moneyText(dynamic amount, [String currency = 'TL']) {
  final value = amount is num ? amount.toDouble() : double.tryParse('$amount');
  if (value == null) {
    return '-';
  }
  return '${value.toStringAsFixed(2)} $currency';
}

String shortDate(dynamic raw) {
  if (raw == null) {
    return '-';
  }

  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) {
    return raw.toString();
  }

  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');

  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
