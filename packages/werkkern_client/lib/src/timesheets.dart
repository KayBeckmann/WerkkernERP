import 'dart:convert';
import 'dart:typed_data';

import 'api_client.dart';
import 'fleet.dart' show onlineDate;
import 'models.dart';

/// Kunden-Stundenzettel online (C3-Rest).
class OnlineTimeSheet {
  const OnlineTimeSheet({
    required this.id,
    required this.date,
    this.documentId,
    this.documentNumber,
    this.projectId,
    this.projectName,
    this.customerName,
    required this.status,
    this.signaturePng,
    this.signerName,
    this.signedAt,
    this.supersedesId,
    this.entries = const [],
    this.totalHours = '0',
  });
  factory OnlineTimeSheet.fromJson(Map<String, Object?> j) => OnlineTimeSheet(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        documentId: j['documentId'] as String?,
        documentNumber: j['documentNumber'] as String?,
        projectId: j['projectId'] as String?,
        projectName: j['projectName'] as String?,
        customerName: j['customerName'] as String?,
        status: j['status'] as String,
        signaturePng: j['signaturePng'] == null ? null : base64Decode(j['signaturePng'] as String),
        signerName: j['signerName'] as String?,
        signedAt: j['signedAt'] == null ? null : DateTime.parse(j['signedAt'] as String),
        supersedesId: j['supersedesId'] as String?,
        entries: [for (final e in (j['entries'] as List? ?? const [])) OnlineTimeEntry.fromJson(e as Map<String, Object?>)],
        totalHours: j['totalHours'] as String? ?? '0',
      );
  final String id;
  final DateTime date;
  final String? documentId;
  final String? documentNumber;
  final String? projectId;
  final String? projectName;
  final String? customerName;
  final String status;
  final Uint8List? signaturePng;
  final String? signerName;
  final DateTime? signedAt;
  final String? supersedesId;
  final List<OnlineTimeEntry> entries;
  final String totalHours;
  bool get isSigned => status == 'signed';
}

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension TimeSheetApi on WerkkernApiClient {
  Future<List<OnlineTimeSheet>> timeSheets() async {
    final j = _map(await request('GET', '/time-sheets'));
    return [for (final s in j['timeSheets'] as List) OnlineTimeSheet.fromJson(s as Map<String, Object?>)];
  }

  Future<OnlineTimeSheet> timeSheet(String id) async => OnlineTimeSheet.fromJson(_map(await request('GET', '/time-sheets/$id')));

  Future<OnlineTimeSheet> createTimeSheet({String? documentId, String? projectId, required DateTime date, List<String> entryIds = const []}) async =>
      OnlineTimeSheet.fromJson(_map(await request('POST', '/time-sheets', body: {
        'documentId': documentId,
        'projectId': projectId,
        'date': onlineDate(date),
        'entryIds': entryIds,
      })));

  Future<OnlineTimeSheet> addTimeSheetEntries(String id, List<String> entryIds) async =>
      OnlineTimeSheet.fromJson(_map(await request('POST', '/time-sheets/$id/entries', body: {'entryIds': entryIds})));

  Future<void> removeTimeSheetEntry(String id, String entryId) => request('DELETE', '/time-sheets/$id/entries/$entryId');

  Future<void> deleteTimeSheet(String id) => request('DELETE', '/time-sheets/$id');

  Future<OnlineTimeSheet> signTimeSheet(String id, Uint8List png, {String? signerName}) async => OnlineTimeSheet.fromJson(
        _map(await request('POST', '/time-sheets/$id/sign', body: {'signaturePng': base64Encode(png), 'signerName': signerName})),
      );

  Future<OnlineTimeSheet> createTimeSheetCorrection(String id) async =>
      OnlineTimeSheet.fromJson(_map(await request('POST', '/time-sheets/$id/correction')));
}
