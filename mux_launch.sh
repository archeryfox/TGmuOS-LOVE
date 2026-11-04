#!/bin/sh
# HELP: Telegram
# ICON: telegram
# GRID: Telegram

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

BASE_DIR="$1"
[ -z "$BASE_DIR" ] && BASE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$BASE_DIR" || exit 1

RUNTIME=/mnt/mmc/MUOS/PortMaster/runtimes/love_11.5
if [ ! -x "$RUNTIME/love.aarch64" ]; then
    printf '%s\n' "LÖVE runtime not found: $RUNTIME/love.aarch64" >"$BASE_DIR/log.txt"
    exit 1
fi

export LD_LIBRARY_PATH="$RUNTIME/libs.aarch64:$LD_LIBRARY_PATH"
mkdir -p /root/.config/Telegram
chmod 700 /root/.config/Telegram
exec "$RUNTIME/love.aarch64" "$BASE_DIR" >"$BASE_DIR/log.txt" 2>&1
