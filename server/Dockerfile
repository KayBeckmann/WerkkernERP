# Build-Kontext ist `server/` selbst (keine Pfadabhängigkeit auf ein
# Geschwisterpaket nötig, anders als bei LibreECAD).
FROM dart:stable AS build
WORKDIR /app
COPY . /app
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/bin/server /app/server
EXPOSE 8090
ENTRYPOINT ["/app/server"]
