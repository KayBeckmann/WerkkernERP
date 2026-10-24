import 'package:werkkern_client/werkkern_client.dart';

/// Entzieht allen Gruppen der aktuell gewählten Firma ihre Rechte.
/// Startgruppen kommen mit Standardrechten (`starterGroupPermissions`);
/// Tests, die Rechte gezielt vergeben, setzen damit vorher auf leer.
Future<void> clearGroupPermissions(WerkkernApiClient client) async {
  for (final group in await client.groups()) {
    for (final permission in await client.groupPermissions(group.id)) {
      await client.setGroupPermission(group.id, permission, granted: false);
    }
  }
}
