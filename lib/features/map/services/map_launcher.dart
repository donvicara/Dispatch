import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  static Future<void> launchNavigation(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final fallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
      return;
    }
  }

  static Future<bool> tryLaunchNavigation(
    double lat,
    double lng, {
    required Function() onFailure,
  }) async {
    final googleUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final browserUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      return true;
    }
    if (await canLaunchUrl(browserUrl)) {
      await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
      return true;
    }
    onFailure();
    return false;
  }
}
