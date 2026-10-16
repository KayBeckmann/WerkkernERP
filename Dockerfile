# Web-Build für Kays LAN-Test (siehe .claude/skills/werkkernerp-workflow).
# Android bleibt die eigentliche Zielplattform für die Offline-App;
# dieser Container dient ausschließlich dazu, die Web-Variante im
# lokalen Netz anzusehen/zu testen — kein Produktivbetrieb.
#
# Baut bewusst NICHT selbst aus dem Quellcode: das öffentliche
# ghcr.io/cirruslabs/flutter:stable-Image hinkt der lokal installierten
# Flutter-Version hinterher (Dart-SDK-Konflikt mit dieser Roadmap-
# Anforderung). Vor jedem Container-Build daher lokal
# `flutter build web --release` ausführen (macht der Skill automatisch).
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
