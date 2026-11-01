import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/domain/services/online_accounts.dart';

void main() {
  const a = OnlineMembership(companyId: 'a', companyName: 'Firma A', groupName: 'Projektleiter', isAdmin: true);
  const b = OnlineMembership(companyId: 'b', companyName: 'Firma B', groupName: 'Monteur', isAdmin: false);

  SavedOnlineAccount account({DateTime? expiresAt}) => const SavedOnlineAccount(
        serverUrl: 'https://erp.example.org',
        email: 'kay@example.com',
        memberships: [a, b],
      ).withSession(token: 't', companyId: 'a', expiresAt: expiresAt);

  test('Abgelaufene Sitzung wird beim Laden verworfen, die Firmen bleiben', () async {
    final store = MemoryOnlineAccountStore();
    await store.save(account(expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1))));
    final loaded = (await store.load()).single;
    expect(loaded.token, isNull);
    expect(loaded.memberships.map((m) => m.companyName), ['Firma A', 'Firma B']);

    await store.save(account(expiresAt: DateTime.now().toUtc().add(const Duration(days: 7))));
    expect((await store.load()).single.hasSessionAt(DateTime.now()), isTrue);
  });

  test('Firma entfernen; ohne verbleibende Firma verschwindet das Konto samt Sitzung', () async {
    final store = MemoryOnlineAccountStore();
    await store.save(account(expiresAt: DateTime.now().toUtc().add(const Duration(days: 7))));
    await store.removeCompany((await store.load()).single, 'a');
    expect((await store.load()).single.memberships.single.companyId, 'b');
    await store.removeCompany((await store.load()).single, 'b');
    expect(await store.load(), isEmpty);
  });

  test('Unlesbare Ablage ist nie fatal', () async {
    final store = MemoryOnlineAccountStore()..value = 'kaputt';
    expect(await store.load(), isEmpty);
  });
}
