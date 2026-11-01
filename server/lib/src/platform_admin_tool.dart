import 'package:uuid/uuid.dart';

import 'repository.dart';
import 'util/passwords.dart';

/// Betreiber-Werkzeug: Superadmin-Zugang vergeben/entziehen — bewusst
/// nur mit direktem DB-Zugriff (`bin/platform_admin.dart`), siehe
/// [PlatformRoutes] in `platform_routes.dart`.
///
/// `grant` legt das Konto an, wenn es noch keins gibt ([password] nötig,
/// mind. 8 Zeichen); ein bestehendes Konto behält sein Passwort.
Future<String> grantPlatformAdmin(PhaseBRepository repository, {required String email, String? password}) async {
  var user = await repository.findUserByEmail(email);
  var created = false;
  if (user == null) {
    if (password == null || password.length < 8) {
      throw StateError('Kein Konto mit $email — zum Anlegen ein Passwort (mind. 8 Zeichen) über stdin übergeben.');
    }
    user = await repository.createUser(id: const Uuid().v4(), email: email, passwordHash: Passwords.hash(password));
    created = true;
  }
  await repository.setPlatformAdmin(user.id, admin: true);
  return created ? 'Konto $email angelegt und als Superadmin eingetragen.' : '$email ist jetzt Superadmin.';
}

Future<String> revokePlatformAdmin(PhaseBRepository repository, {required String email}) async {
  final user = await repository.findUserByEmail(email);
  if (user == null) throw StateError('Kein Konto mit $email.');
  await repository.setPlatformAdmin(user.id, admin: false);
  return '$email ist kein Superadmin mehr.';
}
