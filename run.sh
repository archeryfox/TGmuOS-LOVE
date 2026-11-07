#!/bin/sh
# PC launcher for the Telegram LÖVE client.
# Credentials are taken from environment variables (preferred) or a config file.
#
# Usage:
#   TG_API_ID=12345 TG_API_HASH=abcdef ./run.sh
#   ./run.sh                       # reads ~/.config/love_tg_native/telegram.conf
#   TG_CONFIG=/path/to/telegram.conf ./run.sh
#
# Config file format (telegram.conf):
#   api_id=12345
#   api_hash=abcdef
#   proxy_type=mtproto            # optional
#   proxy_server=...
#   proxy_port=...
#   proxy_secret=...

set -eu

BASE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$BASE_DIR" || exit 1

# Load credentials from a local config file if env vars are not set.
if [ -z "${TG_API_ID:-}" ] || [ -z "${TG_API_HASH:-}" ]; then
    CONF="${TG_CONFIG:-$HOME/.config/love_tg_native/telegram.conf}"
    if [ -f "$CONF" ]; then
        # shellcheck disable=SC1090
        . "$CONF" 2>/dev/null || true
        [ -n "${api_id:-}" ]   && export TG_API_ID="${TG_API_ID:-$api_id}"
        [ -n "${api_hash:-}" ] && export TG_API_HASH="${TG_API_HASH:-$api_hash}"
    fi
fi

if [ -z "${TG_API_ID:-}" ] || [ -z "${TG_API_HASH:-}" ]; then
    echo "ERROR: TG_API_ID and TG_API_HASH are required." >&2
    echo "Set them as env vars or put api_id/api_hash in telegram.conf." >&2
    exit 1
fi

# Use bundled ARM64 lib only on device; on PC rely on system TDLib.
export LD_LIBRARY_PATH="$BASE_DIR/lib:${LD_LIBRARY_PATH:-}"

LOVE="${LOVE_BIN:-love}"
exec "$LOVE" "$BASE_DIR" "$@"
