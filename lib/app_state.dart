import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'core/geo.dart';
import 'core/models.dart';
import 'services/backend.dart';
import 'services/key_value_store.dart';
import 'services/location_source.dart';
import 'services/sos_message.dart';
import 'services/station_finder.dart';

/// Glue between the screens and everything else.
class AppState extends ChangeNotifier {
  final Backend backend;
  final KeyValueStore kv;
  final LocationSource location;
  final StationFinder stations;
  final Launcher launcher;
  final int Function() now;

  /// Hikers and SOS alerts are looked for within this distance.
  static const radiusM = 5000.0;

  AppState({
    required this.backend,
    required this.kv,
    required this.location,
    required this.stations,
    required this.launcher,
    int Function()? now,
  }) : now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  // Profile (kept on the phone)
  String myId = '';
  String name = '';
  String country = '';
  List<EmergencyContact> contacts = [];

  // Live state
  Fix? fix;
  String? locationError;
  bool visible = false;
  List<Hiker> nearby = [];
  List<Incident> incidents = []; // open SOS near me, not mine
  List<HelpStation> helpStations = [];
  String? stationsNote; // e.g. "Showing saved results (offline)"
  Incident? mySos;
  bool sosUploadPending = false;
  bool signedIn = false;
  Timer? _sosTimer;

  StreamSubscription<List<Incident>>? _incSub;
  Timer? _timer;

  bool get hasProfile => name.isNotEmpty;

