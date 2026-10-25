/// Kunden-Stundenzettel online (C3-Rest): Zeitbuchungen eines Tages,
/// vom Kunden auf dem Gerät unterschrieben (einfache Touch-Zeichnung,
/// **keine qualifizierte elektronische Signatur**). Nach der Unterschrift
/// sind Zettel und zugeordnete Buchungen unveränderlich; eine Korrektur
/// ist ein neuer Nachtrag (wie offline).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'request_util.dart';

class TimeSheet {
  const TimeSheet({
    required this.id,
    required this.companyId,
    required this.date,
    this.documentId,
    this.projectId,
    required this.status,
    this.signaturePng,
    this.signerName,
    this.signedAt,
    this.supersedesId,
    required this.createdByUserId,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final DateTime date;
  final String? documentId;
  final String? projectId;

  /// `draft` oder `signed`.
  final String status;
  final Uint8List? signaturePng;
  final String? signerName;
  final DateTime? signedAt;

  /// Korrektur-Nachtrag zu diesem (unterschriebenen) Zettel.
  final String? supersedesId;
  final String createdByUserId;
  final DateTime createdAt;

  bool get isSigned => status == 'signed';

  Map<String, Object?> toJson({bool withSignature = false}) => {
        'id': id,
        'date': dateJson(date),
        'documentId': documentId,
        'projectId': projectId,
        'status': status,
        'signerName': signerName,
        'signedAt': signedAt?.toIso8601String(),
        'supersedesId': supersedesId,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
        if (withSignature) 'signaturePng': signaturePng == null ? null : base64Encode(signaturePng!),
      };
}

abstract interface class TimeSheetStore {
  Future<List<TimeSheet>> listTimeSheets(String companyId, {String? createdByUserId});
  Future<TimeSheet?> findTimeSheet(String companyId, String id);
  Future<List<String>> timeSheetEntryIds(String companyId, String sheetId);

  /// Zettel, dem die Buchung zugeordnet ist (höchstens einer).
  Future<TimeSheet?> timeSheetForEntry(String companyId, String entryId);
  Future<void> createTimeSheet(TimeSheet sheet);

  /// Ordnet Buchungen einem Entwurf zu; [BusinessConflict], wenn der Zettel
  /// unterschrieben ist oder eine Buchung schon auf einem anderen liegt.
  Future<void> addTimeSheetEntries(String companyId, String sheetId, List<String> entryIds);
  Future<bool> removeTimeSheetEntry(String companyId, String sheetId, String entryId);
  Future<bool> deleteTimeSheetDraft(String companyId, String sheetId);

  /// Unterschreiben (nur Entwurf mit mindestens einer Buchung).
  Future<TimeSheet?> signTimeSheet(String companyId, String sheetId, {required Uint8List png, String? signerName, required DateTime now});
}
