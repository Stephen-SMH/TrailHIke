import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/emergency_numbers.dart';
import '../core/geo.dart';
import '../core/models.dart';
import 'chat_screen.dart';
import 'theme.dart';

/// The screen a hiker in trouble needs: SOS, official numbers, nearest help.
class HelpTab extends StatefulWidget {
  final AppState app;
  const HelpTab(this.app, {super.key});

  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> {
  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    app.updateLocation().then((_) => app.loadStations());
  }

  Future<void> _confirmSos() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send SOS?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This alerts hikers within 5 km and texts your emergency '
              'contacts your position. It does not call the authorities: '
              'use the numbers below for that.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'What happened? (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Send SOS',
              style: TextStyle(color: DS.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await app.sendSos(note: note.text.trim());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) {
      final nums = numbersFor(app.country);
      return Scaffold(
        appBar: AppBar(title: const Text('Get help')),
        body: RefreshIndicator(
          onRefresh: () async {
            await app.updateLocation();
            await app.loadStations();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (app.locationError != null)
                _Notice(app.locationError!, Icons.location_off),
              if (app.mySos == null)
                Center(
                  child: GradientButton(
                    'SOS',
                    icon: Icons.sos,
                    danger: true,
                    onPressed: _confirmSos,
                  ),
                )
              else
                _ActiveSos(app),
              const SizedBox(height: 20),
              Text('EMERGENCY NUMBERS - ${nums.country.toUpperCase()}',
                  style: monoLabel(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CallChip(app, 'Police', nums.police),
                  _CallChip(app, 'Ambulance', nums.ambulance),
                  if (nums.fire != null) _CallChip(app, 'Fire', nums.fire!),
                  if (nums.mountainRescue != null)
                    _CallChip(app, 'Mountain rescue', nums.mountainRescue!),
                ],
              ),
              if (nums.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${nums.note}. Numbers can change: verify before you travel.',
                    style: const TextStyle(fontSize: 12, color: DS.inkSoft),
                  ),
                ),
              const SizedBox(height: 20),
              Text('NEAREST HELP', style: monoLabel(context)),
              const SizedBox(height: 8),
              if (app.stationsNote != null)
                _Notice(app.stationsNote!, Icons.info_outline),
              for (final s in app.helpStations) _StationTile(app, s),
            ],
          ),
        ),
      );
    },
  );
}

class _ActiveSos extends StatelessWidget {
  final AppState app;
  const _ActiveSos(this.app);

  @override
  Widget build(BuildContext context) {
    final sos = app.mySos!;
    return GlassCard(
      hue: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SOS is active',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            app.sosUploadPending
                ? 'No signal: contacts were texted. Nearby hikers will be '
                    'alerted as soon as you are back online.'
                : sos.responderIds.isEmpty
                ? 'Nearby hikers have been alerted. Waiting for a reply.'
                : '${sos.responderIds.length} hiker(s) are coming to help.',
            style: const TextStyle(color: DS.inkSoft),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!app.sosUploadPending)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(app, sos)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open chat'),
                ),
              TextButton.icon(
                onPressed: app.resolveMySos,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("I'm safe - end SOS"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallChip extends StatelessWidget {
  final AppState app;
  final String label, number;
  const _CallChip(this.app, this.label, this.number);

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.call, size: 16),
    label: Text('$label  $number'),
    onPressed: () => app.launcher.call(number),
  );
}

class _StationTile extends StatelessWidget {
  final AppState app;
  final HelpStation s;
  const _StationTile(this.app, this.s);

  static IconData _icon(StationKind k) => switch (k) {
    StationKind.police => Icons.local_police_outlined,
    StationKind.ranger => Icons.forest_outlined,
    StationKind.hospital => Icons.local_hospital_outlined,
    StationKind.fire => Icons.fire_truck_outlined,
    StationKind.mountainRescue => Icons.terrain,
  };

  @override
  Widget build(BuildContext context) {
    final f = app.fix;
    final dir = f == null ? '' : ' ${compass(f.lat, f.lon, s.lat, s.lon)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon(s.kind), color: DS.pink),
      title: Text(s.name),
      subtitle: Text('${formatDistance(s.distanceM)}$dir'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.phone != null)
            IconButton(
              tooltip: 'Call',
              icon: const Icon(Icons.call),
              onPressed: () => app.launcher.call(s.phone!),
            ),
          IconButton(
            tooltip: 'Directions',
            icon: const Icon(Icons.directions),
            onPressed: () => app.launcher.directions(s.lat, s.lon),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Notice(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: DS.warn),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: DS.inkSoft)),
        ),
      ],
    ),
  );
}
