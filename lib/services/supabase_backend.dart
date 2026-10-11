import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';
import 'backend.dart';

/// The real server. Every call goes through a database function that checks
/// who you are and what you are allowed to see (see supabase/migrations).
class SupabaseBackend implements Backend {
  final SupabaseClient _c;
  SupabaseBackend(this._c);

  @override
  Future<String> signIn() async {
    final existing = _c.auth.currentSession;
    if (existing != null) return existing.user.id;
    final res = await _c.auth.signInAnonymously();
    return res.user!.id;
  }

  @override
  Future<void> setPresence(Hiker me) => _c.rpc(
    'set_presence',
    params: {'p_lat': me.lat, 'p_lon': me.lon, 'p_name': me.name},
  );

  @override
  Future<void> clearPresence(String hikerId) => _c.rpc('clear_presence');

  @override
  Future<List<Hiker>> nearbyHikers(
    double lat,
    double lon,
    double radiusM, {
    String? excludeId,
  }) async {
    final rows = await _c.rpc(
      'nearby_hikers',
      params: {'p_lat': lat, 'p_lon': lon, 'p_radius_m': radiusM},
    ) as List;
    return [
      for (final r in rows)
        Hiker(
          id: r['id'] as String,
          name: r['name'] as String,
          lat: (r['lat'] as num).toDouble(),
          lon: (r['lon'] as num).toDouble(),
          updatedAt: DateTime.parse(r['updated_at'] as String)
              .millisecondsSinceEpoch,
        ),
    ];
  }

  static Incident _incident(Map<String, dynamic> r) => Incident(
    id: r['id'] as String,
    victimId: r['victim_id'] as String,
    victimName: r['victim_name'] as String,
    lat: (r['lat'] as num).toDouble(),
    lon: (r['lon'] as num).toDouble(),
    note: (r['note'] as String?) ?? '',
    status: r['status'] == 'open'
        ? IncidentStatus.open
        : IncidentStatus.resolved,
    createdAt: DateTime.parse(r['created_at'] as String)
        .millisecondsSinceEpoch,
    responderIds: [
      for (final id in (r['responder_ids'] as List? ?? const [])) id as String,
    ],
  );

  @override
  Future<Incident> createIncident({
    required Hiker victim,
    String note = '',
  }) async {
    final id = await _c.rpc(
      'create_incident',
      params: {
        'p_lat': victim.lat,
        'p_lon': victim.lon,
        'p_name': victim.name,
        'p_note': note,
      },
    ) as String;
    return (await getIncident(id))!;
  }

  @override
  Future<Incident?> getIncident(String id) async {
    final rows = await _c.rpc('my_incident', params: {'p_id': id}) as List;
    return rows.isEmpty ? null : _incident(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> respond(String incidentId, Hiker responder) =>
      _c.rpc('respond_to_incident', params: {'p_incident': incidentId});

  @override
  Future<void> resolve(String incidentId) =>
      _c.rpc('resolve_incident', params: {'p_incident': incidentId});

  @override
  Stream<List<Incident>> watchIncidents(
    double lat,
    double lon,
    double radiusM,
  ) {
    late final StreamController<List<Incident>> out;
    RealtimeChannel? channel;
    Timer? poll;

    Future<void> fetch() async {
      try {
        final rows = await _c.rpc(
          'nearby_incidents',
          params: {'p_lat': lat, 'p_lon': lon, 'p_radius_m': radiusM},
        ) as List;
        if (!out.isClosed) {
          out.add([for (final r in rows) _incident(r as Map<String, dynamic>)]);
        }
      } catch (_) {
        // offline: keep the last list, try again on the next tick
      }
    }

    out = StreamController<List<Incident>>(
      onListen: () {
        fetch();
        // Realtime gives instant updates; polling is the safety net.
        channel = _c
            .channel('incidents-${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'incidents',
              callback: (_) => fetch(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'incident_responders',
              callback: (_) => fetch(),
            )
            .subscribe();
        poll = Timer.periodic(const Duration(seconds: 20), (_) => fetch());
      },
      onCancel: () async {
        poll?.cancel();
        if (channel != null) await _c.removeChannel(channel!);
      },
    );
    return out.stream;
  }

  @override
  Future<void> sendMessage(ChatMessage m) => _c.from('messages').insert({
    'incident_id': m.incidentId,
    'sender_id': m.senderId,
    'sender_name': m.senderName,
    'body': m.text,
  });

  @override
  Stream<List<ChatMessage>> watchMessages(String incidentId) => _c
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('incident_id', incidentId)
      .order('created_at')
      .map(
        (rows) => [
          for (final r in rows)
            ChatMessage(
              id: r['id'] as String,
              incidentId: incidentId,
              senderId: r['sender_id'] as String,
              senderName: r['sender_name'] as String,
              text: r['body'] as String,
              createdAt: DateTime.parse(r['created_at'] as String)
                  .millisecondsSinceEpoch,
            ),
        ],
      );
}
