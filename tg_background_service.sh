#!/bin/sh
# Background Telegram notification service for muOS
# Runs TDLib in background, shows notifications via framebuffer

BASE_DIR="/mnt/mmc/MUOS/application/Telegram"
RUNTIME="/mnt/mmc/MUOS/application/CTupe"
PIDFILE="/run/tgmuos_bg.pid"
export LD_LIBRARY_PATH="$RUNTIME/bin/libs.aarch64:$LD_LIBRARY_PATH"

# Check if already running
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "Already running (pid $pid)"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# Start background LÖVE instance with notification-only mode
"$RUNTIME/bin/love" "$BASE_DIR" --background-notification >/dev/null 2>&1 &
pid=$!
echo "$pid" > "$PIDFILE"
echo "Started background service (pid $pid)"
