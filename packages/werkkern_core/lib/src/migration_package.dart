/// B4 — Umzugspaket Einzelplatz → Online-Firma. Die Offline-App baut es
/// aus ihrer lokalen Datenbank, der Server liest es in eine leere Firma
/// ein (`POST /company/import`). Eigene Formatversion, unabhängig vom
/// Backup-Schema: steigt, wenn sich der Aufbau ändert.
library;

const migrationPackageFormat = 'werkkernerp-migration';
const migrationPackageVersion = 1;

/// Schlüssel in `roleAssignments` für Zeitbuchungen ohne Rolle.
const migrationNoRoleKey = '-';
