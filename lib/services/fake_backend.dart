import 'dart:async';

import '../core/geo.dart';
import '../core/models.dart';
import 'backend.dart';

/// A whole server in memory. Lets the app run and be tested with no internet,
/// and lets two simulated phones talk to each other in one test.
class FakeBackend implements Backend {
  final int Function() now;
  final Duration presenceTtl;
  FakeBackend({int Function()? now, this.presenceTtl = const Duration(minutes: 30)})
    : now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final _hikers = <String, Hiker>{};
  final _incidents = <String, Incident>{};
  final _messages = <String, List<ChatMessage>>{};
  final _changed = StreamController<void>.broadcast();
  final _msgChanged = StreamController<String>.broadcast();
  var _seq = 0;
  var _users = 0;

  @override
  Future<String> signIn() async => 'user${++_users}';

  @override
  Future<Incident?> getIncident(String id) async => _incidents[id];

  @override
  Future<void> setPresence(Hiker me) async => _hikers[me.id] = me;

  @override
  Future<void> clearPresence(String hikerId) async => _hikers.remove(hikerId);

  @override
  Future<List<Hiker>> nearbyHikers(
    double lat,
    double lon,
    double radiusM, {
    String? excludeId,
  }) async {
    final fresh = now() - presenceTtl.inMilliseconds;
    final out = [
      for (final h in _hikers.values)
        if (h.id != excludeId &&
            h.updatedAt >= fresh &&
            distanceM(lat, lon, h.lat, h.lon) <= radiusM)
          h,
    ]..sort(
        (a, b) => distanceM(lat, lon, a.lat, a.lon)
            .compareTo(distanceM(lat, lon, b.lat, b.lon)),
      );
    return out;
  }

  @override
  Future<Incident> createIncident({
    required Hiker victim,
    String note = '',
  }) async {
    final i = Incident(
      id: 'i${++_seq}',
      victimId: victim.id,
      victimName: victim.name,
      lat: victim.lat,
      lon: victim.lon,
      createdAt: now(),
      note: note,
    );
    _incidents[i.id] = i;
    _changed.add(null);
    return i;
  }

  @override
  Future<void> respond(String incidentId, Hiker responder) async {
    final i = _incidents[incidentId];
    if (i == null || i.responderIds.contains(responder.id)) return;
    _incidents[incidentId] = i.copyWith(
      responderIds: [...i.responderIds, responder.id],
    );
    _changed.add(null);
  }

  @override
  Future<void> resolve(String incidentId) async {
    final i = _incidents[incidentId];
    if (i == null) return;
    _incidents[incidentId] = i.copyWith(status: IncidentStatus.resolved);
    _changed.add(null);
  }

  List<Incident> _open(double lat, double lon, double radiusM) => [
    for (final i in _incidents.values)
      if (i.status == IncidentStatus.open &&
          distanceM(lat, lon, i.lat, i.lon) <= radiusM)
        i,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Incident>> watchIncidents(
    double lat,
    double lon,
    double radiusM,
  ) => _live(() => _open(lat, lon, radiusM), _changed.stream);

  @override
  Future<void> sendMessage(ChatMessage m) async {
    (_messages[m.incidentId] ??= []).add(m);
    _msgChanged.add(m.incidentId);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String incidentId) => _live(
    () => List.of(_messages[incidentId] ?? const []),
    _msgChanged.stream.where((id) => id == incidentId),
  );

  /// Emits the current value on listen, then again on every change.
  Stream<T> _live<T>(T Function() read, Stream<Object?> changes) {
    late final StreamController<T> c;
    StreamSubscription<Object?>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = changes.listen((_) => c.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  /// Demo helper: scatter a few pretend hikers around a point.
  void seedDemoHikers(double lat, double lon) {
    const names = ['Dana', 'Ravi', 'Mina', 'Tomas'];
    const offsets = [(0.004, 0.002), (-0.006, 0.004), (0.010, -0.007), (-0.015, -0.010)];
    for (var i = 0; i < names.length; i++) {
      _hikers['demo$i'] = Hiker(
        id: 'demo$i',
        name: names[i],
        lat: lat + offsets[i].$1,
        lon: lon + offsets[i].$2,
        updatedAt: now(),
      );
    }
  }
}
