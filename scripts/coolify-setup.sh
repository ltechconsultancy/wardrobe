#!/bin/sh
# Deploy Wardrobe on Coolify (bartluttels.nl)
#
# Usage:
#   COOLIFY_TARGET=bartluttels ./scripts/coolify-setup.sh
#
# Prerequisites:
#   - OPENAI_API_KEY in Coolify env (or PocketDev credential OPENAI_API_KEY)
#   - Upload model-reference.png to /app/data/model-reference.png after first deploy

set -e

TARGET="${COOLIFY_TARGET:-bartluttels}"
APP_NAME="${WARDROBE_APP_NAME:-wardrobe}"
DOMAIN="${WARDROBE_DOMAIN:-https://wardrobe.bartluttels.nl}"
GIT_REPO="${WARDROBE_GIT_REPO:-https://github.com/ltechconsultancy/wardrobe}"
GIT_BRANCH="${WARDROBE_GIT_BRANCH:-main}"
PORT="${WARDROBE_PORT:-4173}"
MOUNT_PATH="/app/data"
VOLUME_NAME="wardrobe-data"

case "$TARGET" in
    bartluttels)
        COOLIFY_URL="${COOLIFY_URL:-https://coolify.bartluttels.nl}"
        API_KEY="${COOLIFY_API_KEY:-${COOLIFY_API_KEY_BARTLUTTELS:-}}"
        PROJECT_UUID="${WARDROBE_PROJECT_UUID:-t4gg0wggscww4kg48k00g8os}"
        SERVER_UUID="${WARDROBE_SERVER_UUID:-awo4cg4k0gwssss4osgwcw0o}"
        ;;
    hotraco)
        COOLIFY_URL="${COOLIFY_URL:-https://coolify.ai.hotraco.com}"
        API_KEY="${COOLIFY_API_KEY_HOTRACO:-}"
        PROJECT_UUID="${WARDROBE_PROJECT_UUID:-}"
        SERVER_UUID="${WARDROBE_SERVER_UUID:-}"
        ;;
    *)
        echo "Unknown COOLIFY_TARGET: $TARGET"
        exit 1
        ;;
esac

if [ -z "$API_KEY" ]; then
    echo "Set COOLIFY_API_KEY_BARTLUTTELS (or COOLIFY_API_KEY_HOTRACO for hotraco)"
    exit 1
fi

BASE_URL="${COOLIFY_URL%/}/api/v1"
AUTH="Authorization: Bearer $API_KEY"

if [ -n "$WARDROBE_APP_UUID" ]; then
    APP_UUID="$WARDROBE_APP_UUID"
else
    echo "=== Create Coolify application: $APP_NAME ==="
    CREATE=$(curl -sS -w "\nHTTP:%{http_code}" -X POST "$BASE_URL/applications/public" \
        -H "$AUTH" \
        -H "Content-Type: application/json" \
        -d "{
            \"project_uuid\": \"$PROJECT_UUID\",
            \"server_uuid\": \"$SERVER_UUID\",
            \"environment_name\": \"production\",
            \"name\": \"$APP_NAME\",
            \"description\": \"AI wardrobe - tandpfun/wardrobe fork\",
            \"git_repository\": \"$GIT_REPO\",
            \"git_branch\": \"$GIT_BRANCH\",
            \"build_pack\": \"dockerfile\",
            \"ports_exposes\": \"$PORT\",
            \"domains\": \"$DOMAIN\",
            \"health_check_enabled\": true,
            \"health_check_path\": \"/api/import/config\",
            \"health_check_port\": \"$PORT\",
            \"instant_deploy\": false
        }")
    HTTP=$(printf '%s' "$CREATE" | tail -1 | sed 's/HTTP://')
    BODY=$(printf '%s' "$CREATE" | sed '$d')
    if [ "$HTTP" != "201" ] && [ "$HTTP" != "200" ]; then
        echo "Failed to create application ($HTTP)"
        echo "$BODY"
        exit 1
    fi
    APP_UUID=$(printf '%s' "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('uuid',''))")
    echo "Created app UUID: $APP_UUID"
fi

echo "=== Ensure persistent storage at $MOUNT_PATH ==="
LIST=$(curl -sS -H "$AUTH" "$BASE_URL/applications/$APP_UUID/storages" 2>/dev/null || true)
if ! printf '%s' "$LIST" | python3 -c "
import json,sys
raw=sys.stdin.read()
try:
    data=json.loads(raw) if raw.strip() else []
except json.JSONDecodeError:
    sys.exit(1)
items=data if isinstance(data,list) else data.get('storages', data.get('data', []))
for s in items:
    if s.get('mount_path') == '$MOUNT_PATH':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    RESP=$(curl -sS -w "\nHTTP:%{http_code}" -X POST "$BASE_URL/applications/$APP_UUID/storages" \
        -H "$AUTH" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"persistent\",\"name\":\"$VOLUME_NAME\",\"mount_path\":\"$MOUNT_PATH\"}")
    HTTP=$(printf '%s' "$RESP" | tail -1 | sed 's/HTTP://')
    BODY=$(printf '%s' "$RESP" | sed '$d')
    if [ "$HTTP" = "201" ] || [ "$HTTP" = "200" ]; then
        echo "Storage created."
    else
        echo "Storage API unavailable ($HTTP). Add manually in Coolify UI:"
        echo "  Persistent Storages → name=$VOLUME_NAME, mount path=$MOUNT_PATH"
        echo "$BODY"
    fi
else
    echo "Storage already mounted."
fi

echo "=== Set environment variables ==="
set_env() {
    key="$1"
    value="$2"
  is_literal="$3"
    [ -z "$value" ] && return 0
    curl -sS -X POST "$BASE_URL/applications/$APP_UUID/envs" \
        -H "$AUTH" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$key\",\"value\":\"$value\",\"is_literal\":$is_literal}" >/dev/null 2>&1 || true
}

set_env "WARDROBE_DATA_DIR" "/app/data" true
set_env "WARDROBE_MODEL_REFERENCE" "/app/data/model-reference.png" true
set_env "PORT" "$PORT" true
set_env "NODE_ENV" "production" true

if [ -n "${OPENAI_API_KEY:-}" ]; then
    set_env "OPENAI_API_KEY" "$OPENAI_API_KEY" false
    echo "OPENAI_API_KEY set from environment."
else
    echo "WARNING: OPENAI_API_KEY not set locally — add it in Coolify UI before using import."
fi

echo ""
echo "=== Deploy ==="
curl -sS -H "$AUTH" "$BASE_URL/deploy?uuid=$APP_UUID&force=true"
echo ""
echo ""
echo "App UUID: $APP_UUID"
echo "URL: $DOMAIN"
echo ""
echo "After deploy:"
echo "  1. Upload your photo to /app/data/model-reference.png (Coolify → Files or SFTP)"
echo "  2. Confirm OPENAI_API_KEY in Coolify → Environment"
echo "  3. Open $DOMAIN"
