import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'models.dart';
import 'login_throttle.dart';
import 'repository.dart';
import 'util/passwords.dart';
import 'util/responses.dart';
import 'util/tokens.dart';

/// Meldung für Nutzer einer gesperrten Firma (Login, Firmenwahl).
const companySuspendedMessage = 'Diese Firma ist gesperrt. Bitte wende dich an den Anbieter.';

/// Superadmin-Panel (SaaS-Betrieb): Firmen auflisten, Abo pflegen,
/// sperren/entsperren. Eigene Anmeldung und eigene Sitzungen, getrennt
/// von den Firmensitzungen. Superadmin wird man nur über
/// `bin/platform_admin.dart` mit direktem DB-Zugriff — kein
/// Netzwerkpfad, um sich selbst hochzustufen (wie die Admin-Recovery).
///
/// Bewusst nur Firmenstammdaten, Mitgliederzahl und Admin-E-Mails —
/// keine Fachdaten (ADR-0001 B0.5).
class PlatformRoutes {
  PlatformRoutes({
    required this.repository,
    required this.loginThrottle,
    required this.clientAddress,
    this.sessionTtl = const Duration(hours: 8),
  });

  final PhaseBRepository repository;
  final LoginThrottle loginThrottle;
  final String? Function(Request request) clientAddress;
  final Duration sessionTtl;

  void mount(Router router) {
    router.post('/platform/login', _login);
    router.post('/platform/logout', _logout);
    router.get('/platform/me', _me);
    router.get('/platform/companies', _listCompanies);
    router.put('/platform/companies/<id>/billing', _setBilling);
    router.post('/platform/companies/<id>/suspend', _suspend);
    router.post('/platform/companies/<id>/resume', _resume);
  }

