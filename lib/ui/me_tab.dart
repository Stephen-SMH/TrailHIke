import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/emergency_numbers.dart';
import '../core/models.dart';
import 'theme.dart';

/// Your name, country and the people to text if you send an SOS.
class MeTab extends StatefulWidget {
  final AppState app;
  const MeTab(this.app, {super.key});

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  late final _name = TextEditingController(text: widget.app.name);
  late String _country = emergencyNumbers.containsKey(widget.app.country)
      ? widget.app.country
      : 'IL';
  late final List<EmergencyContact> _contacts = List.of(widget.app.contacts);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    final name = TextEditingController(), phone = TextEditingController();
    final c = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (with country code)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                EmergencyContact(name.text.trim(), phone.text.trim()),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (c != null) setState(() => _contacts.add(c));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    await widget.app.saveProfile(
      name: _name.text,
      country: _country,
      contacts: _contacts,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Me')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _country,
          decoration: const InputDecoration(
            labelText: 'Country you are hiking in',
          ),
          items: [
            for (final e in emergencyNumbers.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text('${e.value.country} (${e.key})'),
              ),
          ],
          onChanged: (v) => setState(() => _country = v ?? _country),
        ),
        const SizedBox(height: 24),
        Text('PEOPLE TO TEXT IF YOU SEND AN SOS', style: monoLabel(context)),
        for (var i = 0; i < _contacts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline, color: DS.pink),
            title: Text(_contacts[i].name),
            subtitle: Text(_contacts[i].phone),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _contacts.removeAt(i)),
            ),
          ),
        TextButton.icon(
          onPressed: _addContact,
          icon: const Icon(Icons.add),
          label: const Text('Add contact'),
        ),
        const SizedBox(height: 16),
        GradientButton('Save', icon: Icons.check, onPressed: _save),
      ],
    ),
  );
}
