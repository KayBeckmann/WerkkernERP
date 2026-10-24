#!/usr/bin/env bash
# B3 — konsistentes, verschlüsseltes Backup der Server-Datenbank.
#
#   BACKUP_GPG_RECIPIENT=<key-id|email> server/scripts/backup.sh <zielverzeichnis>
#
# - pg_dump im Custom-Format ist ein transaktional konsistenter Snapshot
#   (kein Kopieren laufender Datenbankdateien, gleiches Prinzip wie
#   VACUUM INTO in der Offline-App).
# - Verschlüsselung mit dem ÖFFENTLICHEN GPG-Schlüssel des Betreibers:
#   der Server-Host kann Backups erzeugen, aber nicht lesen. Der private
#   Schlüssel gehört offline (pass/KeePassXC), nie auf den Server.
# - Vor dem Verschlüsseln wird der Dump mit pg_restore --list geprüft;
#   eine kaputte/leere Sicherung wird nie als Erfolg gemeldet.
# - Unverschlüsselt nur mit ausdrücklichem BACKUP_ALLOW_UNENCRYPTED=1.
set -euo pipefail

target_dir=${1:?Aufruf: backup.sh <zielverzeichnis>}
compose=(docker compose -f "$(dirname "$0")/../../docker-compose.yml")
db_user=werkkernerp_server
db_name=werkkernerp_server

if [[ -z "${BACKUP_GPG_RECIPIENT:-}" && "${BACKUP_ALLOW_UNENCRYPTED:-0}" != 1 ]]; then
  echo "BACKUP_GPG_RECIPIENT fehlt (oder BACKUP_ALLOW_UNENCRYPTED=1 für ein unverschlüsseltes Test-Backup)." >&2
  exit 64
fi

mkdir -p "$target_dir"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"${compose[@]}" exec -T server-db pg_dump -U "$db_user" -d "$db_name" -Fc > "$work/dump"
if ! "${compose[@]}" exec -T server-db pg_restore --list < "$work/dump" > "$work/toc"; then
  echo "Dump ist nicht lesbar — Backup abgebrochen." >&2
  exit 1
fi
grep -q "TABLE DATA public companies" "$work/toc" || { echo "Dump enthält keine companies-Tabelle — abgebrochen." >&2; exit 1; }

if [[ -n "${BACKUP_GPG_RECIPIENT:-}" ]]; then
  name="werkkernerp-server-$stamp.dump.gpg"
  gpg --batch --yes --trust-model always --encrypt --recipient "$BACKUP_GPG_RECIPIENT" \
    --output "$work/$name" "$work/dump"
else
  name="werkkernerp-server-$stamp.dump"
  mv "$work/dump" "$work/$name"
fi

# Erst vollständig schreiben, dann atomar an den Zielort verschieben —
# ein abgebrochener Lauf hinterlässt nie eine halbe Datei mit gültigem Namen.
(cd "$work" && sha256sum "$name" > "$name.sha256")
mv "$work/$name.sha256" "$target_dir/"
mv "$work/$name" "$target_dir/"
echo "$target_dir/$name"
