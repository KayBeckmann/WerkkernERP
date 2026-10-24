import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import 'online_home_screen.dart';

/// Einstieg in den Online-Modus (Phase B): Server-Adresse, E-Mail,
/// Passwort → Firmenwahl aus den eigenen Mitgliedschaften. Der
/// Offline-Modus bleibt davon völlig unberührt.
class OnlineLoginScreen extends StatefulWidget {
  const OnlineLoginScreen({super.key, this.clientFactory});

  /// Für Widget-Tests (MockClient statt echtem Netzwerk).
  final WerkkernApiClient Function(Uri baseUrl)? clientFactory;

  @override
  State<OnlineLoginScreen> createState() => _OnlineLoginScreenState();
}

const _prefServerUrl = 'online.serverUrl';
const _prefEmail = 'online.email';

class _OnlineLoginScreenState extends State<OnlineLoginScreen> {
  final _serverCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  WerkkernApiClient? _client;
  OnlineLogin? _login;

  @override
  void initState() {
    super.initState();
    _restoreLastInput();
  }

  /// Server-Adresse und E-Mail der letzten Anmeldung vorbelegen — das
  /// Passwort wird bewusst nie gespeichert.
  Future<void> _restoreLastInput() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _serverCtrl.text = prefs.getString(_prefServerUrl) ?? '';
      _emailCtrl.text = prefs.getString(_prefEmail) ?? '';
    } on Exception {
      // Ohne gespeicherte Werte geht es genauso.
    }
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Uri? _parseServerUrl() {
    final raw = _serverCtrl.text.trim();
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _submit() async {
    final url = _parseServerUrl();
    if (url == null) {
      setState(() => _error = 'Bitte eine gültige Server-Adresse eingeben, z. B. https://erp.example.org');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = (widget.clientFactory ?? (u) => WerkkernApiClient(baseUrl: u))(url);
    try {
      final login = await client.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefServerUrl, _serverCtrl.text.trim());
        await prefs.setString(_prefEmail, _emailCtrl.text.trim());
      } on Exception {
        // Merken ist Komfort, kein Muss.
      }
      if (!mounted) return;
      setState(() {
        _client = client;
        _login = login;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException && e.isUnauthorized ? 'E-Mail oder Passwort falsch.' : describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectCompany(OnlineMembership membership) async {
    final client = _client!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await client.selectCompany(_login!.identityToken, membership.companyId);
      final mine = await client.myPermissions();
      final modules = await client.modules();
      if (!mounted) return;
      final session = OnlineSession(
        client: client,
        serverUrl: _parseServerUrl()!,
        companyName: membership.companyName,
        isAdmin: mine.isAdmin,
        permissions: mine.permissions,
        modules: modules,
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OnlineHomeScreen(session: session)),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      // Das Login-Zwischentoken ist nach einem Fehlversuch verbraucht —
      // zurück zur Anmeldung statt eines toten Firmenauswahl-Bildschirms.
      setState(() {
        _error = describeOnlineError(e);
        _login = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final login = _login;
    return Scaffold(
      appBar: AppBar(title: Text(login == null ? 'Online anmelden' : 'Firma wählen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (login == null) ...[
                const Text(
                  'Online-Modus: mehrere Nutzer arbeiten gemeinsam auf einem Server. Deine lokalen '
                  'Offline-Firmen bleiben davon unberührt und werden nicht übertragen.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('online-server'),
                  controller: _serverCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Server-Adresse', hintText: 'https://erp.example.org'),
                ),
                TextField(
                  key: const Key('online-email'),
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                ),
                TextField(
                  key: const Key('online-password'),
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Passwort'),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _submit, child: const Text('Anmelden')),
              ] else if (login.memberships.isEmpty)
                const Text('Dieses Konto ist noch keiner Firma zugeordnet. Bitte den Firmen-Admin um eine Einladung.')
              else
                for (final m in login.memberships)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: Text(m.companyName),
                      subtitle: Text(m.isAdmin ? '${m.groupName} · Admin' : m.groupName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _selectCompany(m),
                    ),
                  ),
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
