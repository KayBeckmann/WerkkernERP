/// Plattformabhängiger E-Mail-Versand per SMTP (C7a, Kay-Nachfrage
/// 2026-10-17: "Gibt es schon den SMTP Versand?").
library;

/// Echtes SMTP ist nur über einen Rohsocket möglich (`dart:io`, Paket
/// `mailer`) — im Browser kann JavaScript/WASM so etwas aus
/// Sicherheitsgründen grundsätzlich nicht (kein Rohsocket-Zugriff, keine
/// CORS-Freigabe eines beliebigen Mailservers). Das ist kein Implemen-
/// tierungsrückstand, sondern eine echte Plattformgrenze — anders als
/// bei F4 gibt es hier keinen "noch zu bauenden" Web-Weg, ohne einen
/// eigenen Relay-Server zu betreiben, was dem "kein Server"-Grundprinzip
/// der Offline-Variante widersprechen würde (siehe Roadmap Zielbild
/// Punkt 1). Deshalb exakt das gleiche Muster wie bei
/// `data/backup/backup_io.dart`: Web bekommt eine eigene Implementierung,
/// die [emailSendingSupported] auf `false` setzt und bei einem
/// trotzdem versuchten Versand einen sprechenden Fehler statt eines
/// stillen Fehlschlags liefert. Siehe `email_sender_native.dart` für die
/// tatsächliche Funktionssignatur (`emailSendingSupported`, `sendEmail`).
export 'email_sender_web.dart' if (dart.library.io) 'email_sender_native.dart';
