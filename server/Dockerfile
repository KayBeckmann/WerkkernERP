# Build-Kontext ist `server/` selbst (keine Pfadabhängigkeit auf ein
# Geschwisterpaket nötig, anders als bei LibreECAD).
FROM dart:stable AS build
WORKDIR /app
COPY . /app
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server \
    && dart compile exe bin/recover_admin.dart -o bin/recover_admin

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/bin/server /app/server
COPY --from=build /app/bin/recover_admin /app/recover_admin
EXPOSE 8090
ENTRYPOINT ["/app/server"]