  Future<Map<String, Object?>> _bodyJson(Request request) async {
    final raw = await request.readAsString();
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) throw const FormatException('JSON-Objekt erwartet');
    return decoded;
  }

  String? _bearer(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  /// Prüft bei jedem Aufruf erneut, ob der Nutzer noch Superadmin ist —
  /// Entzug wirkt sofort.
  Future<PlatformSession?> _requirePlatform(Request request) async {
    final token = _bearer(request);
    if (token == null) return null;
    final session = await repository.findPlatformSession(Tokens.hashOf(token));
    if (session == null) return null;
    if (session.isExpired(DateTime.now().toUtc())) {
      await repository.deletePlatformSession(session.tokenHash);
      return null;
    }
    if (!await repository.isPlatformAdmin(session.userId)) return null;
    return session;
  }

  Future<Response> _login(Request request) async {
    final body = await _bodyJson(request);
    final email = (body['email'] as String?)?.trim();
    final password = body['password'] as String?;
    if (email == null || password == null) return jsonError('email und password sind Pflicht.');
    // Eigener Schlüssel: Fehlversuche im Panel sperren nicht das App-Konto.
    final account = 'platform:$email';
    final wait = loginThrottle.blockedFor(account: account, address: clientAddress(request));
    if (wait != null) {
      final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
      return jsonOk(
        {'error': 'Zu viele Fehlversuche — bitte in ${(seconds / 60).ceil()} Minute(n) erneut versuchen.'},
        status: 429,
      ).change(headers: {'retry-after': '$seconds'});
    }
    final user = await repository.findUserByEmail(email);
    // Gleiche Antwort für falsches Passwort und fehlende Berechtigung —
    // kein Hinweis, welche Konten Superadmin sind.
    if (user == null || !Passwords.verify(password, user.passwordHash) || !await repository.isPlatformAdmin(user.id)) {
      loginThrottle.recordFailure(account: account, address: clientAddress(request));
      return jsonError('E-Mail oder Passwort falsch, oder kein Zugang zur Plattform-Verwaltung.', status: 401);
    }
    loginThrottle.recordSuccess(account: account);
    final raw = Tokens.generate();
    final expiresAt = DateTime.now().toUtc().add(sessionTtl);
    await repository.savePlatformSession(PlatformSession(tokenHash: Tokens.hashOf(raw), userId: user.id, expiresAt: expiresAt));
    return jsonOk({'token': raw, 'expiresAt': expiresAt.toIso8601String(), 'email': user.email});
  }

  Future<Response> _logout(Request request) async {
    final token = _bearer(request);
    if (token != null) await repository.deletePlatformSession(Tokens.hashOf(token));
    return Response(204);
  }

  Future<Response> _me(Request request) async {
    final session = await _requirePlatform(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final user = await repository.findUserById(session.userId);
    return jsonOk({'email': user?.email, 'expiresAt': session.expiresAt.toIso8601String()});
  }

  Map<String, Object?> _companyJson(PlatformCompany p, DateTime now) {
    final s = p.subscription;
    return {
      'id': p.company.id,
      'name': p.company.name,
      'createdAt': p.createdAt.toIso8601String(),
      'activeMembers': p.activeMembers,
      'adminEmails': p.adminEmails,
      'plan': s.plan,
      'paidUntil': s.paidUntil == null ? null : _date(s.paidUntil!),
      'note': s.note,
      'overdue': s.isOverdue(now),
      'suspended': s.suspended,
      'suspendedAt': s.suspendedAt?.toIso8601String(),
      'suspendReason': s.suspendReason,
    };
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Response> _listCompanies(Request request) async {
    final session = await _requirePlatform(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final now = DateTime.now().toUtc();
    final companies = await repository.listPlatformCompanies();
    return jsonOk({'companies': [for (final c in companies) _companyJson(c, now)]});
  }

  Future<PlatformCompany?> _find(String id) async =>
      (await repository.listPlatformCompanies()).where((c) => c.company.id == id).firstOrNull;

  Future<void> _audit(PlatformSession session, String companyId, String action) => repository.recordAudit(AuditEntry(
        companyId: companyId,
        userId: session.userId,
        action: action,
        entityType: 'company',
        entityId: companyId,
        at: DateTime.now().toUtc(),
      ));

  String? _text(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Ersetzt Tarif, „bezahlt bis“ (YYYY-MM-DD oder null) und Notiz.
  Future<Response> _setBilling(Request request, String id) async {
    final session = await _requirePlatform(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    if (await repository.findCompanyById(id) == null) return jsonError('Firma nicht gefunden.', status: 404);
    final body = await _bodyJson(request);
    DateTime? paidUntil;
    final rawDate = _text(body['paidUntil']);
    if (rawDate != null) {
      final parsed = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(rawDate);
      if (parsed == null) return jsonError('paidUntil als YYYY-MM-DD angeben.');
      paidUntil = DateTime.utc(int.parse(parsed[1]!), int.parse(parsed[2]!), int.parse(parsed[3]!));
    }
    final current = await repository.getSubscription(id);
    await repository.saveSubscription(
      current.withBilling(plan: _text(body['plan']), paidUntil: paidUntil, note: _text(body['note'])),
    );
    await _audit(session, id, 'platform.billing');
    return jsonOk(_companyJson((await _find(id))!, DateTime.now().toUtc()));
  }

  /// Sperrt die Firma komplett: neue Anmeldungen scheitern, laufende
  /// App-Sitzungen enden sofort, Agent-Token wirken nicht mehr.
  Future<Response> _suspend(Request request, String id) async {
    final session = await _requirePlatform(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    if (await repository.findCompanyById(id) == null) return jsonError('Firma nicht gefunden.', status: 404);
    final reason = _text((await _bodyJson(request))['reason']);
    final current = await repository.getSubscription(id);
    if (!current.suspended) {
      await repository.saveSubscription(current.withSuspension(DateTime.now().toUtc(), reason));
    } else if (reason != null) {
      await repository.saveSubscription(current.withSuspension(current.suspendedAt, reason));
    }
    await repository.deleteSessionsForCompany(id);
    await _audit(session, id, 'platform.suspend');
    return jsonOk(_companyJson((await _find(id))!, DateTime.now().toUtc()));
  }

  Future<Response> _resume(Request request, String id) async {
    final session = await _requirePlatform(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    if (await repository.findCompanyById(id) == null) return jsonError('Firma nicht gefunden.', status: 404);
    final current = await repository.getSubscription(id);
    await repository.saveSubscription(current.withSuspension(null, null));
    await _audit(session, id, 'platform.resume');
    return jsonOk(_companyJson((await _find(id))!, DateTime.now().toUtc()));
  }
}
