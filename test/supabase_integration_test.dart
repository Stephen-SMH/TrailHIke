// Runs the real SupabaseBackend against a live server (local dev by default).
//   SUPABASE_URL=http://127.0.0.1:54421 SUPABASE_KEY=... \
//     flutter test test/supabase_integration_test.dart
// Skipped when SUPABASE_URL is not set, so normal `flutter test` stays offline.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trailmark/core/models.dart';
import 'package:trailmark/services/supabase_backend.dart';

void main() {
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_KEY'];
  final skip = (url == null || key == null)
      ? 'set SUPABASE_URL and SUPABASE_KEY to run'
      : false;

  test('two phones: presence, SOS, help, chat, resolve', () async {
    final clientA = SupabaseClient(url!, key!);
    final clientB = SupabaseClient(url, key);
    final a = SupabaseBackend(clientA), b = SupabaseBackend(clientB);
    final idA = await a.signIn(), idB = await b.signIn();
    expect(idA, isNot(idB));

    Hiker me(String id, String name, double lat, double lon) =>
        Hiker(id: id, name: name, lat: lat, lon: lon, updatedAt: 0);
    // A random spot so repeated runs do not see each other's old data.
    final base = 10 + (DateTime.now().millisecondsSinceEpoch % 1000) / 100;
    final alice = me(idA, 'Alice Test', base, base);
    final bob = me(idB, 'Bob Test', base + 0.004, base + 0.002);

    await a.setPresence(alice);
    await b.setPresence(bob);
    final seen = await a.nearbyHikers(base, base, 5000);
    expect(seen.map((h) => h.name), ['Bob']);

    // Bob watches for SOS alerts in real time.
    final alerts = <List<Incident>>[];
    final sub = b.watchIncidents(bob.lat, bob.lon, 5000).listen(alerts.add);
    await Future<void>.delayed(const Duration(seconds: 1));

    final inc = await a.createIncident(victim: alice, note: 'integration test');
    expect(inc.status, IncidentStatus.open);
    expect(inc.victimName, 'Alice Test');

    // Wait for the alert to reach Bob (realtime or the poll safety net).
    for (var i = 0; i < 40 && !alerts.any((l) => l.isNotEmpty); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(alerts.any((l) => l.any((x) => x.id == inc.id)), isTrue,
        reason: 'Bob should be alerted');

    await b.respond(inc.id, bob);
    await b.sendMessage(
      ChatMessage(
        id: 'x',
        incidentId: inc.id,
        senderId: idB,
        senderName: 'Bob',
        text: 'On my way',
        createdAt: 0,
      ),
    );

    // Alice's chat stream sees Bob's message.
    final msgs = await a
        .watchMessages(inc.id)
        .firstWhere((l) => l.isNotEmpty)
        .timeout(const Duration(seconds: 20));
    expect(msgs.single.text, 'On my way');
    expect(msgs.single.senderName, 'Bob');

    final fresh = await a.getIncident(inc.id);
    expect(fresh!.responderIds, [idB]);

    await a.resolve(inc.id);
    expect((await a.getIncident(inc.id))!.status, IncidentStatus.resolved);

    await sub.cancel();
    await a.clearPresence(idA);
    await b.clearPresence(idB);
    await clientA.dispose();
    await clientB.dispose();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
