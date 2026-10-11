import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/geo.dart';
import '../core/models.dart';

/// Finds police, ranger stations, hospitals, fire stations and mountain rescue
/// near a point, using OpenStreetMap data through the Overpass API.
class StationFinder {
  final http.Client _client;
  final String endpoint;
  StationFinder({http.Client? client, this.endpoint = 'https://overpass-api.de/api/interpreter'})
    : _client = client ?? http.Client();

  static String query(double lat, double lon, int radiusM) {
    final around = '(around:$radiusM,$lat,$lon)';
    return '[out:json][timeout:20];('
        'nwr["amenity"="police"]$around;'
        'nwr["amenity"="ranger_station"]$around;'
        'nwr["amenity"="hospital"]$around;'
        'nwr["amenity"="fire_station"]$around;'
        'nwr["emergency"="mountain_rescue"]$around;'
        ');out center tags;';
  }

  Future<List<HelpStation>> near(
    double lat,
    double lon, {
    int radiusM = 30000,
    int limit = 12,
  }) async {
    final res = await _client
        .post(Uri.parse(endpoint), body: {'data': query(lat, lon, radiusM)})
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw StateError('Station lookup failed (${res.statusCode})');
    }
    return parse(res.body, lat, lon, limit: limit);
  }

  /// Pure, so it can be tested against saved responses.
  static List<HelpStation> parse(
    String body,
    double lat,
    double lon, {
    int limit = 12,
  }) {
    final out = <HelpStation>[];
    for (final e in (jsonDecode(body)['elements'] as List)) {
      final m = e as Map<String, dynamic>;
      final tags = Map<String, dynamic>.from(m['tags'] as Map? ?? const {});
      final c = m['center'] as Map<String, dynamic>?;
      final la = (m['lat'] ?? c?['lat']) as num?;
      final lo = (m['lon'] ?? c?['lon']) as num?;
      final kind = _kind(tags);
      if (la == null || lo == null || kind == null) continue;
      final phone = (tags['phone'] ??
              tags['contact:phone'] ??
              tags['emergency:phone']) as String?;
      out.add(
        HelpStation(
          name: (tags['name:en'] ?? tags['name'] ?? _label(kind)) as String,
          kind: kind,
          lat: la.toDouble(),
          lon: lo.toDouble(),
          phone: phone?.split(';').first.trim(),
        ).withDistance(distanceM(lat, lon, la.toDouble(), lo.toDouble())),
      );
    }
    out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return out.take(limit).toList();
  }

  static StationKind? _kind(Map<String, dynamic> t) {
    if (t['emergency'] == 'mountain_rescue') return StationKind.mountainRescue;
    return switch (t['amenity']) {
      'police' => StationKind.police,
      'ranger_station' => StationKind.ranger,
      'hospital' => StationKind.hospital,
      'fire_station' => StationKind.fire,
      _ => null,
    };
  }

  static String _label(StationKind k) => switch (k) {
    StationKind.police => 'Police station',
    StationKind.ranger => 'Ranger station',
    StationKind.hospital => 'Hospital',
    StationKind.fire => 'Fire station',
    StationKind.mountainRescue => 'Mountain rescue',
  };
}
