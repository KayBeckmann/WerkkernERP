import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/offline_vault.dart';
import '../../../domain/services/online_accounts.dart';
import '../../../domain/services/online_session.dart';
import 'online_home_screen.dart';
import 'online_text_prompt.dart';

/// Einstieg in den Online-Modus (Phase B): Server-Adresse, E-Mail,
/// Passwort → Firmenwahl aus den eigenen Mitgliedschaften. Der
/// Offline-Modus bleibt davon völlig unberührt.
class OnlineLoginScreen extends StatefulWidget {
  const OnlineLoginScreen({
    super.key,
    this.clientFactory,
    this.offlineStoreFactory,
    this.accountStore,
    this.account,
    this.targetCompanyId,
    this.notice,
  });

  /// Für Widget-Tests (MockClient statt echtem Netzwerk).
  final WerkkernApiClient Function(Uri baseUrl)? clientFactory;

  /// Für Widget-Tests (In-Memory statt Gerätedatei/Keystore). Standard:
  /// verschlüsselte Gerätedatei, im Web kein Offline-Bestand.
  final OfflineStore? Function()? offlineStoreFactory;

  /// Bekannte Konten/Sitzungen dieses Geräts (Startseite). Standard:
  /// [defaultOnlineAccountStore].
  final OnlineAccountStore? accountStore;

  /// Von der Startseite: Server/E-Mail vorbelegen; mit gültiger
  /// gespeicherter Sitzung direkt in [targetCompanyId] — ohne Passwort.
  final SavedOnlineAccount? account;
  final String? targetCompanyId;

  /// Hinweis oben in der Maske, z. B. nach abgelaufener Sitzung.
  final String? notice;

  @override
  State<OnlineLoginScreen> createState() => _OnlineLoginScreenState();
}

const _prefServerUrl = 'online.serverUrl';
const _prefEmail = 'online.email';
const _prefStayLoggedIn = 'online.stayLoggedIn';

class _OnlineLoginScreenState extends State<OnlineLoginScreen> {
  final _serverCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _stayLoggedIn = false;
  String? _error;
  late final OnlineAccountStore _accounts = widget.accountStore ?? defaultOnlineAccountStore();
  WerkkernApiClient? _client;
  OnlineLogin? _login;
  OfflineStore? _offline;

