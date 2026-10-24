#!/usr/bin/env bash
# B3 — Restore-Test: spielt ein Backup in eine WEGWERF-Postgres-Instanz
# ein und prüft es, ohne die laufende Datenbank anzufassen.
#
#   server/scripts/restore-test.sh <backup-datei> [--compare-live]
#
# Prüft: Prüfsumme, Entschlüsselung (gpg, privater Schlüssel nötig),
# vollständiges pg_restore in einer Transaktion, Schemastufe und
# Zeilenzahlen je Kerntabelle. Mit --compare-live werden die
# Zeilenzahlen zusätzlich mit der laufenden Datenbank verglichen
# (sinnvoll direkt nach einem Backup).
set -euo pipefail

backup=${1:?Aufruf: restore-test.sh <backup-datei> [--compare-live]}
compare_live=${2:-}
compose=(docker compose -f "$(dirname "$0")/../../docker-compose.yml")
container=werkkern-restore-test-$$
work=$(mktemp -d)
trap 'docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

if [[ -f "$backup.sha256" ]]; then
  (cd "$(dirname "$backup")" && sha256sum --check --quiet "$(basename "$backup").sha256")
  echo "Prüfsumme ok"
fi
if [[ "$backup" == *.gpg ]]; then
  gpg --batch --quiet --decrypt --output "$work/dump" "$backup"
else
  cp "$backup" "$work/dump"
fi

docker run -d --name "$container" -e POSTGRES_PASSWORD=restore -e POSTGRES_USER=restore -e POSTGRES_DB=restore \
  postgres:16-alpine >/dev/null
for _ in $(seq 1 30); do
  docker exec "$container" pg_isready -U restore -d restore >/dev/null 2>&1 && break
  sleep 1
done
sleep 1
docker exec -i "$container" pg_restore -U restore -d restore --no-owner --single-transaction --exit-on-error < "$work/dump"

tables=(companies app_users memberships customers articles documents document_items number_sequences audit_log)
query() { docker exec "$container" psql -U restore -d restore -tAc "$1"; }
echo "Schemastufe: $(query 'SELECT max(version) FROM schema_migrations')"
status=0
for t in "${tables[@]}"; do
  restored=$(query "SELECT count(*) FROM $t")
  if [[ "$compare_live" == --compare-live ]]; then
    live=$("${compose[@]}" exec -T server-db psql -U werkkernerp_server -d werkkernerp_server -tAc "SELECT count(*) FROM $t")
    marker=$([[ "$restored" == "$live" ]] && echo ok || echo ABWEICHUNG)
    [[ "$marker" == ok ]] || status=1
    printf '%-18s %6s (live %s) %s\n' "$t" "$restored" "$live" "$marker"
  else
    printf '%-18s %6s\n' "$t" "$restored"
  fi
done
# Stichprobe Mandantentrennung: kein Dokument ohne existierende Firma
# oder mit Kunde einer anderen Firma.
orphans=$(query "SELECT count(*) FROM documents d LEFT JOIN customers c ON c.id = d.customer_id WHERE c.id IS NULL OR c.company_id <> d.company_id")
echo "Dokumente mit fremdem/fehlendem Kunden: $orphans"
[[ "$orphans" == 0 ]] || status=1
[[ $status == 0 ]] && echo "RESTORE-TEST OK" || echo "RESTORE-TEST FEHLGESCHLAGEN"
exit $status
