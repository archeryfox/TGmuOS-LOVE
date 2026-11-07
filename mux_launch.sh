#!/bin/sh
# HELP: Telegram
# ICON: telegram
# GRID: Telegram

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "Telegram"

BASE_DIR="$1"
[ -z "$BASE_DIR" ] && BASE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$BASE_DIR" || exit 1

# Pick the Telegram config file available on the device.
if [ -z "${TG_CONFIG:-}" ]; then
    for c in /root/.config/Telegram/telegram.conf /root/.config/tgmuos_love/telegram.conf /root/.config/love_tg_native/telegram.conf; do
        if [ -f "$c" ]; then
            TG_CONFIG="$c"
            break
        fi
    done
fi
[ -n "${TG_CONFIG:-}" ] && export TG_CONFIG

RUNTIME=/mnt/mmc/MUOS/PortMaster/runtimes/love_11.5
if [ ! -x "$RUNTIME/love.aarch64" ]; then
    printf '%s\n' "LÖVE runtime not found: $RUNTIME/love.aarch64" >"$BASE_DIR/log.txt"
    exit 1
fi

export LD_LIBRARY_PATH="$RUNTIME/libs.aarch64:$LD_LIBRARY_PATH"
mkdir -p /root/.config/Telegram
chmod 700 /root/.config/Telegram
exec "$RUNTIME/love.aarch64" "$BASE_DIR" >"$BASE_DIR/log.txt" 2>&1
