import 'package:revisit/domain/bookmark_url.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<bool> openExternalLink(String value) {
  final url = BookmarkUrl.parse(value).originalText;
  final colon = url.indexOf(':');
  // Android matches intent schemes case-sensitively. Keep the resource intact.
  final launchTarget =
      url.substring(0, colon).toLowerCase() + url.substring(colon);
  return launchUrlString(launchTarget, mode: LaunchMode.externalApplication);
}