  Future<void> load() async {
    await _signIn();
    name = await kv.get('name') ?? '';
    country = await kv.get('country') ?? '';
    final raw = await kv.get('contacts');
    if (raw != null) {
      contacts = [
        for (final c in jsonDecode(raw) as List)
          EmergencyContact.fromMap(Map<String, Object?>.from(c as Map)),
      ];
    }
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String country,
    required List<EmergencyContact> contacts,
  }) async {
    this.name = name.trim();
    this.country = country.toUpperCase();
    this.contacts = contacts;
    await kv.set('name', this.name);
    await kv.set('country', this.country);
    await kv.set(
      'contacts',
      jsonEncode(contacts.map((c) => c.toMap()).toList()),
    );
    notifyListeners();
  }

  /// Get an identity from the server. If we are offline and have never signed
  /// in, use a temporary local id; we sign in properly when signal returns.
  Future<void> _signIn() async {
    try {
      myId = await backend.signIn();
      signedIn = true;
    } catch (_) {
      signedIn = false;
      if (myId.isEmpty) {
        myId = await kv.get('local_id') ?? '';
        if (myId.isEmpty) {
          myId = 'local${Random().nextInt(1 << 32).toRadixString(36)}';
          await kv.set('local_id', myId);
        }
      }
    }
  }

  Hiker _me(Fix f) =>
      Hiker(id: myId, name: name, lat: f.lat, lon: f.lon, updatedAt: now());

  /// Read the GPS. Sets [locationError] instead of throwing.
  Future<Fix?> updateLocation() async {
    try {
      fix = await location.current();
      locationError = null;
    } on LocationDenied {
      locationError = 'Location is off. Allow it in Settings to find help.';
    } catch (_) {
      locationError = 'Could not get your position yet.';
    }
    notifyListeners();
    return fix;
  }

  // ---- Nearby hikers ----

  Future<void> setVisible(bool on) async {
    if (on) {
      if (await updateLocation() == null) return;
      visible = true;
      try {
        await backend.setPresence(_me(fix!));
      } catch (_) {}
      _watchIncidents();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
      await refresh();
    } else {
      visible = false;
      _timer?.cancel();
      await _incSub?.cancel();
      _incSub = null;
      nearby = [];
      incidents = [];
      try {
        await backend.clearPresence(myId);
      } catch (_) {}
    }
    notifyListeners();
  }

  void _watchIncidents() {
    _incSub?.cancel();
    final f = fix;
    if (f == null) return;
    _incSub = backend.watchIncidents(f.lat, f.lon, radiusM).listen((l) {
      incidents = l.where((i) => i.victimId != myId).toList();
      notifyListeners();
    });
  }

  /// Refresh position, presence, nearby list; retry an SOS that was not sent.
  Future<void> refresh() async {
    final f = await updateLocation();
    if (f == null) return;
    if (!signedIn) await _signIn();
    try {
      if (visible) await backend.setPresence(_me(f));
      nearby = await backend.nearbyHikers(
        f.lat,
        f.lon,
        radiusM,
        excludeId: myId,
      );
      if (sosUploadPending) await _uploadSos();
    } catch (_) {}
    notifyListeners();
  }

  // ---- Help stations ----

  Future<void> loadStations() async {
    final f = fix ?? await updateLocation();
    if (f == null) {
      await _stationsFromCache('No position');
      return;
    }
    try {
      helpStations = await stations.near(f.lat, f.lon);
      stationsNote = helpStations.isEmpty
          ? 'No stations found within 30 km. Use the emergency numbers.'
          : null;
      await kv.set(
        'stations',
        jsonEncode([
          for (final s in helpStations)
            {
              'n': s.name,
              'k': s.kind.index,
              'la': s.lat,
              'lo': s.lon,
              'p': s.phone,
            },
        ]),
      );
    } catch (_) {
      await _stationsFromCache('Offline');
    }
    notifyListeners();
  }

  Future<void> _stationsFromCache(String why) async {
    final raw = await kv.get('stations');
    final f = fix;
    if (raw == null) {
      stationsNote = '$why. Use the emergency numbers above.';
    } else {
      helpStations = [
        for (final m in jsonDecode(raw) as List)
          HelpStation(
            name: m['n'] as String,
            kind: StationKind.values[m['k'] as int],
            lat: (m['la'] as num).toDouble(),
            lon: (m['lo'] as num).toDouble(),
            phone: m['p'] as String?,
          ).withDistance(
            f == null
                ? 0
                : distanceM(
                    f.lat,
                    f.lon,
                    (m['la'] as num).toDouble(),
                    (m['lo'] as num).toDouble(),
                  ),
          ),
      ];
      stationsNote = '$why. Showing saved results from your last lookup.';
    }
    notifyListeners();
  }

  // ---- SOS ----

  /// Raise an SOS: alert nearby hikers through the server, and prepare a text
  /// for personal contacts. Works with whatever is available; never blocks on
  /// the network.
  Future<void> sendSos({String note = ''}) async {
    final f = fix ?? await updateLocation();
    if (f == null) return;
    final victim = _me(f);
    mySos = Incident(
      id: 'pending',
      victimId: myId,
      victimName: name.isEmpty ? 'A hiker' : name,
      lat: f.lat,
      lon: f.lon,
      createdAt: now(),
      note: note,
    );
    sosUploadPending = true;
    notifyListeners();
    await _uploadSos(victim: victim);
    if (contacts.isNotEmpty) {
      await launcher.sms(
        contacts,
        sosMessage(
          name: victim.name.isEmpty ? 'A hiker' : victim.name,
          lat: f.lat,
          lon: f.lon,
          note: note,
        ),
      );
    }
  }

  Future<void> _uploadSos({Hiker? victim}) async {
    final f = fix, m = mySos;
    if (f == null || m == null) return;
    try {
      mySos = await backend.createIncident(
        victim: victim ?? _me(f),
        note: m.note,
      );
      sosUploadPending = false;
      _watchMySos();
    } catch (_) {
      sosUploadPending = true; // retried by refresh() when signal returns
    }
    notifyListeners();
  }

  /// While an SOS is open, check every few seconds who has joined.
  void _watchMySos() {
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final m = mySos;
      if (m == null || m.id == 'pending') return;
      try {
        final fresh = await backend.getIncident(m.id);
        if (fresh != null) {
          mySos = fresh;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  Future<void> resolveMySos() async {
    final m = mySos;
    if (m == null) return;
    if (m.id != 'pending') {
      try {
        await backend.resolve(m.id);
      } catch (_) {}
    }
    mySos = null;
    sosUploadPending = false;
    _sosTimer?.cancel();
    notifyListeners();
  }

  // ---- Helping and chat ----

  Future<void> iCanHelp(Incident i) async {
    final f = fix;
    if (f == null) return;
    await backend.respond(i.id, _me(f));
    await sendChat(i.id, 'On my way. I can help.');
  }

  Future<void> sendChat(String incidentId, String text) async {
    if (text.trim().isEmpty) return;
    await backend.sendMessage(
      ChatMessage(
        id: '${now()}-$myId',
        incidentId: incidentId,
        senderId: myId,
        senderName: name.isEmpty ? 'A hiker' : name,
        text: text.trim(),
        createdAt: now(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sosTimer?.cancel();
    _incSub?.cancel();
    super.dispose();
  }
}
