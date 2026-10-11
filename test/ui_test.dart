import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trailmark/app_state.dart';
import 'package:trailmark/core/models.dart';
import 'package:trailmark/services/fake_backend.dart';
import 'package:trailmark/services/key_value_store.dart';
import 'package:trailmark/services/location_source.dart';
import 'package:trailmark/services/sos_message.dart';
import 'package:trailmark/services/station_finder.dart';
import 'package:trailmark/ui/shell.dart';
import 'package:trailmark/ui/theme.dart';

class _Launcher implements Launcher {
  final calls = <String>[];
  @override
  Future<bool> sms(List<EmergencyContact> to, String body) async {
    calls.add('sms:$body');
    return true;
  }

  @override
  Future<bool> call(String n) async {
    calls.add('call:$n');
    return true;
  }

  @override
  Future<bool> directions(double lat, double lon) async => true;
}

const _stations =
    '{"elements":[{"type":"node","lat":0.005,"lon":0.0,'
    '"tags":{"amenity":"police","name":"Central Police","phone":"100"}}]}';

Future<(AppState, _Launcher, FakeBackend)> boot({bool profile = true}) async {
  final backend = FakeBackend()..seedDemoHikers(0, 0);
  final launcher = _Launcher();
  final app = AppState(
    backend: backend,
    kv: MemoryKv(),
    location: FixedLocation(0, 0, 1),
    stations: StationFinder(
      client: MockClient((_) async => http.Response(_stations, 200)),
    ),
    launcher: launcher,
  );
  await app.load();
  if (profile) {
    await app.saveProfile(
      name: 'Soe',
      country: 'IL',
      contacts: const [EmergencyContact('Mum', '+972500')],
    );
  }
  return (app, launcher, backend);
}

Widget host(AppState app) => MaterialApp(theme: DS.dark(), home: Shell(app));

void main() {
  testWidgets('new user lands on Me and must enter a name', (t) async {
    final (app, _, _) = await boot(profile: false);
    await t.pumpWidget(host(app));
    expect(find.text('Your name'), findsOneWidget);
    await t.tap(find.text('Save'));
    await t.pump();
    expect(find.text('Please enter your name'), findsOneWidget);
    expect(app.hasProfile, isFalse);
  });

  testWidgets('Help tab: numbers, stations, call button, SOS flow', (t) async {
    final (app, launcher, _) = await boot();
    await t.pumpWidget(host(app));
    await t.pumpAndSettle();

    expect(find.textContaining('ISRAEL'), findsOneWidget);
    expect(find.text('Police  100'), findsOneWidget);
    expect(find.text('Central Police'), findsOneWidget); // from OSM data
    expect(find.text('SOS'), findsOneWidget);

    await t.tap(find.text('Ambulance  101'));
    expect(launcher.calls, contains('call:101'));

    await t.tap(find.text('SOS'));
    await t.pumpAndSettle();
    expect(find.text('Send SOS?'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'twisted ankle');
    await t.tap(find.text('Send SOS'));
    await t.pumpAndSettle();

    expect(find.text('SOS is active'), findsOneWidget);
    expect(launcher.calls.last, contains('SOS from Soe. twisted ankle.'));
    expect(find.text("I'm safe - end SOS"), findsOneWidget);

    await t.tap(find.text("I'm safe - end SOS"));
    await t.pumpAndSettle();
    expect(find.text('SOS is active'), findsNothing);
  });

  testWidgets('Nearby tab: go visible, see hikers, answer an SOS', (t) async {
    final (app, _, backend) = await boot();
    await t.pumpWidget(host(app));
    await t.tap(find.text('Nearby'));
    await t.pumpAndSettle();
    expect(find.text('Turn on the switch above to see who is around.'),
        findsOneWidget);

    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('Dana'), findsOneWidget); // simulated hiker ~500 m away
    expect(find.textContaining('under 500 m'), findsOneWidget); // exact spot hidden
    // Someone else sends an SOS nearby.
    await backend.createIncident(
      victim: Hiker(id: 'x', name: 'Mina', lat: 0.002, lon: 0, updatedAt: 1),
      note: 'lost',
    );
    await t.pumpAndSettle();
    expect(find.text('Mina needs help'), findsOneWidget);

    await t.tap(find.text('I can help'));
    await t.pumpAndSettle();
    expect(find.text('SOS: Mina'), findsOneWidget); // chat opened
    expect(find.text('On my way. I can help.'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Bring water?');
    await t.tap(find.byIcon(Icons.send_rounded));
    await t.pumpAndSettle();
    expect(find.text('Bring water?'), findsOneWidget);
    await t.runAsync(() => app.setVisible(false));
  });
}
