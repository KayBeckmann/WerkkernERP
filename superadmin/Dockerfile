# Superadmin-Panel (SaaS-Betrieb). Build-Kontext: Repo-Root. Vorher
# lokal `flutter build web --release` in superadmin/ ausführen (macht
# deploy/strato/deploy.sh).
FROM nginx:alpine
COPY deploy/nginx/superadmin.conf /etc/nginx/conf.d/default.conf
COPY superadmin/build/web /usr/share/nginx/html
EXPOSE 80
