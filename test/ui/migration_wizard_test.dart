import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/data/backup/backup_service.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/domain/services/active_company_service.dart';
import 'package:werkkernerp/domain/services/online_accounts.dart';
import 'package:werkkernerp/ui/screens/company_switcher_screen.dart';
import 'package:werkkernerp/ui/screens/migration_wizard_screen.dart';

import 'online/online_test_server.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

/// In Tests gibt es keinen Plattform-Dateiordner — Sicherung auslassen.
class _NoBackup extends BackupService {
  _NoBackup(super.db);
  @override
  bool get isSupported => false;
}

/// Offline-Firma mit finalisierter Rechnung, Entwurf, Rolle und zwei
/// Zeitbuchungen (eine ohne Rolle).
Future<Company> _seed(AppDatabase db) async {
  final now = DateTime(2026, 3, 2, 9);
  await db.into(db.companies).insert(CompaniesCompanion.insert(
        id: 'co',
        name: 'Elektro Kay',
        createdAt: now,
        iban: const Value('DE02120300000000202051'),
        timeTrackingEnabled: const Value(true),
      ));
  await db.into(db.customers).insert(CustomersCompanion.insert(id: 'c1', companyId: 'co', name: 'Meyer', createdAt: now));
  await db.into(db.invoices).insert(InvoicesCompanion.insert(
        id: 'r1',
        companyId: 'co',
        customerId: 'c1',
        status: InvoiceStatus.finalized,
        invoiceNumber: const Value('R-26007'),
        numberYear: const Value(2026),
        issueDate: now,
        serviceDate: now,
        customerSnapshotName: const Value('Meyer'),
        companySnapshotName: const Value('Elektro Kay'),
        finalizedAt: Value(now),
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.invoices).insert(InvoicesCompanion.insert(
        id: 'r2',
        companyId: 'co',
        customerId: 'c1',
        status: InvoiceStatus.draft,
        issueDate: now,
        serviceDate: now,
        createdAt: now,
        updatedAt: now,
      ));
  for (final (id, invoice) in [('i1', 'r1'), ('i2', 'r2')]) {
    await db.into(db.invoiceItems).insert(InvoiceItemsCompanion.insert(
          id: id,
          invoiceId: invoice,
          kind: InvoiceItemKind.hours,
          description: 'Montage',
          quantity: '2',
          unitPriceCents: 6500,
          vatRatePercent: 19,
          sortOrder: 0,
        ));
  }
  await db.into(db.numberSequences).insert(
        NumberSequencesCompanion.insert(companyId: 'co', documentType: 'invoice', year: 2026, lastNumber: const Value(7)),
      );
  await db.into(db.staffRoles).insert(StaffRolesCompanion.insert(
        id: 'role1',
        companyId: 'co',
        name: 'Monteur',
        createdAt: now,
        hourlyCostRateCents: const Value(4500),
      ));
  await db.into(db.timeEntries).insert(TimeEntriesCompanion.insert(
        id: 't1',
        companyId: 'co',
        date: now,
        hours: 2,
        createdAt: now,
        staffRoleId: const Value('role1'),
        invoiceId: const Value('r1'),
      ));
  await db.into(db.timeEntries).insert(TimeEntriesCompanion.insert(id: 't2', companyId: 'co', date: now, hours: 1.5, createdAt: now));
  return (await (db.select(db.companies)..where((c) => c.id.equals('co'))).getSingle());
}

Widget _app(AppDatabase db, Widget home) => MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<CompanyRepository>(create: (_) => CompanyRepository(db)),
        Provider<NumberSequenceRepository>(create: (_) => NumberSequenceRepository(db)),
        Provider<InvoiceRepository>(create: (c) => InvoiceRepository(db, c.read<NumberSequenceRepository>())),
        Provider<BackupService>(create: (_) => _NoBackup(db)),
        ChangeNotifierProvider<ActiveCompanyService>(create: (c) => ActiveCompanyService(c.read<CompanyRepository>())),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Umzug: Warnhinweis, Konto + neue Firma, Rollen zuordnen, Probelauf, Umzug; danach Archiv', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = _db();
    addTearDown(db.close);
    final server = OnlineTestServer();
    final store = MemoryOnlineAccountStore();
    final company = (await tester.runAsync(() => _seed(db)))!;

    await tester.pumpWidget(_app(
      db,
      MigrationWizardScreen(
        company: company,
        clientFactory: (_) => server.client(),
        accountStore: store,
        offlineStoreFactory: () => null,
      ),
    ));
    await tester.pumpAndSettle();

    // Warnhinweis muss ausdrücklich bestätigt werden.
    expect(find.text('Es gibt kein Zurück zur Offline-Variante'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Weiter')).onPressed, isNull);
    await tester.tap(find.byKey(const Key('migration-ack')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
    await tester.pumpAndSettle();

    // Konto registrieren, neue Online-Firma (Name vorbelegt).
    await tester.enterText(find.byKey(const Key('migration-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('migration-password')), 'passwort-12345');
    await tester.tap(find.text('Neues Konto registrieren'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Elektro Kay'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('migration-company-name')), 'Elektro Kay GmbH');
    await tester.tap(find.text('Firma anlegen und weiter'));
    await tester.pumpAndSettle();

    // Beide Rollen (mit Rolle + ohne Rolle) brauchen ein Mitglied; vorbelegt mit dem eigenen Konto.
    expect(find.text('Monteur (1 Buchungen)'), findsOneWidget);
    expect(find.text('Ohne Rolle (1 Buchungen)'), findsOneWidget);
    await tester.tap(find.text('Prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Dokumente'), findsOneWidget);
    expect(find.text('Zeitbuchungen'), findsOneWidget);

    await tester.tap(find.byKey(const Key('migration-start')));
    await tester.pumpAndSettle();
    expect(find.text('Endgültig umziehen?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('migration-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Umzug abgeschlossen'), findsOneWidget);

    // Lokal: Firma als umgezogen markiert. Online: Daten unverändert da.
    final migrated = await tester.runAsync(() => (db.select(db.companies)..where((c) => c.id.equals('co'))).getSingle());
    expect(migrated!.migratedAt, isNotNull);
    expect(migrated.migratedToCompanyName, 'Elektro Kay GmbH');
    final accounts = (await tester.runAsync(store.load))!;
    final membership = accounts.single.memberships.single;
    expect(membership.companyName, 'Elektro Kay GmbH');
    final export = await tester.runAsync(() async {
      final client = server.client();
      final login = await client.login('kay@example.com', 'passwort-12345');
      await client.selectCompany(login.identityToken, membership.companyId);
      return client.exportCompanyData();
    });
    final documents = (export!['documents']! as List).cast<Map<String, Object?>>();
    expect(documents.map((d) => d['number']), containsAll(['R-26007', null]));
    expect(((export['company']! as Map)['iban']), 'DE02120300000000202051');
    expect(export['timeEntries'], hasLength(2));
    expect(((export['staffRoles']! as List).single as Map)['hourlyCostCents'], 4500);

    // Direkt weiter in die Online-Firma (gemerkte Sitzung, kein Passwort).
    await tester.tap(find.text('Zur Online-Firma'));
    await tester.pumpAndSettle();
    expect(find.text('Elektro Kay GmbH · online'), findsOneWidget);
    expect(find.text('Rechnungen'), findsWidgets);
  });

  testWidgets('Umgezogene Firma öffnet nur noch als Archiv (ohne Wiederherstellen)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = _db();
    addTearDown(db.close);
    await tester.runAsync(() async {
      await _seed(db);
      await CompanyRepository(db).markMigrated('co', server: 'https://erp.example.org/api', companyName: 'Elektro Kay GmbH');
    });

    await tester.pumpWidget(_app(db, CompanySwitcherScreen(accountStore: MemoryOnlineAccountStore())));
    await tester.pumpAndSettle();
    expect(find.text('Umgezogen nach „Elektro Kay GmbH“ · nur lesen'), findsOneWidget);
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();

    expect(find.text('Elektro Kay (Archiv)'), findsOneWidget);
    expect(find.text('R-26007 · Meyer'), findsOneWidget);
    expect(find.text('Zur Online-Firma'), findsOneWidget);
    await tester.tap(find.text('Sicherung erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Backup erstellen'), findsOneWidget);
    expect(find.text('Backup wiederherstellen'), findsNothing);
  });
}
