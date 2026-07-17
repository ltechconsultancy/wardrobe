#!/bin/sh
# Enable persistent /app/data storage via Docker Compose named volume.
# Coolify beta.442 has no /storages API — compose volume is the reliable path.
#
# Usage:
#   WARDROBE_APP_UUID=aso84g4kk4s4kgkw848ogkcs ./scripts/coolify-enable-storage.sh
#   ./scripts/coolify-enable-storage.sh --deploy

set -e

APP_UUID="${WARDROBE_APP_UUID:-aso84g4kk4s4kgkw848ogkcs}"
COOLIFY_URL="${COOLIFY_URL:-https://coolify.bartluttels.nl}"
API_KEY="${COOLIFY_API_KEY:-${COOLIFY_API_KEY_BARTLUTTELS:-}}"
DEPLOY=false

for arg in "$@"; do
    case "$arg" in
        --deploy) DEPLOY=true ;;
    esac
done

if [ -z "$API_KEY" ]; then
    echo "Set COOLIFY_API_KEY_BARTLUTTELS"
    exit 1
fi

BASE_URL="${COOLIFY_URL%/}/api/v1"
AUTH="Authorization: Bearer $API_KEY"

echo "=== Switch application to Docker Compose (named volume) ==="
curl -sS -X PATCH "$BASE_URL/applications/$APP_UUID" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d '{
        "build_pack": "dockercompose",
        "docker_compose_location": "/docker-compose.yaml",
        "ports_exposes": "4173"
    }' >/dev/null
echo "Build pack set to dockercompose with /docker-compose.yaml"

if [ "$DEPLOY" = true ]; then
    echo ""
    echo "=== Redeploy ==="
    curl -sS -H "$AUTH" "$BASE_URL/deploy?uuid=$APP_UUID&force=true"
    echo ""
fi

echo ""
echo "Persistent volume: wardrobe-data -> /app/data"
