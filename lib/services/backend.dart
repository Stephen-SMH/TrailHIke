import '../core/models.dart';

/// Everything that needs a server: who is nearby, SOS alerts, chat.
/// The app only talks to this interface, so the real Supabase version and the
/// in-memory test version are interchangeable.
abstract class Backend {
  /// Make sure we have an identity (anonymous account) and return its id.
  Future<String> signIn();

  /// Become visible to nearby hikers, or refresh your position.
  Future<void> setPresence(Hiker me);
  Future<void> clearPresence(String hikerId);

  /// Hikers within [radiusM] who updated recently, nearest first.
  Future<List<Hiker>> nearbyHikers(
    double lat,
    double lon,
    double radiusM, {
    String? excludeId,
  });

  Future<Incident> createIncident({required Hiker victim, String note = ''});
  /// An incident you are part of (victim or responder), fresh from the server.
  Future<Incident?> getIncident(String id);
  Future<void> respond(String incidentId, Hiker responder);
  Future<void> resolve(String incidentId);

  /// Open SOS alerts within [radiusM], updating live.
  Stream<List<Incident>> watchIncidents(double lat, double lon, double radiusM);

  Future<void> sendMessage(ChatMessage m);
  Stream<List<ChatMessage>> watchMessages(String incidentId);
}
