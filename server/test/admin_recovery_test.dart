import 'package:test/test.dart';
import 'package:werkkernerp_server/src/admin_recovery.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';

void main() {
  late InMemoryPhaseBRepository repository;

  setUp(() async {
    repository = InMemoryPhaseBRepository();
    await repository.createUser(id: 'u1', email: 'chef@example.com', passwordHash: 'x');
    await repository.createUser(id: 'u2', email: 'neu@example.com', passwordHash: 'x');
    await repository.createCompany(id: 'c1', name: 'Firma A');
    await repository.createGroup(id: 'g1', companyId: 'c1', name: 'Projektleiter');
  });

  test('Deaktivierter einziger Admin wird reaktiviert und bleibt Admin', () async {
    await repository.createMembership(id: 'm1', userId: 'u1', companyId: 'c1', groupId: 'g1', isAdmin: true);
    await repository.updateMembership(id: 'm1', active: false);
    expect(await repository.countActiveAdmins('c1'), 0);

    await recoverCompanyAdmin(repository, email: 'chef@example.com', companyId: 'c1');
    expect(await repository.countActiveAdmins('c1'), 1);
  });

  test('Nutzer ohne Mitgliedschaft bekommt eine neue Admin-Mitgliedschaft', () async {
    await recoverCompanyAdmin(repository, email: 'neu@example.com', companyId: 'c1');
    final membership = await repository.findMembership(userId: 'u2', companyId: 'c1');
    expect(membership?.isAdmin, isTrue);
    expect(membership?.active, isTrue);
  });

  test('Unbekannte E-Mail oder Firma wird abgewiesen, nichts wird angelegt', () async {
    expect(() => recoverCompanyAdmin(repository, email: 'gibtsnicht@example.com', companyId: 'c1'), throwsStateError);
    expect(() => recoverCompanyAdmin(repository, email: 'chef@example.com', companyId: 'c999'), throwsStateError);
    expect(await repository.listMembershipsForCompany('c1'), isEmpty);
  });
}
