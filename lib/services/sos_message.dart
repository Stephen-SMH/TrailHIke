import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';

/// The text sent to the hiker's own emergency contacts with an SOS.
String sosMessage({
  required String name,
  required double lat,
  required double lon,
  String note = '',
}) {
  final la = lat.toStringAsFixed(5), lo = lon.toStringAsFixed(5);
  return 'SOS from $name.'
      '${note.isEmpty ? '' : ' $note.'}'
      ' Position: $la, $lo '
      'https://www.openstreetmap.org/?mlat=$la&mlon=$lo#map=16/$la/$lo'
      ' Please call local emergency services if you cannot reach them.';
}

/// Opens an action outside the app (SMS composer, phone dialer, maps).
/// Behind an interface so tests can record what would have happened.
abstract class Launcher {
  Future<bool> sms(List<EmergencyContact> to, String body);
  Future<bool> call(String number);
  Future<bool> directions(double lat, double lon);
}

class PhoneLauncher implements Launcher {
  @override
  Future<bool> sms(List<EmergencyContact> to, String body) => launchUrl(
    Uri(
      scheme: 'sms',
      path: to.map((c) => c.phone).join(','),
      queryParameters: {'body': body},
    ),
  );

  @override
  Future<bool> call(String number) =>
      launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));

  @override
  Future<bool> directions(double lat, double lon) => launchUrl(
    Uri.parse('https://www.openstreetmap.org/directions?to=$lat%2C$lon'),
    mode: LaunchMode.externalApplication,
  );
}
