import 'package:flutter/material.dart';

import '../../../domain/services/online_session.dart';

/// Eigenes Passwort ändern (Online-Konto). Beendet serverseitig alle
/// anderen Sitzungen dieses Kontos.
class OnlinePasswordDialog extends StatefulWidget {
  const OnlinePasswordDialog({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlinePasswordDialog> createState() => _OnlinePasswordDialogState();
}

class _OnlinePasswordDialogState extends State<OnlinePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.length < 8) {
      setState(() => _error = 'Das neue Passwort braucht mindestens 8 Zeichen.');
      return;
    }
    if (_next.text != _repeat.text) {
      setState(() => _error = 'Die Wiederholung stimmt nicht überein.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.client.changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Passwort ändern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('online-password-current'),
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Aktuelles Passwort'),
          ),
          TextField(
            key: const Key('online-password-new'),
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Neues Passwort (mind. 8 Zeichen)'),
          ),
          TextField(
            key: const Key('online-password-repeat'),
            controller: _repeat,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Neues Passwort wiederholen'),
          ),
          const SizedBox(height: 8),
          const Text('Andere angemeldete Geräte werden dabei abgemeldet.'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Ändern')),
      ],
    );
  }
}
