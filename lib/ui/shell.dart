import 'package:flutter/material.dart';

import '../app_state.dart';
import 'help_tab.dart';
import 'me_tab.dart';
import 'nearby_tab.dart';

/// Bottom navigation: Help, Nearby, Me. New users start on Me.
class Shell extends StatefulWidget {
  final AppState app;
  final String? banner; // environment notice; null in production
  const Shell(this.app, {super.key, this.banner});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int index = widget.app.hasProfile ? 0 : 2;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        if (widget.banner != null)
          Container(
            width: double.infinity,
            color: Colors.amber.shade800,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 4,
              16,
              4,
            ),
            child: Text(
              widget.banner!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: widget.banner != null,
            child: IndexedStack(
              index: index,
              children: [
                HelpTab(widget.app),
                NearbyTab(widget.app),
                MeTab(widget.app),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) => setState(() => index = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.sos_outlined), label: 'Help'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Nearby'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
      ],
    ),
  );
}
