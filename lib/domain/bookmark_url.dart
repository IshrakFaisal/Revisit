final class BookmarkUrl {
  const BookmarkUrl._(this.originalText, this.canonicalKey, this.host);

  factory BookmarkUrl.parse(String input) {
    final text = input.trim();
    if (text.isEmpty) throw const FormatException('Enter a URL.');
    if (text.length > 4096) {
      throw const FormatException('Enter a URL of at most 4,096 characters.');
    }
    if (_invalidCharacter.hasMatch(text)) {
      throw const FormatException('Remove spaces or invalid URL characters.');
    }
    if (_invalidEscape.hasMatch(text)) {
      throw const FormatException('Check the URL’s percent encoding.');
    }

    final address = _address.firstMatch(text);
    if (address == null) {
      throw const FormatException(
        'Enter a full URL starting with http:// or https://.',
      );
    }
    final authority = address[2]!;
    if (authority.contains('@')) {
      throw const FormatException('Remove credentials from the URL.');
    }
    final hostAndPort = _hostAndPort.firstMatch(authority);
    if (hostAndPort == null) {
      throw const FormatException('Check the URL’s host and port.');
    }
    final host = hostAndPort[1]!.toLowerCase();
    if (!_validHost(host)) {
      throw const FormatException('Enter a valid host name or IP address.');
    }
    final portText = hostAndPort[2];
    final port = portText == null ? null : int.tryParse(portText);
    if (portText != null && (port == null || port < 1 || port > 65535)) {
      throw const FormatException('Enter a port from 1 to 65535.');
    }

    final scheme = address[1]!.toLowerCase();
    final defaultPort = scheme == 'https' ? 443 : 80;
    final portSuffix = port == null || port == defaultPort ? '' : ':$port';
    final resource = text.substring(address.end);
    final root = resource.startsWith('/') ? '' : '/';
    // Uri serialization can remove dot segments and change escaped bytes.
    // Keep the resource as entered, including any empty query or fragment.
    return BookmarkUrl._(
      text,
      '$scheme://$host$portSuffix$root$resource',
      host,
    );
  }

  final String originalText;
  final String canonicalKey;
  final String host;

  static final _invalidCharacter = RegExp(
    r'[\s\u0000-\u001F\u007F-\u009F<>"{}|^`\\]',
  );
  static final _invalidEscape = RegExp(r'%(?![0-9A-Fa-f]{2})');
  static final _address = RegExp(
    r'^(https?)://([^/?#]*)',
    caseSensitive: false,
  );
  static final _hostAndPort = RegExp(
    r'^(\[[0-9A-Fa-f:.]+\]|[A-Za-z0-9.-]+)(?::([0-9]+))?$',
  );
  static final _hostLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  static final _numericLabel = RegExp(r'^(?:[0-9]+|0x[0-9a-f]*)$');
  static final _ipv4Octet = RegExp(r'^(?:0|[1-9][0-9]{0,2})$');

  static bool _validHost(String host) {
    if (host.startsWith('[')) {
      try {
        Uri.parseIPv6Address(host.substring(1, host.length - 1));
        return true;
      } on FormatException {
        return false;
      }
    }
    final name = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
    if (name.length > 253) return false;
    final labels = name.split('.');
    if (!labels.every(_hostLabel.hasMatch)) return false;
    // Browsers can reinterpret a numeric final label as an IPv4 address.
    // Require its unambiguous dotted-decimal form.
    if (_numericLabel.hasMatch(labels.last)) {
      return labels.length == 4 &&
          labels.every(
            (label) => _ipv4Octet.hasMatch(label) && int.parse(label) <= 255,
          );
    }
    return true;
  }
}
