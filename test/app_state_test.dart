import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trailmark/app_state.dart';
import 'package:trailmark/core/models.dart';
import 'package:trailmark/services/backend.dart';
import 'package:trailmark/services/fake_backend.dart';
import 'package:trailmark/services/key_value_store.dart';
import 'package:trailmark/services/location_source.dart';
import 'package:trailmark/services/sos_message.dart';
import 'package:trailmark/services/station_finder.dart';

class RecordingLauncher implements Launcher {
  final smsSent = <String>[];
  @override
  Future<bool> sms(List<EmergencyContact> to, String body) async {
    smsSent.add('${to.map((c) => c.phone).join(',')}|$body');
    return true;
  }

  @override
  Future<bool> call(String number) async => true;
  @override
  Future<bool> directions(double lat, double lon) async => true;
}

/// A backend that is "offline" until [up] is set.
class FlakyBackend extends FakeBackend {
  bool up = false;
  @override
  Future<Incident> createIncident({
    required Hiker victim,
    String note = '',
  }) {
    if (!up) throw StateError('no signal');
    return super.createIncident(victim: victim, note: note);
  }
}

Future<AppState> phone(
  Backend b,
  String name,
  double lat, {
  Launcher? launcher,
  http.Client? http,
  KeyValueStore? kv,
}) async {
  final app = AppState(
    backend: b,
    kv: kv ?? MemoryKv(),
    location: FixedLocation(lat, 0, 1),
    stations: StationFinder(
      client: http ?? MockClient((_) async => httpOk('{"elements":[]}')),
    ),
    launcher: launcher ?? RecordingLauncher(),
    now: () => 1000,
  );
  await app.load();
  await app.saveProfile(
    name: name,
    country: 'IL',
    contacts: const [EmergencyContact('Mum', '+972500')],
  );
  return app;
}

http.Response httpOk(String body) => http.Response(body, 200);

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('SOS reaches a nearby hiker, who helps and chats; victim resolves',
      () async {
    final server = FakeBackend(now: () => 1000);
    final sms = RecordingLauncher();
    final victim = await phone(server, 'Soe', 0, launcher: sms);
    final helper = await phone(server, 'Dana', 0.004); // ~440 m away
    await helper.setVisible(true);
    await victim.setVisible(true);
    await helper.refresh();
    expect(helper.nearby.map((h) => h.name), ['Soe']);

    await victim.sendSos(note: 'twisted ankle');
    await tick();
    expect(victim.mySos!.id, 'i1');
    expect(sms.smsSent.single, contains('SOS from Soe. twisted ankle.'));
    expect(sms.smsSent.single, startsWith('+972500|'));
    expect(helper.incidents.single.victimName, 'Soe');
    expect(victim.incidents, isEmpty); // you do not see your own SOS as one to answer

    await helper.iCanHelp(helper.incidents.single);
    await tick();
    final msgs = await server.watchMessages('i1').first;
    expect(msgs.single.text, 'On my way. I can help.');
    expect(msgs.single.senderName, 'Dana');

    await victim.resolveMySos();
    await tick();
    expect(helper.incidents, isEmpty);
    expect(victim.mySos, isNull);
  });

  test('hiker outside the radius is not alerted', () async {
    final server = FakeBackend(now: () => 1000);
    final victim = await phone(server, 'Soe', 0);
    final far = await phone(server, 'Far', 1.0); // ~111 km
    await far.setVisible(true);
    await victim.setVisible(true);
    await victim.sendSos();
    await tick();
    expect(far.incidents, isEmpty);
  });

  test('SOS with no signal still texts contacts and retries the upload',
      () async {
    final server = FlakyBackend();
    final sms = RecordingLauncher();
    final victim = await phone(server, 'Soe', 0, launcher: sms);
    await victim.updateLocation();
    await victim.sendSos(note: 'lost');
    expect(sms.smsSent, hasLength(1)); // contacts are told regardless
    expect(victim.sosUploadPending, isTrue);
    expect(victim.mySos!.id, 'pending');

    server.up = true; // signal returns
    await victim.refresh();
    expect(victim.sosUploadPending, isFalse);
    expect(victim.mySos!.id, 'i1');
  });

  test('location denied is reported, not thrown', () async {
    final app = AppState(
      backend: FakeBackend(),
      kv: MemoryKv(),
      location: _Denied(),
      stations: StationFinder(client: MockClient((_) async => httpOk('{}'))),
      launcher: RecordingLauncher(),
    );
    await app.load();
    await app.setVisible(true);
    expect(app.visible, isFalse);
    expect(app.locationError, contains('Location is off'));
  });

  test('stations: loaded online, then served from cache when offline',
      () async {
    final kv = MemoryKv();
    final body = jsonEncode({
      'elements': [
        {
          'type': 'node', 'lat': 0.005, 'lon': 0.0,
          'tags': {'amenity': 'police', 'name': 'Central Police', 'phone': '100'},
        },
      ],
    });
    final online = await phone(
      FakeBackend(),
      'Soe',
      0,
      kv: kv,
      http: MockClient((_) async => httpOk(body)),
    );
    await online.loadStations();
    expect(online.helpStations.single.name, 'Central Police');
    expect(online.stationsNote, isNull);

    final offline = await phone(
      FakeBackend(),
      'Soe',
      0,
      kv: kv,
      http: MockClient((_) async => throw StateError('no network')),
    );
    await offline.loadStations();
    expect(offline.helpStations.single.name, 'Central Police');
    expect(offline.helpStations.single.phone, '100');
    expect(offline.stationsNote, contains('saved results'));
  });
}

class _Denied implements LocationSource {
  @override
  Future<Fix> current() => throw LocationDenied();
}
