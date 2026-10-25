import 'package:decimal/decimal.dart';

import 'money.dart';

/// Mahnstufe (C12, Kay-Priorisierungsentscheidung 2026-10-17). Rein
/// datums-/statusbasiert berechnet aus Fälligkeitsdatum und den von Kay
/// selbst eingetragenen Fristen (siehe [DunningConfig]) — **keine**
/// gesetzliche Vorgabe, keine Rechtsprüfung der Fristen/Beträge selbst.
enum DunningLevel { none, overdue, reminder2, reminder3 }

/// Mahnwesen-Einstellungen einer Firma (Kay-Feedback 2026-10-17: "Wo
/// stelle ich die Gebühren und die Fristen ein?") — **Kays eigene
/// Werte**, keine von dieser App vorgegebenen oder rechtlich geprüften
/// Beträge/Fristen. Die Mahngebühr ist ein Pauschalbetrag je Stufe, der
/// Verzugszins eine einfache Tageszins-Berechnung
/// (`Hauptforderung × Zinssatz% × überfällige Tage / 365`) — **ob und in
/// welcher Höhe ein Verzugszins im Einzelfall überhaupt zulässig ist
/// (§ 286/288 BGB), prüft diese App nicht.**
class DunningConfig {
  const DunningConfig({
    required this.reminder2AfterDays,
    required this.reminder3AfterDays,
    required this.feeLevel1,
    required this.feeLevel2,
    required this.feeLevel3,
    required this.interestRatePercent,
  });


  /// Tage seit Fälligkeit, ab denen die 2./3. Stufe statt der einfachen
  /// Überfälligkeit gilt.
  final int reminder2AfterDays;
  final int reminder3AfterDays;

  /// Pauschale Mahngebühr je Stufe — `Money.zero()` zeigt keine Gebühr.
  final Money feeLevel1;
  final Money feeLevel2;
  final Money feeLevel3;

  /// Jährlicher Verzugszinssatz in Prozent — `0` schaltet die
  /// Zinsberechnung komplett aus.
  final double interestRatePercent;

  Money feeFor(DunningLevel level) => switch (level) {
        DunningLevel.none => Money.zero(),
        DunningLevel.overdue => feeLevel1,
        DunningLevel.reminder2 => feeLevel2,
        DunningLevel.reminder3 => feeLevel3,
      };
}

/// Berechnet die Mahnstufe einer Rechnung aus Fälligkeit, Zahlungsstatus
/// und den Firmen-Einstellungen [config]. `DunningLevel.none`, wenn sie
/// nicht finalisiert oder bezahlt ist, keine Fälligkeit hat oder die
/// Fälligkeit noch nicht erreicht ist.
DunningLevel dunningLevelForDue({
  required bool isFinalized,
  required bool isPaid,
  required DateTime? dueDate,
  required DateTime now,
  required DunningConfig config,
}) {
  if (!isFinalized || isPaid || dueDate == null) return DunningLevel.none;
  if (!now.isAfter(dueDate)) return DunningLevel.none;
  final overdueDays = now.difference(dueDate).inDays;
  if (overdueDays >= config.reminder3AfterDays) return DunningLevel.reminder3;
  if (overdueDays >= config.reminder2AfterDays) return DunningLevel.reminder2;
  return DunningLevel.overdue;
}

/// Anzeigetext je Stufe für die reine In-App-Statusanzeige (Liste/
/// Editor) — bewusst "überfällig"/"2./3. Mahnstufe" statt "1./2./3.
/// Mahnung", um keine bereits versendete Mahnung zu unterstellen. Das
/// tatsächliche Mahnschreiben (siehe `pdf/dunning_letter_pdf_builder.dart`)
/// nennt sich dagegen bewusst "1./2./3. Mahnung", weil es genau das ist
/// — ein Dokument, das Kay jetzt aktiv erzeugt und versendet.
String dunningLevelLabel(DunningLevel level) => switch (level) {
      DunningLevel.none => '',
      DunningLevel.overdue => 'Überfällig',
      DunningLevel.reminder2 => 'Überfällig (2. Mahnstufe)',
      DunningLevel.reminder3 => 'Überfällig (3. Mahnstufe)',
    };

/// Titel für ein erzeugtes Mahnschreiben je Stufe.
String dunningLetterTitle(DunningLevel level) => switch (level) {
      DunningLevel.none => '',
      DunningLevel.overdue => '1. Mahnung',
      DunningLevel.reminder2 => '2. Mahnung',
      DunningLevel.reminder3 => '3. Mahnung',
    };

/// Einfache Tageszins-Berechnung: `principal × ratePercent% × tage/365`,
/// kaufmännisch gerundet über [Money] (F2). `Money.zero()`, wenn
/// [ratePercent] `<= 0` oder [overdueDays] `<= 0` — keine Zinsberechnung
/// ohne hinterlegten Zinssatz oder ohne tatsächliche Überfälligkeit.
Money dunningInterestFor({
  required Money principal,
  required int overdueDays,
  required double ratePercent,
}) {
  if (ratePercent <= 0 || overdueDays <= 0) return Money.zero();
  final annualInterest = principal.applyPercent(ratePercent);
  final dayFraction =
      (Decimal.fromInt(overdueDays) / Decimal.fromInt(365)).toDecimal(scaleOnInfinitePrecision: 10);
  return annualInterest.multiplyByQuantity(dayFraction);
}
