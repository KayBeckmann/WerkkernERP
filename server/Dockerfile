# Build-Kontext ist das Repo-Root (docker-compose.yml: context ".",
# dockerfile server/Dockerfile), weil der Server das gemeinsame Paket
# packages/werkkern_core per path-Abhängigkeit nutzt. Was in den
# Kontext gelangt, regelt server/Dockerfile.dockerignore.
FROM dart:stable AS build
WORKDIR /app
COPY packages /app/packages
COPY server /app/server
WORKDIR /app/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server \
    && dart compile exe bin/recover_admin.dart -o bin/recover_admin

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/server/bin/server /app/server
COPY --from=build /app/server/bin/recover_admin /app/recover_admin
EXPOSE 8090
ENTRYPOINT ["/app/server"]
