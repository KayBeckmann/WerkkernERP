import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';

/// Ein auf diesem Gerät bekanntes Online-Konto (Server + E-Mail) mit den
/// Firmen der letzten Anmeldung — Grundlage der Online-Einträge auf der
/// Startseite. Das Passwort wird nie gespeichert; bei „angemeldet
/// bleiben“ liegt nur das Sitzungs-Token des Servers hier, das nach
/// 7 Tagen abläuft (Kay-Entscheidung 2026-11-01).
class SavedOnlineAccount {
  const SavedOnlineAccount({
    required this.serverUrl,
    required this.email,
    required this.memberships,
    this.token,
    this.sessionCompanyId,
    this.expiresAt,
  });

  factory SavedOnlineAccount.fromJson(Map<String, Object?> j) => SavedOnlineAccount(
        serverUrl: j['serverUrl'] as String,
        email: j['email'] as String,
        memberships: [
          for (final m in j['memberships'] as List) OnlineMembership.fromJson((m as Map).cast<String, Object?>()),
        ],
        token: j['token'] as String?,
        sessionCompanyId: j['sessionCompanyId'] as String?,
        expiresAt: j['expiresAt'] == null ? null : DateTime.parse(j['expiresAt'] as String),
      );

  final String serverUrl;
  final String email;
  final List<OnlineMembership> memberships;

  /// Sitzungs-Token für [sessionCompanyId] — nur bei „angemeldet bleiben“.
  final String? token;
  final String? sessionCompanyId;
  final DateTime? expiresAt;

  String get key => '$serverUrl|$email';

  /// Gespeicherte Sitzung, die laut Ablaufdatum noch gilt. Ob der Server
  /// sie noch kennt (z. B. nach Passwortänderung), zeigt erst der Aufruf.
  bool hasSessionAt(DateTime now) =>
      token != null && sessionCompanyId != null && expiresAt != null && now.toUtc().isBefore(expiresAt!);

  SavedOnlineAccount withSession({String? token, String? companyId, DateTime? expiresAt}) => SavedOnlineAccount(
        serverUrl: serverUrl,
        email: email,
        memberships: memberships,
        token: token,
        sessionCompanyId: token == null ? null : companyId,
        expiresAt: token == null ? null : expiresAt,
      );

  SavedOnlineAccount withMemberships(List<OnlineMembership> memberships) => SavedOnlineAccount(
        serverUrl: serverUrl,
        email: email,
        memberships: memberships,
        token: token,
        sessionCompanyId: sessionCompanyId,
        expiresAt: expiresAt,
      );

  Map<String, Object?> toJson() => {
        'serverUrl': serverUrl,
        'email': email,
        'memberships': [
          for (final m in memberships)
            {'companyId': m.companyId, 'companyName': m.companyName, 'groupName': m.groupName, 'isAdmin': m.isAdmin},
        ],
        if (token != null) 'token': token,
        if (sessionCompanyId != null) 'sessionCompanyId': sessionCompanyId,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };
}

/// Ablage der bekannten Online-Konten. Abstrakt, damit Tests ohne
/// Secure-Storage-Plattformkanal auskommen. Fehler beim Lesen/Schreiben
/// sind nie fatal: ohne Ablage meldet man sich eben jedes Mal an.
/// Meldet jede Änderung, damit die Startseite z. B. nach dem Abmelden
/// aktuell ist.
abstract class OnlineAccountStore extends ChangeNotifier {
  Future<String?> readRaw();
  Future<void> writeRaw(String value);

  /// Abgelaufene Sitzungen werden beim Laden verworfen.
  Future<List<SavedOnlineAccount>> load() async {
    try {
      final raw = await readRaw();
      if (raw == null) return [];
      final now = DateTime.now();
      final accounts = [
        for (final a in jsonDecode(raw) as List) SavedOnlineAccount.fromJson((a as Map).cast<String, Object?>()),
      ];
      return [for (final a in accounts) a.token == null || a.hasSessionAt(now) ? a : a.withSession()];
    } on Object {
      return [];
    }
  }

  Future<SavedOnlineAccount?> find(String serverUrl, String email) async {
    for (final a in await load()) {
      if (a.serverUrl == serverUrl && a.email == email) return a;
    }
    return null;
  }

  /// Ersetzt das Konto mit gleichem Server + E-Mail (oder legt es an).
  Future<void> save(SavedOnlineAccount account) async {
    final others = [for (final a in await load()) if (a.key != account.key) a];
    await _write([account, ...others]);
  }

  /// Gespeicherte Sitzung verwerfen — Firmen bleiben auf der Startseite.
  Future<void> forgetSession(String serverUrl, String email) async {
    final account = await find(serverUrl, email);
    if (account != null) await save(account.withSession());
  }

  /// Eine Firma von der Startseite entfernen; ohne verbleibende Firma
  /// verschwindet das Konto samt Sitzung.
  Future<void> removeCompany(SavedOnlineAccount account, String companyId) async {
    final rest = [for (final m in account.memberships) if (m.companyId != companyId) m];
    final others = [for (final a in await load()) if (a.key != account.key) a];
    await _write([if (rest.isNotEmpty) account.withMemberships(rest), ...others]);
  }

  Future<void> _write(List<SavedOnlineAccount> accounts) async {
    try {
      await writeRaw(jsonEncode([for (final a in accounts) a.toJson()]));
    } on Object {
      // Merken ist Komfort, kein Muss.
    }
    notifyListeners();
  }
}

/// Standard-Ablage der Plattform: Android Keystore; im Web der normale
/// Browser-Speicher. Grund: Secure Storage braucht im Web WebCrypto, das
/// Browser nur über HTTPS oder `localhost` freigeben — über
/// `http://<LAN-IP>` scheiterte jedes Speichern still, die Startseite
/// blieb leer (Kay-Feedback 2026-11-01). Echten Schutz bietet es im Web
/// ohnehin nicht (der Schlüssel läge im selben Browser-Speicher).
OnlineAccountStore defaultOnlineAccountStore() => kIsWeb ? PrefsOnlineAccountStore() : SecureOnlineAccountStore();

class PrefsOnlineAccountStore extends OnlineAccountStore {
  static const _key = 'online.accounts';

  @override
  Future<String?> readRaw() async => (await SharedPreferences.getInstance()).getString(_key);
  @override
  Future<void> writeRaw(String value) async => (await SharedPreferences.getInstance()).setString(_key, value);
}

/// Android Keystore — wie das SMTP-Passwort.
class SecureOnlineAccountStore extends OnlineAccountStore {
  SecureOnlineAccountStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'online_accounts';

  @override
  Future<String?> readRaw() => _storage.read(key: _key);
  @override
  Future<void> writeRaw(String value) => _storage.write(key: _key, value: value);
}

class MemoryOnlineAccountStore extends OnlineAccountStore {
  String? value;
  @override
  Future<String?> readRaw() async => value;
  @override
  Future<void> writeRaw(String value) async => this.value = value;
}
