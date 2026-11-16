import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

const samplePng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
const replacementPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==';

base class _SyntheticFile extends PlatformFile {
  @override
  String get name => 'synthetic.png';
  @override
  Uri get uri => Uri.parse('data:image/png;base64,$replacementPng');
  @override
  XFile get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => base64Decode(replacementPng).length;
  @override
  Future<int?> length() async => lengthSync();
  @override
  Future<Uint8List> readAsBytes() async => base64Decode(replacementPng);
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(base64Decode(replacementPng));
}

class _SyntheticPicker extends FilePickerPlatform {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle, String? initialDirectory, FileType type = FileType.any,
    List<String>? allowedExtensions, Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0, AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(), WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(), WebOptions webOptions = const WebOptions(),
  }) async => [_SyntheticFile()];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('document settings replace and remove the company logo on save', (tester) async {
    final previousPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _SyntheticPicker();
    addTearDown(() => FilePickerPlatform.instance = previousPicker);
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(email: 'logo-ui@example.test', companyName: 'Synthetic Company', permissions: []);
      await server.put('/company/profile', {'pdfLogoBase64': samplePng}, token);
    });
    await tester.pumpWidget(MaterialApp(home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null)));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'logo-ui@example.test');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetic Company'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Einstellungen');
    await tester.tap(find.text('Dokumenttexte'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('online-pdf-logo-preview')), findsOneWidget);
    expect(find.byKey(const Key('online-pdf-logo-upload')), findsOneWidget);
    await tester.tap(find.byKey(const Key('online-pdf-logo-upload')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final replaced = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return (await client.companyProfile()).pdfLogoBase64;
    });
    expect(replaced, replacementPng);
    await tester.tap(find.byKey(const Key('online-pdf-logo-remove')));
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final logo = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return (await client.companyProfile()).pdfLogoBase64;
    });
    expect(logo, isNull);
  });
}
