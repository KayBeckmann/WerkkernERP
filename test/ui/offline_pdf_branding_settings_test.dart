import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:werkkern_core/werkkern_core.dart' show decodeFooterColumns;
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/domain/services/active_company_service.dart';
import 'package:werkkernerp/ui/screens/settings_company_screen.dart';
import 'package:werkkernerp/ui/screens/settings_document_texts_screen.dart';

/// Parität offline/online (Roadmap-Nachtrag 26.11.2026): Kays Befund —
/// in der lokalen Firma ließen sich kein Logo, keine drei Fußzeilenspalten
/// und kein Layout einstellen.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

base class _SyntheticFile extends PlatformFile {
  _SyntheticFile(this.bytes);
  final Uint8List bytes;
  @override
  String get name => 'synthetic.png';
  @override
  Uri get uri => Uri.parse('data:image/png;base64,${base64Encode(bytes)}');
  @override
  XFile get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _SyntheticPicker extends FilePickerPlatform {
  _SyntheticPicker(this.bytes);
  final Uint8List bytes;
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle, String? initialDirectory, FileType type = FileType.any,
    List<String>? allowedExtensions, Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0, AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(), WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(), WebOptions webOptions = const WebOptions(),
  }) async => [_SyntheticFile(bytes)];
}

void main() {
  late AppDatabase db;
  late CompanyRepository repository;
  late ActiveCompanyService active;
  late Company company;

  Future<void> pump(WidgetTester tester, Widget screen, {required Uint8List pick}) async {
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _SyntheticPicker(pick);
    addTearDown(() => FilePickerPlatform.instance = previous);
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repository = CompanyRepository(db);
    company = await repository.create(name: 'Synthetik GmbH');
    active = ActiveCompanyService(repository)..select(company);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<CompanyRepository>.value(value: repository),
        ChangeNotifierProvider<ActiveCompanyService>.value(value: active),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('document-texts-save')));
    await tester.tap(find.byKey(const Key('document-texts-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('Dokumenttexte offline: Logo hochladen/entfernen und drei Fußzeilenspalten speichern', (tester) async {
    await pump(tester, const SettingsDocumentTextsScreen(), pick: base64Decode(_png));
    expect(find.byKey(const Key('pdf-logo-preview')), findsNothing);
    await tester.tap(find.byKey(const Key('pdf-logo-upload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdf-logo-preview')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('footer-columns-enabled')));
    await tester.tap(find.byKey(const Key('footer-columns-enabled')));
    await tester.pumpAndSettle();
    // Vorbelegung wie online, solange nie Spalten gespeichert wurden.
    expect(find.text('IBAN: {{iban}}'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('footer-right')), 'USt-IdNr.: {{vatId}}');
    await save(tester);

    var saved = (await repository.findById(company.id))!;
    expect(saved.pdfLogoBase64, _png);
    expect(decodeFooterColumns(saved.pdfFooterColumns), {
      'left': '{{companyName}}\n{{address}}',
      'center': 'IBAN: {{iban}}',
      'right': 'USt-IdNr.: {{vatId}}',
    });
    expect(active.active!.pdfLogoBase64, _png, reason: 'aktive Firma neu geladen');

    await tester.tap(find.byKey(const Key('pdf-logo-remove')));
    await tester.ensureVisible(find.byKey(const Key('footer-columns-enabled')));
    await tester.tap(find.byKey(const Key('footer-columns-enabled')));
    await tester.pumpAndSettle();
    await save(tester);
    saved = (await repository.findById(company.id))!;
    expect(saved.pdfLogoBase64, isNull);
    expect(saved.pdfFooterColumns, isNull);
  });

  testWidgets('ungültiges Bild wird offline abgewiesen', (tester) async {
    await pump(tester, const SettingsDocumentTextsScreen(), pick: Uint8List.fromList(utf8.encode('kein Bild')));
    await tester.tap(find.byKey(const Key('pdf-logo-upload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdf-logo-preview')), findsNothing);
    expect(find.textContaining('gültiges PNG/JPEG'), findsOneWidget);
  });

  testWidgets('Firmendaten offline: PDF-Layout wählbar wie online', (tester) async {
    await pump(tester, const SettingsCompanyScreen(), pick: base64Decode(_png));
    await tester.tap(find.byKey(const Key('company-pdf-layout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls-Briefbogen').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Firmendaten speichern'));
    await tester.tap(find.text('Firmendaten speichern'));
    await tester.pumpAndSettle();
    expect((await repository.findById(company.id))!.pdfLayout, 'nordLetterhead');
  });
}
