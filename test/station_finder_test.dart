import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailmark/core/emergency_numbers.dart';
import 'package:trailmark/core/geo.dart';
import 'package:trailmark/core/models.dart';
import 'package:trailmark/services/station_finder.dart';

final sample = jsonEncode({
  'elements': [
    {
      'type': 'node', 'lat': 0.02, 'lon': 0.0,
      'tags': {'amenity': 'hospital', 'name': 'Far Hospital'},
    },
    {
      'type': 'way', 'center': {'lat': 0.005, 'lon': 0.0},
      'tags': {
        'amenity': 'police', 'name': 'Ban Police', 'name:en': 'Ban Police Station',
        'phone': '+66 53 123 456; +66 53 999 999',
      },
    },
    {
      'type': 'node', 'lat': 0.01, 'lon': 0.0,
      'tags': {'amenity': 'ranger_station'},
    },
    {'type': 'node', 'lat': 0.001, 'lon': 0.0, 'tags': {'amenity': 'cafe'}},
    {'type': 'node', 'tags': {'amenity': 'police'}}, // no position: skipped
  ],
});

void main() {
  test('parses, sorts nearest first, prefers English name, first phone', () {
    final r = StationFinder.parse(sample, 0, 0);
    expect(r.map((s) => s.name), [
      'Ban Police Station',
      'Ranger station', // no name tag: fallback label
      'Far Hospital',
    ]);
    expect(r.first.kind, StationKind.police);
    expect(r.first.phone, '+66 53 123 456');
    expect(r.first.distanceM, closeTo(556, 5));
  });

  test('limit is applied', () {
    expect(StationFinder.parse(sample, 0, 0, limit: 1), hasLength(1));
  });

  test('query asks for the right things', () {
    final q = StationFinder.query(18.5, 98.4, 30000);
    expect(q, contains('"amenity"="police"'));
    expect(q, contains('"emergency"="mountain_rescue"'));
    expect(q, contains('around:30000,18.5,98.4'));
  });

  test('emergency numbers: known country and fallback', () {
    expect(numbersFor('il').police, '100');
    expect(numbersFor('TH').ambulance, '1669');
    expect(numbersFor('ZZ').police, '112');
    expect(numbersFor(null).country, 'Unknown country');
  });

  test('geo helpers', () {
    expect(distanceM(0, 0, 1, 0), closeTo(111195, 200));
    expect(compass(0, 0, 1, 0), 'N');
    expect(compass(0, 0, 0, 1), 'E');
    expect(formatDistance(850), '850 m');
    expect(formatDistance(2350), '2.4 km');
  });
}
