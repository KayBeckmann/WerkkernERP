import 'dart:convert';
import 'dart:math';

import 'api_client.dart';
import 'models.dart';

/// Ablage für den verschlüsselten Offline-Bestand (B2). Die App liefert
/// eine verschlüsselnde Implementierung (AES-GCM, gerätegebundener
/// Schlüssel); Tests nutzen [InMemoryOfflineVault].
abstract class OfflineVault {
  Future<String?> read();
  Future<void> write(String content);
  Future<void> clear();
}

class InMemoryOfflineVault implements OfflineVault {
  String? content;
  @override
  Future<String?> read() async => content;
  @override
  Future<void> write(String value) async => content = value;
  @override
  Future<void> clear() async => content = null;
}

/// Wem der Offline-Bestand gehört. Ein Abgleich ist nur mit genau
/// diesem Server/Konto/dieser Firma erlaubt — nie mit einer anderen.
class OfflineScope {
  const OfflineScope({required this.serverUrl, required this.email, required this.companyId, required this.companyName});
  factory OfflineScope.fromJson(Map<String, Object?> j) => OfflineScope(
        serverUrl: j['serverUrl'] as String,
        email: j['email'] as String,
        companyId: j['companyId'] as String,
        companyName: j['companyName'] as String,
      );
  final String serverUrl;
  final String email;
  final String companyId;
  final String companyName;

  bool matches(OfflineScope other) =>
      serverUrl == other.serverUrl && email.toLowerCase() == other.email.toLowerCase() && companyId == other.companyId;

  Map<String, Object?> toJson() => {'serverUrl': serverUrl, 'email': email, 'companyId': companyId, 'companyName': companyName};
}

enum OutboxStatus { pending, conflict, rejected }

/// Eine offline vorgenommene Entwurfsänderung, die noch zum Server muss.
/// [opId] dient als `Idempotency-Key`: wurde sie schon angewendet und
/// nur die Antwort ging verloren, wirkt die Wiederholung nicht doppelt.
class OutboxEntry {
  OutboxEntry({
    required this.opId,
    required this.documentId,
    required this.baseVersion,
    required this.items,
    required this.notes,
    required this.createdAt,
    this.attempted = false,
    this.status = OutboxStatus.pending,
    this.message,
  });

  factory OutboxEntry.fromJson(Map<String, Object?> j) => OutboxEntry(
        opId: j['opId'] as String,
        documentId: j['documentId'] as String,
        baseVersion: j['baseVersion'] as int,
        items: [for (final i in j['items'] as List) OnlineDocumentItem.fromJson(i as Map<String, Object?>)],
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        attempted: j['attempted'] as bool? ?? false,
        status: OutboxStatus.values.byName(j['status'] as String),
        message: j['message'] as String?,
      );

  final String opId;
  final String documentId;

  /// Version, auf der die Änderung beruht — der Server lehnt mit 409 ab,
  /// wenn inzwischen jemand anderes gespeichert hat (kein "last write wins").
  final int baseVersion;
  List<OnlineDocumentItem> items;
  String? notes;
  final DateTime createdAt;

  /// Schon mindestens einmal gesendet (Antwort evtl. verloren) — dann
  /// darf der Inhalt nicht mehr geändert werden (Idempotency-Key gehört
  /// zu genau diesem Inhalt).
  bool attempted;
  OutboxStatus status;
  String? message;

  Map<String, Object?> toJson() => {
        'opId': opId,
        'documentId': documentId,
        'baseVersion': baseVersion,
        'items': [for (final i in items) i.toJson()],
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'attempted': attempted,
        'status': status.name,
        'message': message,
      };
}

/// Selektiver Offline-Bestand (B2 Punkt 1): **nur ausdrücklich
/// markierte** Dokumente samt ihres Kunden — nie ein Abzug der ganzen
/// Firmendaten. Offline erlaubt ist ausschließlich das Bearbeiten von
/// Entwürfen; Finalisieren/Zahlung/Umwandlung brauchen den Server.
class OfflineStore {
  OfflineStore(this._vault);
  final OfflineVault _vault;

  OfflineScope? scope;
  final Map<String, Map<String, Object?>> _documents = {};
  final Map<String, OnlineCustomer> _customers = {};
  final List<OutboxEntry> outbox = [];

  static final _random = Random.secure();

