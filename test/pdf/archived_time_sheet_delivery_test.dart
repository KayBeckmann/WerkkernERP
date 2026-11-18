import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/archived_time_sheet_delivery.dart';

void main() {
  test('sends only exact retrieved archive bytes to explicit recipient', () async {
    final stored = Uint8List.fromList([37, 80, 68, 70, 45, 49]);
    Uint8List? delivered;
    String? recipient;
    await deliverArchivedTimeSheet(
      signed: true,
      recipient: 'recipient@example.test',
      readArchivedPdf: () async => stored,
      send: (address, bytes) async {
        recipient = address;
        delivered = bytes;
      },
    );
    expect(recipient, 'recipient@example.test');
    expect(identical(delivered, stored), isTrue);
  });

  test('draft, blank recipient or unavailable archive never calls sender', () async {
    var calls = 0;
    Future<void> send(String address, Uint8List bytes) async => calls++;
    await expectLater(deliverArchivedTimeSheet(
      signed: false, recipient: 'a@example.test',
      readArchivedPdf: () async => Uint8List.fromList([37, 80, 68, 70]), send: send,
    ), throwsStateError);
    await expectLater(deliverArchivedTimeSheet(
      signed: true, recipient: '  ',
      readArchivedPdf: () async => Uint8List.fromList([37, 80, 68, 70]), send: send,
    ), throwsArgumentError);
    await expectLater(deliverArchivedTimeSheet(
      signed: true, recipient: 'a@example.test',
      readArchivedPdf: () async => null, send: send,
    ), throwsStateError);
    expect(calls, 0);
  });
}
