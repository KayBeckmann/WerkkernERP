import 'package:bcrypt/bcrypt.dart';

/// Gleiches Muster wie LibreECADs `shared_server_kit` (bewusst
/// dupliziert statt Cross-Repo-Abhängigkeit — zwei unabhängige
/// Produkte, siehe docs/phase-b-server.md).
class Passwords {
  Passwords._();

  static String hash(String plainText) => BCrypt.hashpw(plainText, BCrypt.gensalt());

  static bool verify(String plainText, String hash) {
    try {
      return BCrypt.checkpw(plainText, hash);
    } on ArgumentError {
      return false;
    } on FormatException {
      return false;
    }
  }
}
