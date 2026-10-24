import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/offline_vault.dart';
import '../../../domain/services/online_session.dart';
import 'online_home_screen.dart';
import 'online_text_prompt.dart';

/// Einstieg in den Online-Modus (Phase B): Server-Adresse, E-Mail,
/// Passwort → Firmenwahl aus den eigenen Mitgliedschaften. Der
/// Offline-Modus bleibt davon völlig unberührt.
class OnlineLoginScreen extends StatefulWidget {
  const OnlineLoginScreen({super.key, this.clientFactory, this.offlineStoreFactory});

  /// Für Widget-Tests (MockClient statt echtem Netzwerk).
  final WerkkernApiClient Function(Uri baseUrl)? clientFactory;

  /// Für Widget-Tests (In-Memory statt Gerätedatei/Keystore). Standard:
  /// verschlüsselte Gerätedatei, im Web kein Offline-Bestand.
  final OfflineStore? Function()? offlineStoreFactory;

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
  OfflineStore? _offline;

  @override
  void initState() {
    super.initState();
    _restoreLastInput();
    _openOfflineStore();
  }

  /// Lädt den Offline-Bestand des Geräts (B2). Ist er nicht lesbar
  /// (Schlüssel verloren/Datei beschädigt), ist er wertlos — er wird
  /// entfernt und das ausdrücklich angezeigt.
  Future<void> _openOfflineStore() async {
    final store = widget.offlineStoreFactory != null
        ? widget.offlineStoreFactory!()
        : (offlineCacheSupported
            ? OfflineStore(EncryptedOfflineVault(blobs: createDeviceOfflineBlobStore()!, keys: SecureOfflineKeyStore()))
            : null);
    if (store == null) return;
    try {
      await store.load();
    } on OfflineVaultUnreadable catch (e) {
      await store.wipe();
      if (mounted) setState(() => _error = '$e Der Offline-Bestand wurde entfernt.');
    } on Exception {
      // z. B. Keystore im Test nicht verfügbar — dann ohne Offline-Bestand.
      return;
    }
    if (mounted) setState(() => _offline = store);
  }

  /// Ohne Verbindung direkt in die markierten Dokumente (B2) — Abgleich
  /// erst nach der nächsten Anmeldung.
  Future<void> _openOffline() async {
    final store = _offline!;
    final scope = store.scope!;
    final session = OnlineSession(
      client: (widget.clientFactory ?? (u) => WerkkernApiClient(baseUrl: u))(Uri.parse(scope.serverUrl)),
      serverUrl: Uri.parse(scope.serverUrl),
      email: scope.email,
      companyId: scope.companyId,
      companyName: scope.companyName,
      isAdmin: false,
      permissions: scope.permissions,
      modules: scope.modules,
      offline: store,
      offlineOnly: true,
    );
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => OnlineHomeScreen(session: session)),
    );
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

  /// Gemeinsamer Rahmen für Konto-Aktionen vor der Anmeldung: Eingaben
  /// prüfen, [action] ausführen, danach normal anmelden.
  Future<void> _accountAction(Future<void> Function(WerkkernApiClient client) action) async {
    final url = _parseServerUrl();
    if (url == null) {
      setState(() => _error = 'Bitte eine gültige Server-Adresse eingeben, z. B. https://erp.example.org');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.length < 8) {
      setState(() => _error = 'E-Mail und Passwort (mind. 8 Zeichen) eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action((widget.clientFactory ?? (u) => WerkkernApiClient(baseUrl: u))(url));
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeOnlineError(e));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _submit();
  }

  Future<void> _register() => _accountAction(
        (client) => client.register(_emailCtrl.text.trim(), _passwordCtrl.text),
      );

  Future<void> _acceptInvitation() async {
    final code = await showOnlineTextPrompt(
      context,
      title: 'Einladung einlösen',
      label: 'Einladungscode',
      confirm: 'Einlösen',
      fieldKey: const Key('online-invitation-code'),
      intro: 'Server, E-Mail und Passwort oben ausfüllen. Neue E-Mail: das Passwort wird dein neues. Bestehendes '
          'Konto: dein bisheriges Passwort.',
    );
    if (code == null || code.isEmpty) return;
    await _accountAction((client) => client.acceptInvitation(code, _passwordCtrl.text));
  }

  /// Neue Firma mit dem angemeldeten Konto als Admin. Verbraucht das
  /// Login-Zwischentoken — danach wird automatisch neu angemeldet.
  Future<void> _createCompany() async {
    final name = await showOnlineTextPrompt(
      context,
      title: 'Neue Online-Firma',
      label: 'Firmenname',
      confirm: 'Anlegen',
      fieldKey: const Key('online-new-company-name'),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _client!.createCompany(_login!.identityToken, name);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _submit();
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
      final serverUrl = _parseServerUrl()!;
      var offline = _offline;
      String? offlineWarning;
      if (offline != null) {
        try {
          await offline.bind(OfflineScope(
            serverUrl: serverUrl.toString(),
            email: _emailCtrl.text.trim(),
            companyId: membership.companyId,
            companyName: membership.companyName,
            permissions: mine.permissions,
            modules: modules,
          ));
        } on StateError catch (e) {
          // Fremde, noch nicht übertragene Änderungen auf diesem Gerät:
          // nie still verwerfen — Offline-Funktion in dieser Sitzung aus.
          offlineWarning = e.message;
          offline = null;
        }
      }
      if (!mounted) return;
      final session = OnlineSession(
        client: client,
        serverUrl: serverUrl,
        email: _emailCtrl.text.trim(),
        companyId: membership.companyId,
        companyName: membership.companyName,
        isAdmin: mine.isAdmin,
        permissions: mine.permissions,
        modules: modules,
        offline: offline,
      );
      if (offlineWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline-Funktion nicht verfügbar: $offlineWarning'), duration: const Duration(seconds: 8)),
        );
      }
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
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(onPressed: _busy ? null : _register, child: const Text('Konto registrieren')),
                    TextButton(onPressed: _busy ? null : _acceptInvitation, child: const Text('Einladung einlösen')),
                  ],
                ),
                if (_offline?.scope != null && !_offline!.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.offline_pin_outlined),
                      title: Text('Offline-Bestand: ${_offline!.scope!.companyName}'),
                      subtitle: Text(
                        '${_offline!.documents.length} Dokument(e), ${_offline!.outbox.length} nicht übertragene '
                        'Änderung(en) · ${_offline!.scope!.email}',
                      ),
                      trailing: TextButton(onPressed: _busy ? null : _openOffline, child: const Text('Ohne Verbindung öffnen')),
                    ),
                  ),
              ] else ...[
                if (login.memberships.isEmpty)
                  const Text(
                    'Dieses Konto ist noch keiner Firma zugeordnet. Lege eine eigene Firma an oder lass dich vom '
                    'Firmen-Admin einladen.',
                  ),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createCompany,
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Neue Firma anlegen'),
                ),
              ],
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
