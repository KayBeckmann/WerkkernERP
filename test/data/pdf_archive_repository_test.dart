import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:werkkernerp/data/backup/backup_service.dart';
import 'package:werkkernerp/data/backup/backup_encryption.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/pdf_archive_repository.dart';

class _TempPaths extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _TempPaths();
  test('global archive lists only the selected company across source kinds', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final company = await CompanyRepository(db).create(name: 'First');
    final other = await CompanyRepository(db).create(name: 'Second');
    final archive = PdfArchiveRepository(db);
    await archive.storeGenerated(companyId: company.id, sourceType: PdfArchiveSource.customerDocument,
        sourceId: 'invoice', bytes: Uint8List.fromList([1]));
    await archive.storeGenerated(companyId: company.id, sourceType: PdfArchiveSource.purchaseOrder,
        sourceId: 'order', bytes: Uint8List.fromList([2]));
    await archive.storeGenerated(companyId: other.id, sourceType: PdfArchiveSource.signedTimeSheet,
        sourceId: 'private', bytes: Uint8List.fromList([3]));
    expect((await archive.listAll(companyId: company.id)).map((a) => a.sourceId).toSet(), {'invoice', 'order'});
    expect((await archive.listAll(companyId: other.id)).map((a) => a.sourceId), ['private']);
  });
  test('generated PDFs have independent source versions and immutable exact bytes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final company = await CompanyRepository(db).create(name: 'Archive test');
    final repo = PdfArchiveRepository(db);
    final first = await repo.storeGenerated(
      companyId: company.id, sourceType: PdfArchiveSource.customerDocument,
      sourceId: 'invoice-1', bytes: Uint8List.fromList([37, 80, 68, 70, 0, 255]),
    );
    final second = await repo.storeGenerated(
      companyId: company.id, sourceType: PdfArchiveSource.customerDocument,
      sourceId: 'invoice-1', bytes: Uint8List.fromList([1, 2]),
    );
    final purchase = await repo.storeGenerated(
      companyId: company.id, sourceType: PdfArchiveSource.purchaseOrder,
      sourceId: 'invoice-1', bytes: Uint8List.fromList([3, 4]),
    );
    expect([first.version, second.version, purchase.version], [1, 2, 1]);
    expect(first.createdAt.isUtc, isTrue);
    expect((await repo.readBytes(companyId: company.id, artifactId: first.id))?.toList(), [37, 80, 68, 70, 0, 255]);
    expect((await repo.list(companyId: company.id, sourceType: PdfArchiveSource.customerDocument, sourceId: 'invoice-1')).map((a) => a.version).toList(), [2, 1]);
    expect(await repo.readBytes(companyId: company.id, artifactId: first.id), isNotNull);
    expect((await repo.list(companyId: company.id, sourceType: PdfArchiveSource.customerDocument, sourceId: 'invoice-1')).length, 2);
    final other = await CompanyRepository(db).create(name: 'Other');
    final otherFirst = await repo.storeGenerated(
      companyId: other.id, sourceType: PdfArchiveSource.customerDocument,
      sourceId: 'invoice-1', bytes: Uint8List.fromList([5]),
    );
    expect(otherFirst.version, 1);
    expect(await repo.readBytes(companyId: other.id, artifactId: first.id), isNull);
    expect((await repo.list(companyId: other.id, sourceType: PdfArchiveSource.customerDocument, sourceId: 'invoice-1')).map((a) => a.id), [otherFirst.id]);
  });

  test('archived bytes survive reopening a file-backed database', () async {
    final dir = await Directory.systemTemp.createTemp('pdf-archive-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/erp.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    final company = await CompanyRepository(db).create(name: 'Archive test');
    final artifact = await PdfArchiveRepository(db).storeGenerated(
      companyId: company.id, sourceType: PdfArchiveSource.purchaseOrder,
      sourceId: 'po-1', bytes: Uint8List.fromList([0, 255, 42]),
    );
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    expect((await PdfArchiveRepository(db).readBytes(companyId: company.id, artifactId: artifact.id))?.toList(), [0, 255, 42]);
    await db.close();
  });

  test('ordinary offline backup contains archived exact PDF bytes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final company = await CompanyRepository(db).create(name: 'Backup source');
    final artifact = await PdfArchiveRepository(db).storeGenerated(
      companyId: company.id, sourceType: PdfArchiveSource.customerDocument,
      sourceId: 'doc', bytes: Uint8List.fromList([0, 255, 42]),
    );
    final bytes = await BackupService(db).createBackup();
    final zip = ZipDecoder().decodeBytes(await BackupEncryption.decryptIfNeeded(bytes, null));
    expect(zip.files.map((f) => f.name), contains('werkkernerp.sqlite'));
    final sqlite = zip.findFile('werkkernerp.sqlite')!;
    final dir = await Directory.systemTemp.createTemp('archive-backup-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/restored.sqlite');
    await file.writeAsBytes(sqlite.content as List<int>);
    final restored = AppDatabase.forTesting(NativeDatabase(file));
    expect((await PdfArchiveRepository(restored).readBytes(
      companyId: company.id, artifactId: artifact.id))?.toList(), [0, 255, 42]);
    await restored.close();
    await db.close();
  });
}
