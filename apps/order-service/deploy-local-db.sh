#!/usr/bin/env bash
set -euo pipefail

# Postgres settings
PG_CONTAINER="order-service-pg"
PG_IMAGE="postgres:17-alpine"
PG_NETWORK="order-network"
PG_VOLUME="order-pgdata"
PG_DB="orderdb"
PG_USER="orderuser"
PG_PASS="orderpass"
PG_PORT=5432


### 4) Run Postgres container
if [ "$(docker ps -aq -f name=^/${PG_CONTAINER}$)" = "" ]; then
  echo "==> Launching Postgres container '${PG_CONTAINER}'…"
  docker run -d \
    --name "${PG_CONTAINER}" \
    --network "${PG_NETWORK}" \
    -p ${PG_PORT}:5432 \
    -e POSTGRES_DB="${PG_DB}" \
    -e POSTGRES_USER="${PG_USER}" \
    -e POSTGRES_PASSWORD="${PG_PASS}" \
    -v "${PG_VOLUME}":/var/lib/postgresql/data \
    "${PG_IMAGE}"
else
  echo "==> Postgres container '${PG_CONTAINER}' already exists."
  if [ "$(docker ps -q -f name=^/${PG_CONTAINER}$)" = "" ]; then
    echo "    Starting existing Postgres container…"
    docker start "${PG_CONTAINER}"
  fi
fi

# echo "==> Launching app container '${APP_CONTAINER}'…"
# docker run -d \
#   --name "${APP_CONTAINER}" \
#   --network "${PG_NETWORK}" \
#   -p 8080:8080 \
#   -e SPRING_DATASOURCE_URL="jdbc:postgresql://${PG_CONTAINER}:5432/${PG_DB}" \
#   -e SPRING_DATASOURCE_USERNAME="${PG_USER}" \
#   -e SPRING_DATASOURCE_PASSWORD="${PG_PASS}" \
#   "${APP_IMAGE}"

echo "==> All done!  
- Postgres on localhost:${PG_PORT}, db=${PG_DB}, user=${PG_USER}/${PG_PASS}"
