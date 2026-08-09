/// Shared URL / text helpers for share, clipboard, and SMS flows.
abstract final class LinkExtractor {
  static final RegExp _urlPattern = RegExp(
    r'''(?:https?:\/\/|www\.)[^\s<>"')\]]+|https?:\/\/[^\s<>"')\]]+''',
    caseSensitive: false,
  );

  /// Returns the first URL found in [text], normalized with https if needed.
  static String? firstUrl(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (_looksLikeBareUrl(trimmed)) {
      return normalizeUrl(trimmed);
    }

    final match = _urlPattern.firstMatch(trimmed);
    if (match == null) return null;
    return normalizeUrl(match.group(0)!);
  }

  static List<String> allUrls(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final found = <String>{};
    for (final match in _urlPattern.allMatches(text)) {
      final url = normalizeUrl(match.group(0)!);
      if (url != null) found.add(url);
    }
    if (found.isEmpty && _looksLikeBareUrl(text.trim())) {
      final url = normalizeUrl(text.trim());
      if (url != null) found.add(url);
    }
    return found.toList();
  }

  static String? normalizeUrl(String raw) {
    var value = raw.trim();
    // Strip trailing punctuation often copied from messages.
    while (value.isNotEmpty && '.,;:!?)】》"\''.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) return null;
    if (value.startsWith('www.')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'safelink')) {
      return value;
    }
    if (!uri.hasScheme && value.contains('.') && !value.contains(' ')) {
      return 'https://$value';
    }
    return null;
  }

  static bool _looksLikeBareUrl(String text) {
    if (text.contains(' ') || text.contains('\n')) return false;
    final lower = text.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.')) {
      return true;
    }
    // domain.tld or domain.tld/path without spaces
    return RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[^\s]*)?$').hasMatch(text);
  }

  static bool isPasteCheckUri(Uri uri) {
    return uri.scheme == 'safelink' && uri.host == 'paste-check';
  }
}
