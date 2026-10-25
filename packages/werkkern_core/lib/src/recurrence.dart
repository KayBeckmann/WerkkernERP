/// Intervalle wiederkehrender Rechnungen (C11), Schlüssel = Name des
/// `RecurrenceInterval`-Enums der Offline-App.
const recurrenceIntervals = {'monthly', 'quarterly', 'yearly'};

/// Nächster Fälligkeitstermin — bewusst über den `DateTime`-Konstruktor
/// (Monats-/Jahresüberlauf normalisiert Dart, z. B. Monat 13 → Januar);
/// ein 31. bei kürzerem Zielmonat rutscht in den übernächsten Monat vor
/// (bekannte, dokumentierte Einschränkung, wie offline). UTC bleibt UTC.
DateTime nextRecurrenceDate(DateTime date, String interval) {
  final (year, month) = switch (interval) {
    'monthly' => (date.year, date.month + 1),
    'quarterly' => (date.year, date.month + 3),
    'yearly' => (date.year + 1, date.month),
    _ => throw ArgumentError.value(interval, 'interval'),
  };
  return date.isUtc ? DateTime.utc(year, month, date.day) : DateTime(year, month, date.day);
}
