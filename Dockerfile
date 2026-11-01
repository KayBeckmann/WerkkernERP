# Web-Build für den LAN-Test und den Online-Betrieb (deploy/strato/).
# nginx liefert die App aus und reicht /api/ an den Server-Container
# weiter (deploy/nginx/web.conf).
#
# Baut bewusst NICHT selbst aus dem Quellcode: das öffentliche
# ghcr.io/cirruslabs/flutter:stable-Image hinkt der lokal installierten
# Flutter-Version hinterher (Dart-SDK-Konflikt mit dieser Roadmap-
# Anforderung). Vor jedem Container-Build daher lokal
# `flutter build web --release` ausführen (macht der Skill automatisch).
FROM nginx:alpine
COPY deploy/nginx/web.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
EXPOSE 80
