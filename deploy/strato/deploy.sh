#!/usr/bin/env bash
# Baut Web-, Server- und Superadmin-Image lokal und startet sie auf Strato.
#   deploy/strato/deploy.sh            # Web-Builds + alle Images
#   SKIP_FLUTTER=1 deploy/strato/deploy.sh   # vorhandene Web-Builds nutzen
# Der Zielserver kompiliert nichts: Images kommen per `docker save | ssh
# docker load`, nur postgres wird dort gezogen.
set -euo pipefail

HOST=${DEPLOY_HOST:-strato}
DIR=${DEPLOY_DIR:-projekte/werkkernerp}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

if [[ "${SKIP_FLUTTER:-0}" != 1 ]]; then
  flutter build web --release
  (cd superadmin && flutter build web --release)
fi
[[ "${SKIP_IMAGES:-0}" == 1 ]] || docker build -t werkkernerp-web:latest -f Dockerfile .
[[ "${SKIP_IMAGES:-0}" == 1 ]] || docker build -t werkkernerp-server:latest -f server/Dockerfile .
[[ "${SKIP_IMAGES:-0}" == 1 ]] || docker build -t werkkernerp-superadmin:latest -f superadmin/Dockerfile .

ssh "$HOST" "mkdir -p ~/$DIR"
# Kein scp: die Login-Shell auf Strato gibt ein Banner aus, das scp bricht.
ssh "$HOST" "cat > ~/$DIR/docker-compose.yml" < deploy/strato/docker-compose.yml
# .env mit Zufalls-Secrets nur beim ersten Mal anlegen — nie überschreiben.
ssh "$HOST" "cd ~/$DIR && if [ ! -f .env ]; then umask 077; {
  echo SERVER_DB_PASSWORD=\$(openssl rand -hex 24)
  echo SERVER_SECRET_KEY=\$(openssl rand -base64 32)
  echo WEB_PORT=8085
  echo SUPERADMIN_PORT=8086
} > .env; echo '.env angelegt'; fi"

docker save werkkernerp-web:latest werkkernerp-server:latest werkkernerp-superadmin:latest | gzip -1 | ssh "$HOST" "gunzip | docker load"
ssh "$HOST" "cd ~/$DIR && docker compose up -d --remove-orphans && docker compose ps"
