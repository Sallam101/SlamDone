import 'package:url_launcher/url_launcher.dart';

abstract final class SupportLinks {
  static final Uri patreon = Uri.parse(
    'https://www.patreon.com/Sallam101/posts/buy-sallam-167511433?utm_medium=clipboard_copy&utm_source=copyLink&utm_campaign=postshare_creator&utm_content=join_link',
  );

  static Future<bool> openPatreon() => launchUrl(
        patreon,
        webOnlyWindowName: '_blank',
      );
}
