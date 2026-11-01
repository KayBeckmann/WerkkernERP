import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'app.dart';
import 'companies_screen.dart';

/// Anmeldung fürs Panel — nur Konten, die der Betreiber per
/// `platform_admin grant` freigeschaltet hat. Die Sitzung lebt nur im
/// Speicher des Tabs (Neuladen = neu anmelden).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.clientFactory, this.notice});

  final WerkkernApiClient Function() clientFactory;
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = widget.clientFactory();
    try {
      final login = await client.platformLogin(_email.text.trim(), _password.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => CompaniesScreen(client: client, email: login.email, clientFactory: widget.clientFactory),
      ));
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('WerkkernERP Plattform', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Firmen und Abos verwalten', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  if (widget.notice != null && _error == null) ...[
                    Text(widget.notice!, style: TextStyle(color: theme.colorScheme.tertiary)),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    Text(_error!, key: const Key('login-error'), style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    key: const Key('login-email'),
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('login-password'),
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Passwort', border: OutlineInputBorder()),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Anmelden'),
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
