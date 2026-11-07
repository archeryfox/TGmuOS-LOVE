#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUTPUT=${1:-"$ROOT/dist/Telegram.zip"}
case "$OUTPUT" in
    /*) ;;
    *) OUTPUT="$ROOT/$OUTPUT" ;;
esac

mkdir -p -- "$(dirname -- "$OUTPUT")"
cd "$ROOT"
zip -qrFS "$OUTPUT" \
    conf.lua main.lua dkjson.lua qr.lua lib src threads fonts res icon.png glyph \
    gameinfo.xml mux_launch.sh README.md tools tg_background_service.sh
printf 'Built %s\n' "$OUTPUT"
