#!/bin/sh
APPDIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$APPDIR" || exit 1
if [ -z "${TG_API_ID:-}" ] || [ -z "${TG_API_HASH:-}" ]; then
  [ -f "$HOME/.config/love_tg_native/telegram.conf" ] && . "$HOME/.config/love_tg_native/telegram.conf" 2>/dev/null
  [ -n "${api_id:-}" ] && export TG_API_ID="${TG_API_ID:-$api_id}"
  [ -n "${api_hash:-}" ] && export TG_API_HASH="${TG_API_HASH:-$api_hash}"
fi
export TG_API_ID
export TG_API_HASH
export LÖVE_PATH="$APPDIR"
LOVE_BIN="$(command -v love 2>/dev/null || command -v love11 2>/dev/null || command -v love2d 2>/dev/null || echo /usr/bin/love)"
exec "$LOVE_BIN" "$APPDIR" "$@"
