#!/usr/bin/env bash
# B3 — Wiederherstellung der LAUFENDEN Server-Datenbank aus einem Backup.
#
#   server/scripts/restore.sh <backup-datei>
#
# Ersetzt den kompletten Datenbestand ALLER Mandanten. Deshalb:
# - vorher immer restore-test.sh mit derselben Datei laufen lassen,
# - ausdrückliche Bestätigung durch Eintippen von WIEDERHERSTELLEN
#   (oder RESTORE_CONFIRM=WIEDERHERSTELLEN für Automatisierung),
# - Server wird während des Restores gestoppt (keine Schreibzugriffe),
# - pg_restore läuft in EINER Transaktion: schlägt es fehl, bleibt der
#   bisherige Bestand vollständig erhalten.
set -euo pipefail

backup=${1:?Aufruf: restore.sh <backup-datei>}
compose=(docker compose -f "$(dirname "$0")/../../docker-compose.yml")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ "${RESTORE_CONFIRM:-}" != WIEDERHERSTELLEN ]]; then
  read -r -p "Gesamten Server-Datenbestand durch $backup ersetzen? Zum Bestätigen WIEDERHERSTELLEN eintippen: " answer
  [[ "$answer" == WIEDERHERSTELLEN ]] || { echo "Abgebrochen, nichts verändert."; exit 1; }
fi

if [[ -f "$backup.sha256" ]]; then
  (cd "$(dirname "$backup")" && sha256sum --check --quiet "$(basename "$backup").sha256")
fi
if [[ "$backup" == *.gpg ]]; then
  gpg --batch --quiet --decrypt --output "$work/dump" "$backup"
else
  cp "$backup" "$work/dump"
fi

"${compose[@]}" stop server
restore_status=0
"${compose[@]}" exec -T server-db pg_restore -U werkkernerp_server -d werkkernerp_server \
  --clean --if-exists --no-owner --single-transaction --exit-on-error < "$work/dump" || restore_status=$?
if [[ $restore_status == 0 ]]; then
  # Sitzungen/Login-Zwischentokens aus dem Backup-Zeitpunkt nicht
  # wiederbeleben — nach einem Restore melden sich alle neu an.
  "${compose[@]}" exec -T server-db psql -U werkkernerp_server -d werkkernerp_server \
    -c 'TRUNCATE company_sessions, pending_logins' >/dev/null
fi
"${compose[@]}" start server
if [[ $restore_status != 0 ]]; then
  echo "Restore fehlgeschlagen (Transaktion zurückgerollt, bisheriger Bestand unverändert)." >&2
  exit $restore_status
fi
echo "Restore abgeschlossen. Alle Sitzungen wurden beendet — Nutzer melden sich neu an."
