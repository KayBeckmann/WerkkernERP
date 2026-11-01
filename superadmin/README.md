# WerkkernERP Superadmin-Panel

Eigene Web-App für den SaaS-Betrieb: alle Firmen mit Mitgliederzahl,
Admin-E-Mails und Abo (Tarif, „bezahlt bis“, Notiz). Überfällige
Firmen werden markiert; sperren und entsperren macht der Betreiber von
Hand. Eine gesperrte Firma ist komplett gesperrt: laufende Sitzungen
enden sofort, Anmeldung und Agent-Token wirken nicht mehr, die Daten
bleiben erhalten.

Das Panel sieht nur Firmenstammdaten, keine Fachdaten (ADR-0001 B0.5).

## Zugang

Superadmin wird man nur auf dem Server (kein API-Weg):

```bash
docker compose exec server /app/platform_admin grant kay@example.org
# Konto existiert noch nicht: Passwort über stdin
echo 'mind-8-zeichen' | docker compose exec -T server /app/platform_admin grant kay@example.org
docker compose exec server /app/platform_admin revoke kay@example.org
```

Die Panel-Sitzung gilt 8 Stunden und lebt nur im Browser-Tab.

## Bauen und Betrieb

```bash
flutter test
flutter build web --release
docker compose build superadmin && docker compose up -d superadmin   # Port 8086
```

Der Container (nginx, `deploy/nginx/superadmin.conf`) reicht nur
`/api/platform/*` und `/api/health` an den Server weiter. Auf Strato
übernimmt das `deploy/strato/deploy.sh`.

Entwicklung gegen einen lokalen Server:
`flutter run -d chrome --dart-define=WERKKERN_API=http://localhost:8190`