  Future<void> load() async {
    final raw = await _vault.read();
    _documents.clear();
    _customers.clear();
    outbox.clear();
    scope = null;
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, Object?>;
    scope = j['scope'] == null ? null : OfflineScope.fromJson(j['scope'] as Map<String, Object?>);
    for (final d in (j['documents'] as Map<String, Object?>).entries) {
      _documents[d.key] = d.value as Map<String, Object?>;
    }
    for (final c in (j['customers'] as Map<String, Object?>).entries) {
      _customers[c.key] = OnlineCustomer.fromJson(c.value as Map<String, Object?>);
    }
    outbox.addAll([for (final o in j['outbox'] as List) OutboxEntry.fromJson(o as Map<String, Object?>)]);
  }

  Future<void> _save() => _vault.write(jsonEncode({
        'scope': scope?.toJson(),
        'documents': _documents,
        'customers': {for (final c in _customers.entries) c.key: {'id': c.value.id, ...c.value.toWriteJson()}},
        'outbox': [for (final o in outbox) o.toJson()],
      }));

  bool get isEmpty => _documents.isEmpty && outbox.isEmpty;
  bool isPinned(String documentId) => _documents.containsKey(documentId);
  List<OnlineDocument> get documents => [for (final d in _documents.values) OnlineDocument.fromJson(d)];
  OnlineDocument? document(String id) => _documents[id] == null ? null : OnlineDocument.fromJson(_documents[id]!);
  OnlineCustomer? customer(String id) => _customers[id];
  List<OutboxEntry> pendingFor(String documentId) => [for (final o in outbox) if (o.documentId == documentId) o];

  /// Bindet den Bestand an Server/Konto/Firma. Ein Bestand einer anderen
  /// Bindung wird nur ersetzt, wenn er keine offenen Änderungen enthält —
  /// sonst `StateError` (nie still verwerfen).
  Future<void> bind(OfflineScope newScope) async {
    final current = scope;
    if (current != null && !current.matches(newScope)) {
      if (outbox.isNotEmpty) {
        throw StateError(
          'Auf diesem Gerät liegen noch nicht übertragene Offline-Änderungen für "${current.companyName}" '
          '(${current.email}). Erst dort abgleichen oder ausdrücklich verwerfen.',
        );
      }
      await wipe();
    }
    scope = newScope;
    await _save();
  }

  /// Dokument (Server-JSON) + Kunde offline verfügbar machen.
  Future<void> pin(Map<String, Object?> documentJson, OnlineCustomer? customer) async {
    if (scope == null) throw StateError('Offline-Bestand ist keiner Firma zugeordnet.');
    _documents[documentJson['id'] as String] = documentJson;
    if (customer != null) _customers[customer.id] = customer;
    await _save();
  }

  /// Nicht möglich, solange noch Änderungen dieses Dokuments ausstehen.
  Future<void> unpin(String documentId) async {
    if (pendingFor(documentId).isNotEmpty) {
      throw StateError('Für dieses Dokument gibt es noch nicht übertragene Offline-Änderungen.');
    }
    final removed = _documents.remove(documentId);
    final customerId = removed?['customerId'];
    if (customerId != null && !_documents.values.any((d) => d['customerId'] == customerId)) {
      _customers.remove(customerId);
    }
    await _save();
  }

  /// Offline-Änderung eines markierten Entwurfs. Aktualisiert die lokale
  /// Kopie sofort; die Übertragung erfolgt mit [SyncService].
  Future<void> enqueueUpdate(String documentId, {required List<OnlineDocumentItem> items, String? notes}) async {
    final raw = _documents[documentId];
    if (raw == null) throw StateError('Dokument ist nicht offline verfügbar.');
    if (raw['status'] != 'draft') throw StateError('Finalisierte Dokumente sind unveränderlich.');
    final pending = pendingFor(documentId);
    final open = pending.where((o) => o.status == OutboxStatus.pending && !o.attempted).lastOrNull;
    if (open != null) {
      // Noch nie gesendet -> zusammenfassen statt Kette.
      open.items = items;
      open.notes = notes;
    } else {
      // Baut auf der davor liegenden (evtl. schon gesendeten) Änderung auf.
      final base = pending.isEmpty ? raw['version'] as int : pending.last.baseVersion + 1;
      outbox.add(OutboxEntry(
        opId: _newOpId(),
        documentId: documentId,
        baseVersion: base,
        items: items,
        notes: notes,
        createdAt: DateTime.now().toUtc(),
      ));
    }
    _documents[documentId] = {
      ...raw,
      'items': [for (final i in items) i.toJson()],
      'notes': notes,
    };
    await _save();
  }

