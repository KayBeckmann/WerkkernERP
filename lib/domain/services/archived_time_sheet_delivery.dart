import 'dart:typed_data';

/// Only the archive reader supplies attachment bytes. No renderer is accepted
/// in this path, preventing a later re-render from differing from the archive.
Future<void> deliverArchivedTimeSheet({
  required bool signed,
  required String recipient,
  required Future<Uint8List?> Function() readArchivedPdf,
  required Future<void> Function(String recipient, Uint8List pdf) send,
}) async {
  if (!signed) throw StateError('Nur unterschriebene Stundenzettel dürfen versendet werden.');
  final address = recipient.trim();
  if (address.isEmpty) throw ArgumentError.value(recipient, 'recipient', 'Empfänger erforderlich');
  final pdf = await readArchivedPdf();
  if (pdf == null || pdf.isEmpty) throw StateError('Archiviertes PDF fehlt; kein Versand.');
  await send(address, pdf);
}
