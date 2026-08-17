String? b2bReferralTokenFromUri(Uri uri) {
  if (uri.scheme == 'kiralayabilirmiyim' && uri.host == 'b2b-referral') {
    final token = uri.queryParameters['token']?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  if (uri.scheme == 'https' &&
      uri.host == 'kiralayabilirmiyim.com' &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'basvuru') {
    final token = uri.pathSegments[1].trim();
    return token.isEmpty ? null : token;
  }

  return null;
}
