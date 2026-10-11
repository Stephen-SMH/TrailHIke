import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/geo.dart';
import '../core/models.dart';
import 'chat_screen.dart';
import 'theme.dart';

/// Hikers close to you, and SOS alerts you could answer.
class NearbyTab extends StatelessWidget {
  final AppState app;
  const NearbyTab(this.app, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) {
      final f = app.fix;
      return Scaffold(
        appBar: AppBar(title: const Text('Nearby hikers')),
        body: RefreshIndicator(
          onRefresh: app.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("I'm hiking - let others find me"),
                subtitle: const Text(
                  'Only for emergencies. Hikers within 5 km see your first '
                  'name and distance, never your exact position. Turn off '
                  'when you finish.',
                ),
                value: app.visible,
                onChanged: !app.hasProfile
                    ? null
                    : (v) => app.setVisible(v),
              ),
              if (!app.hasProfile)
                const Text(
                  'Add your name in the Me tab first.',
                  style: TextStyle(color: DS.warn),
                ),
              if (app.locationError != null)
                Text(
                  app.locationError!,
                  style: const TextStyle(color: DS.warn),
                ),
              if (app.incidents.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('SOS NEAR YOU', style: monoLabel(context)),
                const SizedBox(height: 8),
                for (final i in app.incidents) _IncidentCard(app, i),
              ],
              const SizedBox(height: 16),
              Text('HIKERS WITHIN 5 KM', style: monoLabel(context)),
              const SizedBox(height: 8),
              if (!app.visible)
                const Text(
                  'Turn on the switch above to see who is around.',
                  style: TextStyle(color: DS.inkSoft),
                )
              else if (app.nearby.isEmpty)
                const Text(
                  'Nobody nearby right now.',
                  style: TextStyle(color: DS.inkSoft),
                ),
              for (final h in app.nearby)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hiking, color: DS.pink),
                  title: Text(h.name.split(' ').first),
                  subtitle: Text(
                    f == null
                        ? ''
                        : '${_roughDistance(distanceM(f.lat, f.lon, h.lat, h.lon))} '
                              '${compass(f.lat, f.lon, h.lat, h.lon)}  -  '
                              '${formatAgo(Duration(milliseconds: app.now() - h.updatedAt))}',
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  /// Rounded so nobody's exact spot can be worked out from the list.
  static String _roughDistance(double m) =>
      m < 500 ? 'under 500 m' : formatDistance((m / 100).round() * 100.0);
}

class _IncidentCard extends StatelessWidget {
  final AppState app;
  final Incident i;
  const _IncidentCard(this.app, this.i);

  @override
  Widget build(BuildContext context) {
    final f = app.fix;
    final joined = i.responderIds.contains(app.myId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        hue: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${i.victimName} needs help',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (f != null)
                  '${formatDistance(distanceM(f.lat, f.lon, i.lat, i.lon))} '
                      '${compass(f.lat, f.lon, i.lat, i.lon)}',
                if (i.note.isNotEmpty) i.note,
                '${i.responderIds.length} on the way',
              ].join('  -  '),
              style: const TextStyle(color: DS.inkSoft),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (!joined)
                  FilledButton(
                    onPressed: () async {
                      await app.iCanHelp(i);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(app, i),
                          ),
                        );
                      }
                    },
                    child: const Text('I can help'),
                  ),
                if (joined)
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatScreen(app, i)),
                    ),
                    child: const Text('Open chat'),
                  ),
                OutlinedButton(
                  onPressed: () => app.launcher.directions(i.lat, i.lon),
                  child: const Text('Directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
