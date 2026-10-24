import 'package:uuid/uuid.dart';

import 'repository.dart';

/// Erstadmin-Recovery (Roadmap B1 Punkt 2: "Erstadmin/Recovery offen").
///
/// **Technische Vorgabe, keine fachliche Freigabe:** Recovery ist
/// bewusst **kein** API-Endpunkt, sondern nur über `bin/recover_admin.dart`
/// mit direktem Datenbankzugriff möglich — wer den Server betreibt
/// (Kay beim Managed-Hosting bzw. der Self-Hosting-Betreiber), kann
/// ohnehin direkt in die Datenbank schreiben; ein zusätzlicher
/// Netzwerk-Pfad würde nur neue Angriffsfläche schaffen (gleiches
/// Prinzip wie ADR-0001 B0.5: "kein impliziter globaler Zugriff, auch
/// nicht für den Betreiber-Account").
///
/// Macht einen **bereits registrierten** Nutzer zum aktiven Admin der
/// Firma: vorhandene Mitgliedschaft wird reaktiviert + Admin, sonst neu
/// in der ersten Gruppe der Firma angelegt.
Future<String> recoverCompanyAdmin(
  PhaseBRepository repository, {
  required String email,
  required String companyId,
}) async {
  final user = await repository.findUserByEmail(email);
  if (user == null) {
    throw StateError('Kein registrierter Nutzer mit E-Mail $email — zuerst über /auth/register anlegen.');
  }
  final company = await repository.findCompanyById(companyId);
  if (company == null) throw StateError('Firma $companyId existiert nicht.');

  final existing = await repository.findMembership(userId: user.id, companyId: companyId);
  if (existing != null) {
    await repository.updateMembership(id: existing.id, active: true, isAdmin: true);
    return 'Mitgliedschaft ${existing.id} von $email in "${company.name}" reaktiviert und zum Admin gemacht.';
  }

  final groups = await repository.listGroupsForCompany(companyId);
  if (groups.isEmpty) throw StateError('Firma "${company.name}" hat keine Gruppe — Recovery nicht möglich.');
  final membership = await repository.createMembership(
    id: const Uuid().v4(),
    userId: user.id,
    companyId: companyId,
    groupId: groups.first.id,
    isAdmin: true,
  );
  return 'Neue Admin-Mitgliedschaft ${membership.id} für $email in "${company.name}" '
      '(Gruppe "${groups.first.name}") angelegt.';
}
