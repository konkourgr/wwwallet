#!/bin/bash

set -e

docker compose up -d wallet-db
docker compose up -d kv-store

# Start optional gateway only when the submodule is present
if [ -f "privacy-gateway-server-go/Dockerfile" ]; then
  docker compose up -d gateway
else
  echo "Warning: privacy-gateway-server-go/Dockerfile not found; skipping gateway startup."
  echo "Run: git submodule update --init --recursive privacy-gateway-server-go"
fi

wait_for_health() {
  local service="$1"
  local container_id status
  local deadline=$((SECONDS + 180))

  echo "Waiting for $service to be healthy..."
  while (( SECONDS < deadline )); do
    container_id=$(docker compose ps --all --quiet "$service")
    if [ -z "$container_id" ]; then
      echo "No container found for Compose service $service."
      return 1
    fi

    status=$(docker inspect --format='{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")
    case "$status" in
      "running healthy")
        echo "$service is healthy!"
        return 0
        ;;
      "running starting"|"created "*)
        echo "$service status: $status"
        ;;
      *)
        echo "$service failed to become healthy (status: $status)."
        echo "Check logs with: docker compose logs $service"
        return 1
        ;;
    esac
    sleep 2
  done

  echo "Timed out waiting for $service to become healthy."
  echo "Check logs with: docker compose logs $service"
  return 1
}

wait_for_health wallet-db
wait_for_health kv-store

FRONTEND_CMD="${FRONTEND_CMD:-npm --prefix wallet-frontend run dev}"

yarn concurrently \
  --names "wallet-frontend,wallet-backend-server,wallet-issuer,wallet-verifier,vct-registry,wallet-as" \
  --prefix-colors "blueBright,greenBright,yellowBright,magentaBright,cyanBright,blue" \
  "$FRONTEND_CMD" \
  "npm --prefix wallet-backend-server run dev" \
  "npm --prefix wallet-issuer run dev" \
  "npm --prefix wallet-verifier run dev" \
  "npm --prefix vct-registry run dev" \
  "npm --prefix wallet-as run dev"