  @override
  void initState() {
    super.initState();
    _restoreLastInput();
    _openOfflineStore();
    final account = widget.account;
    if (account != null) {
      _serverCtrl.text = account.serverUrl;
      _emailCtrl.text = account.email;
      if (widget.targetCompanyId != null && account.hasSessionAt(DateTime.now())) {
        _stayLoggedIn = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _resume(account, widget.targetCompanyId!));
      }
    }
  }

  WerkkernApiClient _newClient(Uri url) => (widget.clientFactory ?? (u) => WerkkernApiClient(baseUrl: u))(url);

  /// Gespeicherte Sitzung (angemeldet bleiben) weiterverwenden; liegt sie
  /// bei einer anderen Firma desselben Kontos, wechselt der Server ohne
  /// Passwort. Kennt der Server sie nicht mehr: verwerfen, Passwort nötig.
  Future<void> _resume(SavedOnlineAccount account, String companyId) async {
    final membership = account.memberships.where((m) => m.companyId == companyId).firstOrNull;
    if (membership == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = _newClient(Uri.parse(account.serverUrl))..token = account.token;
    try {
      var expiresAt = account.expiresAt;
      if (account.sessionCompanyId != companyId) expiresAt = await client.switchCompany(companyId);
      await _openSession(client, membership, expiresAt, memberships: account.memberships);
    } on Exception catch (e) {
      if (e is ApiException && e.isUnauthorized) await _accounts.forgetSession(account.serverUrl, account.email);
      if (!mounted) return;
      setState(
        () => _error = e is ApiException && e.isUnauthorized
            ? 'Anmeldung abgelaufen — bitte das Passwort erneut eingeben.'
            : describeOnlineError(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Lädt den Offline-Bestand des Geräts (B2). Ist er nicht lesbar
  /// (Schlüssel verloren/Datei beschädigt), ist er wertlos — er wird
  /// entfernt und das ausdrücklich angezeigt.
  Future<void> _openOfflineStore() async {
    final store = widget.offlineStoreFactory != null
        ? widget.offlineStoreFactory!()
        : (offlineCacheSupported
              ? OfflineStore(
                  EncryptedOfflineVault(blobs: createDeviceOfflineBlobStore()!, keys: SecureOfflineKeyStore()),
                )
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
    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => OnlineHomeScreen(session: session)));
  }

  /// Server-Adresse und E-Mail der letzten Anmeldung vorbelegen — das
  /// Passwort wird bewusst nie gespeichert (angemeldet bleiben speichert
  /// nur das Sitzungs-Token, siehe `online_accounts.dart`).
  Future<void> _restoreLastInput() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (widget.account == null) {
        _serverCtrl.text = prefs.getString(_prefServerUrl) ?? '';
        _emailCtrl.text = prefs.getString(_prefEmail) ?? '';
        setState(() => _stayLoggedIn = prefs.getBool(_prefStayLoggedIn) ?? false);
      }
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
    final client = _newClient(url);
    try {
      final login = await client.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefServerUrl, _serverCtrl.text.trim());
        await prefs.setString(_prefEmail, _emailCtrl.text.trim());
        await prefs.setBool(_prefStayLoggedIn, _stayLoggedIn);
      } on Exception {
        // Merken ist Komfort, kein Muss.
      }
      // Firmen fürs nächste Mal auf der Startseite; eine alte gespeicherte
      // Sitzung gilt nach neuer Passwort-Eingabe nicht mehr.
      await _accounts.save(
        SavedOnlineAccount(serverUrl: url.toString(), email: _emailCtrl.text.trim(), memberships: login.memberships),
      );
      if (!mounted) return;
      setState(() {
        _client = client;
        _login = login;
      });
      final target = login.memberships.where((m) => m.companyId == widget.targetCompanyId).firstOrNull;
      if (target != null) await _selectCompany(target);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException && e.isUnauthorized ? 'E-Mail oder Passwort falsch.' : describeOnlineError(e),
      );
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

  Future<void> _register() => _accountAction((client) => client.register(_emailCtrl.text.trim(), _passwordCtrl.text));

  Future<void> _acceptInvitation() async {
    final code = await showOnlineTextPrompt(
      context,
      title: 'Einladung einlösen',
      label: 'Einladungscode',
      confirm: 'Einlösen',
      fieldKey: const Key('online-invitation-code'),
      intro:
          'Server, E-Mail und Passwort oben ausfüllen. Neue E-Mail: das Passwort wird dein neues. Bestehendes '
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
      final expiresAt = await client.selectCompany(_login!.identityToken, membership.companyId);
      await _openSession(client, membership, expiresAt, memberships: _login!.memberships);
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

  /// Rechte/Module laden, Offline-Bestand binden, Sitzung je nach
  /// „angemeldet bleiben“ merken oder verwerfen und den Online-Modus öffnen.
  Future<void> _openSession(
    WerkkernApiClient client,
    OnlineMembership membership,
    DateTime? expiresAt, {
    required List<OnlineMembership> memberships,
  }) async {
    final mine = await client.myPermissions();
    final modules = await client.modules();
    final serverUrl = _parseServerUrl()!;
    final email = _emailCtrl.text.trim();
    final account = SavedOnlineAccount(serverUrl: serverUrl.toString(), email: email, memberships: memberships);
    await _accounts.save(
      _stayLoggedIn && expiresAt != null
          ? account.withSession(token: client.token, companyId: membership.companyId, expiresAt: expiresAt)
          : account,
    );
    var offline = _offline;
    String? offlineWarning;
    if (offline != null) {
      try {
        await offline.bind(
          OfflineScope(
            serverUrl: serverUrl.toString(),
            email: _emailCtrl.text.trim(),
            companyId: membership.companyId,
            companyName: membership.companyName,
            permissions: mine.permissions,
            modules: modules,
          ),
        );
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
      expiresAt: expiresAt,
      onEnded: () => _accounts.forgetSession(account.serverUrl, account.email),
      keepSignedIn: _stayLoggedIn && expiresAt != null,
    );
    if (offlineWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offline-Funktion nicht verfügbar: $offlineWarning'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OnlineHomeScreen(
          session: session,
          expiredBuilder: (notice) => OnlineLoginScreen(
            clientFactory: widget.clientFactory,
            offlineStoreFactory: widget.offlineStoreFactory,
            accountStore: _accounts,
            account: account,
            targetCompanyId: membership.companyId,
            notice: notice,
          ),
        ),
      ),
    );
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
              if (widget.notice != null)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(leading: const Icon(Icons.lock_clock_outlined), title: Text(widget.notice!)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
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
                CheckboxListTile(
                  key: const Key('online-stay-logged-in'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _stayLoggedIn,
                  onChanged: _busy ? null : (v) => setState(() => _stayLoggedIn = v ?? false),
                  title: const Text('Angemeldet bleiben'),
                  subtitle: const Text(
                    '7 Tage ohne Passwort, danach erneut anmelden. Das Passwort selbst wird nicht gespeichert.',
                  ),
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
                      trailing: TextButton(
                        onPressed: _busy ? null : _openOffline,
                        child: const Text('Ohne Verbindung öffnen'),
                      ),
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
                      leading: Icon(m.suspended ? Icons.lock_outline : Icons.cloud_outlined),
                      title: Text(m.companyName),
                      subtitle: Text(
                        m.suspended
                            ? 'Gesperrt — bitte an den Anbieter wenden'
                            : (m.isAdmin ? '${m.groupName} · Admin' : m.groupName),
                      ),
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
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
