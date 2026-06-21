class UrlValidator {
  UrlValidator._();

  static bool isValid(String? url) => normalize(url) != null;

  /// Clean base URL: scheme://host[:port][/path], no trailing slash, no query,
  /// no fragment — or null when input is not a valid http(s) URL with a host.
  ///
  /// Permissive: any http/https host is accepted (local, public, VPN/Tailscale).
  /// Mirrors the original Android UrlValidator behaviour.
  static String? normalize(String? url) {
    if (url == null) return null;
    Uri uri;
    try {
      uri = Uri.parse(url.trim());
    } on FormatException {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    final host = uri.host;
    if (host.isEmpty) return null;

    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) return null;

    final base = StringBuffer('$scheme://$host');
    final port = uri.port;
    final isDefaultPort =
        (scheme == 'http' && port == 80) || (scheme == 'https' && port == 443);
    if (port != 0 && !isDefaultPort) {
      base.write(':$port');
    }

    var path = uri.path;
    if (path.isNotEmpty && path != '/') {
      while (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      if (path.isNotEmpty) base.write(path);
    }
    return base.toString();
  }
}
