#!/bin/sh
# Check Wardrobe deployment on Coolify
#
# Usage:
#   WARDROBE_APP_UUID=<uuid> ./scripts/coolify-check.sh
#   COOLIFY_TARGET=bartluttels ./scripts/coolify-check.sh

set -e

TARGET="${COOLIFY_TARGET:-bartluttels}"
HEALTH_URL="${WARDROBE_HEALTH_URL:-https://wardrobe.bartluttels.nl/api/import/config}"

case "$TARGET" in
    bartluttels)
        COOLIFY_URL="${COOLIFY_URL:-https://coolify.bartluttels.nl}"
        API_KEY="${COOLIFY_API_KEY:-${COOLIFY_API_KEY_BARTLUTTELS:-}}"
        ;;
    hotraco)
        COOLIFY_URL="${COOLIFY_URL:-https://coolify.ai.hotraco.com}"
        API_KEY="${COOLIFY_API_KEY_HOTRACO:-}"
        ;;
    *)
        echo "Unknown COOLIFY_TARGET: $TARGET"
        exit 1
        ;;
esac

echo "=== Public config check ==="
echo "GET $HEALTH_URL"
HTTP_CODE=$(curl -sS -o /tmp/wardrobe-health.json -w "%{http_code}" "$HEALTH_URL" || echo "000")
echo "HTTP $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
    cat /tmp/wardrobe-health.json
    echo ""
    python3 -c "
import json
d=json.load(open('/tmp/wardrobe-health.json'))
print('ready:', d.get('ready'))
print('hasApiKey:', d.get('hasApiKey'))
print('hasModelReference:', d.get('hasModelReference'))
" 2>/dev/null || true
else
    cat /tmp/wardrobe-health.json 2>/dev/null || true
    echo ""
fi

if [ -z "$API_KEY" ] || [ -z "$WARDROBE_APP_UUID" ]; then
    echo ""
    echo "Set WARDROBE_APP_UUID + API key for Coolify API details."
    exit 0
fi

BASE_URL="${COOLIFY_URL%/}/api/v1"
AUTH="Authorization: Bearer $API_KEY"

echo ""
echo "=== Application status ==="
curl -sS -H "$AUTH" "$BASE_URL/applications/$WARDROBE_APP_UUID" | python3 -c "
import json,sys
a=json.load(sys.stdin)
print('status:', a.get('status'))
print('fqdn:', a.get('fqdn'))
print('commit:', (a.get('git_commit_sha') or '')[:8])
" 2>/dev/null || true

echo ""
echo "=== Recent deployments ==="
curl -sS -H "$AUTH" "$BASE_URL/deployments/applications/$WARDROBE_APP_UUID" | python3 -m json.tool 2>/dev/null | head -40
