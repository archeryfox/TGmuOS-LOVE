#!/bin/sh
BASE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$BASE_DIR" || exit 1
if [ -z "${TG_API_ID:-}" ] || [ -z "${TG_API_HASH:-}" ]; then
  CONF="${TG_CONFIG:-$HOME/.config/love_tg_native/telegram.conf}"
  [ -f "$CONF" ] && . "$CONF" 2>/dev/null || true
  [ -n "${api_id:-}" ] && export TG_API_ID="${TG_API_ID:-$api_id}"
  [ -n "${api_hash:-}" ] && export TG_API_HASH="${TG_API_HASH:-$api_hash}"
fi
export TG_API_ID="${TG_API_ID:-}"
export TG_API_HASH="${TG_API_HASH:-}"
export LD_LIBRARY_PATH="$BASE_DIR/lib:${LD_LIBRARY_PATH:-}"
LOVE="${LOVE_BIN:-love}"
exec "$LOVE" "$BASE_DIR" "$@"
