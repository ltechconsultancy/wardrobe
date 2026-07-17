#!/bin/sh
# Upload a local image as the wardrobe model reference (PNG on persistent volume).
#
# Usage:
#   ./scripts/upload-model-reference.sh /path/to/photo.jpg
#   WARDROBE_URL=https://wardrobe.bartluttels.nl \
#     WARDROBE_AUTH_USER=wardrobe WARDROBE_AUTH_PASSWORD=... \
#     ./scripts/upload-model-reference.sh ./photo.png

set -e

IMAGE_PATH="${1:-}"
BASE_URL="${WARDROBE_URL:-https://wardrobe.bartluttels.nl}"
AUTH_USER="${WARDROBE_AUTH_USER:-wardrobe}"
AUTH_PASSWORD="${WARDROBE_AUTH_PASSWORD:-}"

if [ -z "$IMAGE_PATH" ] || [ ! -f "$IMAGE_PATH" ]; then
    echo "Usage: $0 /path/to/photo.jpg"
    exit 1
fi

if [ -z "$AUTH_PASSWORD" ]; then
    echo "Set WARDROBE_AUTH_PASSWORD"
    exit 1
fi

TMP_JSON="/tmp/wardrobe-model-reference-upload.json"
python3 - "$IMAGE_PATH" "$TMP_JSON" <<'PY'
import base64
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
payload = source.read_bytes()
if source.suffix.lower() in {".jpg", ".jpeg"}:
    from PIL import Image
    import io
    img = Image.open(io.BytesIO(payload)).convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    payload = buf.getvalue()
    mime = "image/png"
elif source.suffix.lower() == ".png":
    mime = "image/png"
else:
    mime = "application/octet-stream"

encoded = base64.b64encode(payload).decode("ascii")
Path(sys.argv[2]).write_text(
    json.dumps({"imageDataUrl": f"data:{mime};base64,{encoded}"}),
    encoding="utf-8",
)
PY

echo "Uploading $(basename "$IMAGE_PATH") to $BASE_URL ..."
HTTP_CODE=$(curl -sS -o /tmp/wardrobe-model-reference-response.json -w "%{http_code}" \
    -u "$AUTH_USER:$AUTH_PASSWORD" \
    -H "Content-Type: application/json" \
    --data-binary "@$TMP_JSON" \
    "$BASE_URL/api/import/model-reference")

echo "HTTP $HTTP_CODE"
cat /tmp/wardrobe-model-reference-response.json
echo ""

if [ "$HTTP_CODE" != "200" ]; then
    exit 1
fi

rm -f "$TMP_JSON"
