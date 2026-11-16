import 'package:flutter/material.dart';
import 'package:werkkern_core/werkkern_core.dart' show quoteValidityDaysBetween;

String formatValidityDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Ergebnis der Rückfrage beim Ändern eines finalisierten Angebots:
/// `keep` = bisherige Frist behalten, sonst das ausdrücklich bestätigte
/// neue „bindend bis“.
typedef QuoteValidityDecision = ({bool keep, DateTime? newUntil});

/// A5-Nachtrag (Kay, 16.11.2026): Vor dem Speichern eines bereits
/// finalisierten, noch editierbaren Angebots aktiv fragen, ob die
/// Bindefrist angepasst werden soll. Kein stilles Verlängern/Verkürzen:
/// „Nein“ behält die Frist, „Ja“ zeigt das neue Enddatum zur Bestätigung.
/// `null` = abgebrochen, nichts speichern.
Future<QuoteValidityDecision?> askQuoteValidityChange(
  BuildContext context, {
  required DateTime validFrom,
  DateTime? validUntil,
}) async {
  final change = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bindefrist anpassen?'),
      content: Text(
        validUntil == null
            ? 'Dieses Angebot hat bisher keine Bindefrist.'
            : 'Das Angebot ist bisher bindend bis ${formatValidityDate(validUntil)} '
                '(Fristbeginn ${formatValidityDate(validFrom)}).',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
        TextButton(
          key: const Key('quote-validity-keep'),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Nein, Frist behalten'),
        ),
        FilledButton(
          key: const Key('quote-validity-change'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ja, anpassen'),
        ),
      ],
    ),
  );
  if (change == null || !context.mounted) return null;
  if (!change) return (keep: true, newUntil: null);

  final start = DateTime(validFrom.year, validFrom.month, validFrom.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: validUntil != null && !validUntil.isBefore(start) ? validUntil : start,
    firstDate: start,
    lastDate: DateTime(start.year + 10),
    helpText: 'Neues „bindend bis“',
  );
  if (picked == null || !context.mounted) return null;
  final days = quoteValidityDaysBetween(start, picked);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Neue Bindefrist bestätigen'),
      content: Text(
        'Bindend bis ${formatValidityDate(picked)} — $days ${days == 1 ? 'Tag' : 'Tage'} '
        'ab Fristbeginn ${formatValidityDate(start)}'
        '${validUntil == null ? '' : ' (bisher bis ${formatValidityDate(validUntil)})'}.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        FilledButton(
          key: const Key('quote-validity-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Übernehmen'),
        ),
      ],
    ),
  );
  if (confirmed != true) return null;
  return (keep: false, newUntil: picked);
}

/// Bindefrist-Zeile für ein finalisiertes Angebot (Anzeige im Editor).
String quoteValidityStatus({DateTime? validFrom, DateTime? validUntil, int? days}) {
  if (validUntil == null) return 'Keine Bindefrist.';
  return 'Bindend bis ${formatValidityDate(validUntil)}'
      '${validFrom == null || days == null ? '' : ' ($days ${days == 1 ? 'Tag' : 'Tage'} ab ${formatValidityDate(validFrom)})'}.';
}

/// Eingabe der Bindefrist in Tagen: leer = keine, sonst 0–3650.
/// Liefert `(ok: false)` bei ungültiger Eingabe.
({bool ok, int? days}) parseQuoteValidityDays(String text) {
  final t = text.trim();
  if (t.isEmpty) return (ok: true, days: null);
  final days = int.tryParse(t);
  if (days == null || days < 0 || days > 3650) return (ok: false, days: null);
  return (ok: true, days: days);
}
