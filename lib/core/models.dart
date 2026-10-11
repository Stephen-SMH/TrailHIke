/// A hiker who chose to be visible to others nearby.
class Hiker {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int updatedAt; // unix ms

  const Hiker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.updatedAt,
  });
}

enum IncidentStatus { open, resolved }

/// One SOS. The victim, the people coming to help, and the chat all hang off it.
class Incident {
  final String id;
  final String victimId;
  final String victimName;
  final double lat;
  final double lon;
  final int createdAt;
  final String note; // what the victim typed, e.g. "twisted ankle"
  final IncidentStatus status;
  final List<String> responderIds; // hikers who tapped "I can help"

  const Incident({
    required this.id,
    required this.victimId,
    required this.victimName,
    required this.lat,
    required this.lon,
    required this.createdAt,
    this.note = '',
    this.status = IncidentStatus.open,
    this.responderIds = const [],
  });

  Incident copyWith({IncidentStatus? status, List<String>? responderIds}) =>
      Incident(
        id: id,
        victimId: victimId,
        victimName: victimName,
        lat: lat,
        lon: lon,
        createdAt: createdAt,
        note: note,
        status: status ?? this.status,
        responderIds: responderIds ?? this.responderIds,
      );
}

class ChatMessage {
  final String id;
  final String incidentId;
  final String senderId;
  final String senderName;
  final String text;
  final int createdAt;

  const ChatMessage({
    required this.id,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });
}

enum StationKind { police, ranger, hospital, fire, mountainRescue }

/// Somewhere a hiker in trouble could get help.
class HelpStation {
  final String name;
  final StationKind kind;
  final double lat;
  final double lon;
  final String? phone;
  final double distanceM;

  const HelpStation({
    required this.name,
    required this.kind,
    required this.lat,
    required this.lon,
    this.phone,
    this.distanceM = 0,
  });

  HelpStation withDistance(double m) => HelpStation(
    name: name,
    kind: kind,
    lat: lat,
    lon: lon,
    phone: phone,
    distanceM: m,
  );
}

class EmergencyContact {
  final String name;
  final String phone;
  const EmergencyContact(this.name, this.phone);

  Map<String, Object?> toMap() => {'name': name, 'phone': phone};
  factory EmergencyContact.fromMap(Map<String, Object?> m) =>
      EmergencyContact(m['name'] as String, m['phone'] as String);
}
