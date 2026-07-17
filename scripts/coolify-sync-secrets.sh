#!/bin/sh
# Sync PocketDev secrets to Coolify wardrobe app and enable HTTP basic auth.
#
# Usage:
#   WARDROBE_APP_UUID=aso84g4kk4s4kgkw848ogkcs ./scripts/coolify-sync-secrets.sh
#   ./scripts/coolify-sync-secrets.sh --deploy
#
# Reads from PocketDev environment (never prints secret values):
#   OPENAI_API_KEY          (required for import)
#   WARDROBE_AUTH_USER      (optional, default: wardrobe)
#   WARDROBE_AUTH_PASSWORD  (optional, generated if missing)

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

if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "OPENAI_API_KEY is not set in PocketDev environment."
    exit 1
fi

AUTH_USER="${WARDROBE_AUTH_USER:-wardrobe}"
if [ -z "${WARDROBE_AUTH_PASSWORD:-}" ]; then
    WARDROBE_AUTH_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)
    GENERATED_AUTH=true
else
    GENERATED_AUTH=false
fi

BASE_URL="${COOLIFY_URL%/}/api/v1"
AUTH="Authorization: Bearer $API_KEY"

upsert_env() {
    key="$1"
    value="$2"
    is_literal="${3:-false}"

  existing=$(curl -sS -H "$AUTH" "$BASE_URL/applications/$APP_UUID/envs" | python3 -c "
import json,sys
key=sys.argv[1]
for env in json.load(sys.stdin):
    if env.get('key') == key:
        print(env.get('uuid',''))
        break
" "$key")

    if [ -n "$existing" ]; then
        curl -sS -X PATCH "$BASE_URL/applications/$APP_UUID/envs/$existing" \
            -H "$AUTH" \
            -H "Content-Type: application/json" \
            -d "{\"key\":\"$key\",\"value\":\"$value\",\"is_literal\":$is_literal}" >/dev/null
        echo "Updated env: $key"
    else
        curl -sS -X POST "$BASE_URL/applications/$APP_UUID/envs" \
            -H "$AUTH" \
            -H "Content-Type: application/json" \
            -d "{\"key\":\"$key\",\"value\":\"$value\",\"is_literal\":$is_literal}" >/dev/null
        echo "Created env: $key"
    fi
}

echo "=== Sync OpenAI key to Coolify ==="
upsert_env "OPENAI_API_KEY" "$OPENAI_API_KEY" false

echo ""
echo "=== Sync app auth credentials ==="
upsert_env "WARDROBE_AUTH_USER" "$AUTH_USER" true
upsert_env "WARDROBE_AUTH_PASSWORD" "$WARDROBE_AUTH_PASSWORD" false

echo ""
echo "=== Sync OpenAI image model settings (cost-optimized) ==="
upsert_env "OPENAI_VISION_MODEL" "${OPENAI_VISION_MODEL:-gpt-5.4-mini}" true
upsert_env "OPENAI_IMAGE_MODEL" "${OPENAI_IMAGE_MODEL:-gpt-image-2}" true
upsert_env "OPENAI_IMAGE_QUALITY" "${OPENAI_IMAGE_QUALITY:-medium}" true
upsert_env "OPENAI_IMAGE_SIZE_GARMENT" "${OPENAI_IMAGE_SIZE_GARMENT:-1024x1024}" true
upsert_env "OPENAI_IMAGE_SIZE_MODELED" "${OPENAI_IMAGE_SIZE_MODELED:-1024x1024}" true

echo ""
echo "=== Disable Coolify proxy auth (app handles auth) ==="
curl -sS -X PATCH "$BASE_URL/applications/$APP_UUID" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d '{"is_http_basic_auth_enabled":false}' >/dev/null
echo "Using in-app HTTP basic auth instead."

if [ "$GENERATED_AUTH" = true ]; then
    echo ""
    echo "Generated login password (save this): $WARDROBE_AUTH_PASSWORD"
fi

if [ "$DEPLOY" = true ]; then
    echo ""
    echo "=== Redeploy ==="
    curl -sS -H "$AUTH" "$BASE_URL/deploy?uuid=$APP_UUID&force=true"
    echo ""
fi

echo ""
echo "Done. App: https://wardrobe.bartluttels.nl"
