import 'package:flutter/material.dart';

import '../../domain/services/database_encryption_service.dart';
import '../theme/app_theme.dart';

/// F4-Verschlüsselung (Kay-Entscheidung 2026-10-19): wird gezeigt,
/// bevor die eigentliche App startet, wenn die Datenbank
/// passwortgeschützt ist (siehe `main.dart`). Eine eigene,
/// eigenständige `MaterialApp` statt eines gewöhnlichen Screens — zu
/// diesem Zeitpunkt existiert noch kein `AppDatabase`/Provider-Baum,
/// den ein normaler Screen bräuchte.
class DatabaseUnlockScreen extends StatefulWidget {
  const DatabaseUnlockScreen({
    super.key,
    required this.encryptionService,
    required this.dbPath,
    required this.onUnlocked,
  });

  final DatabaseEncryptionService encryptionService;
  final String dbPath;
  final void Function(String password) onUnlocked;

  @override
  State<DatabaseUnlockScreen> createState() => _DatabaseUnlockScreenState();
}

class _DatabaseUnlockScreenState extends State<DatabaseUnlockScreen> {
  final _passwordCtrl = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.encryptionService.verifyPassword(dbPath: widget.dbPath, password: password);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked(password);
    } else {
      setState(() {
        _checking = false;
        _error = 'Falsches Passwort.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WerkkernERP',
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Datenbank entsperren',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Diese Datenbank ist mit einem Passwort geschützt (F4-Verschlüsselung).',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _checking ? null : _unlock(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _checking ? null : _unlock,
                    child: _checking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Entsperren'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
