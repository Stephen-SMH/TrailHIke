import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/geo.dart';
import '../core/models.dart';
import 'theme.dart';

/// The chat for one SOS. Only people on that incident use it.
class ChatScreen extends StatefulWidget {
  final AppState app;
  final Incident incident;
  const ChatScreen(this.app, this.incident, {super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  late final Stream<List<ChatMessage>> _messages =
      widget.app.backend.watchMessages(widget.incident.id);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text;
    _text.clear();
    await widget.app.sendChat(widget.incident.id, t);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app, inc = widget.incident;
    final f = app.fix;
    return Scaffold(
      appBar: AppBar(
        title: Text('SOS: ${inc.victimName}'),
        actions: [
          if (inc.victimId != app.myId)
            IconButton(
              tooltip: 'Directions to them',
              icon: const Icon(Icons.directions),
              onPressed: () => app.launcher.directions(inc.lat, inc.lon),
            ),
        ],
      ),
      body: Column(
        children: [
          if (inc.note.isNotEmpty || f != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                [
                  if (inc.note.isNotEmpty) inc.note,
                  if (f != null && inc.victimId != app.myId)
                    '${formatDistance(distanceM(f.lat, f.lon, inc.lat, inc.lon))} '
                        '${compass(f.lat, f.lon, inc.lat, inc.lon)} of you',
                ].join('  -  '),
                style: const TextStyle(color: DS.inkSoft),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (_, snap) {
                final msgs = snap.data ?? const [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: DS.inkSoft),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m.senderId == app.myId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine
                              ? DS.violet.withValues(alpha: .35)
                              : DS.glass(.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Text(
                                m.senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: DS.pinkInk,
                                ),
                              ),
                            Text(m.text),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
