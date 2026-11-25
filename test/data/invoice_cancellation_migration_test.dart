import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';

void main() {
  test('Version 44 migriert auf 45 und erhält bestehende Daten', () async {
    final dir = await Directory.systemTemp.createTemp('werkkern-cancellation-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.sqlite');
    final before = AppDatabase.forTesting(NativeDatabase(file));
    final company = await CompanyRepository(before).create(name: 'Bestandsfirma');
    await before.customStatement('ALTER TABLE invoices DROP COLUMN is_cancellation');
    await before.customStatement('PRAGMA user_version = 44');
    await before.close();
    final after = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(after.close);
    expect((await after.select(after.companies).get()).single.id, company.id);
    final columns = await after.customSelect('PRAGMA table_info(invoices)').get();
    expect(columns.any((c) => c.read<String>('name') == 'is_cancellation'), isTrue);
    expect(
      (await after.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version'),
      after.schemaVersion,
    );
  });
}
