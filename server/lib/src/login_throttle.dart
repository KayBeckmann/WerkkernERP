/// Schutz gegen Durchprobieren von Passwörtern: zu viele Fehlversuche
/// je Konto (E-Mail) bzw. je Absender-IP innerhalb eines Zeitfensters
/// sperren weitere Versuche vorübergehend (429). Bewusst im Speicher des
/// Prozesses — reicht für den Ein-Instanz-Betrieb; bei mehreren
/// Instanzen hinter einem Proxy gehört das in den Proxy bzw. die DB.
class LoginThrottle {
  LoginThrottle({
    this.maxFailuresPerAccount = 5,
    this.maxFailuresPerAddress = 30,
    this.window = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final int maxFailuresPerAccount;
  final int maxFailuresPerAddress;
  final Duration window;
  final DateTime Function() _clock;
  final Map<String, List<DateTime>> _failures = {};

  List<DateTime> _recent(String key) {
    final cutoff = _clock().subtract(window);
    final list = _failures[key]?..removeWhere((t) => t.isBefore(cutoff));
    if (list != null && list.isEmpty) _failures.remove(key);
    return list ?? const [];
  }

  /// Wie lange noch gesperrt, `null` = Versuch erlaubt.
  Duration? blockedFor({required String account, String? address}) {
    for (final (key, limit) in [
      ('a:${account.toLowerCase()}', maxFailuresPerAccount),
      if (address != null) ('ip:$address', maxFailuresPerAddress),
    ]) {
      final recent = _recent(key);
      if (recent.length >= limit) return recent.first.add(window).difference(_clock());
    }
    return null;
  }

  void recordFailure({required String account, String? address}) {
    final now = _clock();
    _failures.putIfAbsent('a:${account.toLowerCase()}', () => []).add(now);
    if (address != null) _failures.putIfAbsent('ip:$address', () => []).add(now);
  }

  /// Erfolgreiche Anmeldung setzt den Zähler des Kontos zurück (nicht
  /// den der Adresse — sonst könnte ein eigenes Konto als "Reset" für
  /// Angriffe auf fremde Konten dienen).
  void recordSuccess({required String account}) => _failures.remove('a:${account.toLowerCase()}');
}