  /// Verwirft eine offene/abgewiesene Änderung und ersetzt die lokale
  /// Kopie bei nächster Gelegenheit durch den Serverstand.
  Future<void> discard(String opId) async {
    outbox.removeWhere((o) => o.opId == opId);
    await _save();
  }

  /// Löscht den gesamten Offline-Bestand (Abmelden mit "Daten
  /// entfernen", Rechte entzogen, Gerät weitergegeben).
  Future<void> wipe() async {
    _documents.clear();
    _customers.clear();
    outbox.clear();
    scope = null;
    await _vault.clear();
  }

  Future<void> _replaceDocument(Map<String, Object?> json) async {
    _documents[json['id'] as String] = json;
    await _save();
  }

  Future<void> _dropDocument(String id) async {
    _documents.remove(id);
    outbox.removeWhere((o) => o.documentId == id && o.status == OutboxStatus.pending);
    await _save();
  }

  Future<void> _persist() => _save();

  static String _newOpId() =>
      List<int>.generate(16, (_) => _random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class SyncResult {
  SyncResult();
  int sent = 0;
  int refreshed = 0;

  /// Vom Server abgelehnt, weil inzwischen anders gespeichert (409).
  final List<OutboxEntry> conflicts = [];

  /// Recht entzogen, Dokument gelöscht oder finalisiert (403/404/409-final).
  final List<OutboxEntry> rejected = [];

  /// Dokumente, deren lokale Kopie entfernt wurde, weil der Server den
  /// Zugriff nicht mehr erlaubt (widerrufene Mitgliedschaft/Rechte).
  final List<String> revoked = [];
  bool needsLogin = false;
  bool unreachable = false;

  bool get clean => conflicts.isEmpty && rejected.isEmpty && !needsLogin && !unreachable;
}

/// Abgleich Outbox -> Server und Server -> markierte Dokumente.
/// Server entscheidet bei Rückkehr online neu über jedes Recht (B2
/// Punkt 2); nichts wird still überschrieben.
class SyncService {
  const SyncService();

  Future<SyncResult> sync(WerkkernApiClient client, OfflineStore store) async {
    final result = SyncResult();
    // Dokumente, deren frühere Änderung abgelehnt wurde/offen strittig
    // ist: darauf aufbauende Änderungen werden NICHT gesendet — sonst
    // könnte eine Folgeänderung zufällig zur fremden Version passen und
    // sie doch still überschreiben.
    final blocked = <String>{
      for (final o in store.outbox)
        if (o.status != OutboxStatus.pending) o.documentId,
    };
    for (final entry in [...store.outbox]) {
      if (entry.status != OutboxStatus.pending) continue;
      if (blocked.contains(entry.documentId)) {
        entry
          ..status = OutboxStatus.conflict
          ..message = 'Baut auf einer abgelehnten Offline-Änderung auf.';
        result.conflicts.add(entry);
        await store._persist();
        continue;
      }
      entry.attempted = true;
      await store._persist();
      try {
        final updated = await client.updateDocument(
          id: entry.documentId,
          version: entry.baseVersion,
          items: entry.items,
          notes: entry.notes,
          idempotencyKey: entry.opId,
        );
        store.outbox.remove(entry);
        result.sent++;
        if (store.isPinned(entry.documentId)) await store._replaceDocument(updated.rawJson);
      } on ApiUnreachable {
        result.unreachable = true;
        return result;
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          result.needsLogin = true;
          return result;
        }
        blocked.add(entry.documentId);
        if (e.isConflict && !e.message.contains('finalisiert')) {
          entry
            ..status = OutboxStatus.conflict
            ..message = e.message;
          result.conflicts.add(entry);
        } else {
          entry
            ..status = OutboxStatus.rejected
            ..message = e.message;
          result.rejected.add(entry);
        }
        await store._persist();
      }
    }

    // Markierte Dokumente ohne offene Änderungen auf Serverstand bringen.
    for (final document in store.documents) {
      if (store.pendingFor(document.id).isNotEmpty) continue;
      try {
        final fresh = await client.documentJson(document.id);
        await store._replaceDocument(fresh);
        result.refreshed++;
      } on ApiUnreachable {
        result.unreachable = true;
        return result;
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          result.needsLogin = true;
          return result;
        }
        if (e.isForbidden || e.statusCode == 404) {
          // Zugriff entzogen oder gelöscht -> lokale Kopie entfernen.
          await store._dropDocument(document.id);
          result.revoked.add(document.id);
        }
      }
    }
    return result;
  }
}
