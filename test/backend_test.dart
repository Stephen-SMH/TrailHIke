import 'package:flutter_test/flutter_test.dart';
import 'package:trailmark/core/models.dart';
import 'package:trailmark/services/fake_backend.dart';

Hiker h(String id, double lat, {int t = 1000}) =>
    Hiker(id: id, name: id, lat: lat, lon: 0, updatedAt: t);

void main() {
  test('nearby hikers: radius, nearest first, excludes self', () async {
    final b = FakeBackend(now: () => 1000);
    await b.setPresence(h('me', 0));
    await b.setPresence(h('near', 0.005)); // ~555 m
    await b.setPresence(h('mid', 0.02)); // ~2.2 km
    await b.setPresence(h('far', 0.5)); // ~55 km
    final r = await b.nearbyHikers(0, 0, 5000, excludeId: 'me');
    expect(r.map((e) => e.id), ['near', 'mid']);
  });

  test('stale presence is ignored, clearing removes you', () async {
    var now = 0;
    final b = FakeBackend(now: () => now);
    await b.setPresence(h('a', 0.001, t: 0));
    expect(await b.nearbyHikers(0, 0, 5000), hasLength(1));
    now += 31 * 60000; // 31 min later, no refresh
    expect(await b.nearbyHikers(0, 0, 5000), isEmpty);
    await b.setPresence(h('b', 0.001, t: now));
    await b.clearPresence('b');
    expect(await b.nearbyHikers(0, 0, 5000), isEmpty);
  });

  test('SOS reaches nearby watchers, not distant ones; resolve closes it',
      () async {
    final b = FakeBackend(now: () => 1);
    final near = b.watchIncidents(0, 0, 5000);
    final far = b.watchIncidents(10, 10, 5000);
    final nearSeen = <int>[], farSeen = <int>[];
    final s1 = near.listen((l) => nearSeen.add(l.length));
    final s2 = far.listen((l) => farSeen.add(l.length));

    final i = await b.createIncident(victim: h('v', 0.001), note: 'ankle');
    await Future<void>.delayed(Duration.zero);
    expect(nearSeen.last, 1);
    expect(farSeen.last, 0);

    await b.respond(i.id, h('helper', 0.002));
    await b.respond(i.id, h('helper', 0.002)); // twice: counted once
    await b.resolve(i.id);
    await Future<void>.delayed(Duration.zero);
    expect(nearSeen.last, 0);
    await s1.cancel();
    await s2.cancel();
  });

  test('chat messages go to that incident only', () async {
    final b = FakeBackend(now: () => 1);
    final got = <List<ChatMessage>>[];
    final s = b.watchMessages('i1').listen(got.add);
    ChatMessage m(String inc, String text) => ChatMessage(
      id: text,
      incidentId: inc,
      senderId: 'x',
      senderName: 'X',
      text: text,
      createdAt: 1,
    );
    await b.sendMessage(m('i1', 'hello'));
    await b.sendMessage(m('i2', 'other room'));
    await Future<void>.delayed(Duration.zero);
    expect(got.last.map((e) => e.text), ['hello']);
    await s.cancel();
  });
}
