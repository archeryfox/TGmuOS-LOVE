#!/bin/sh
# Background Telegram notification service for muOS
# Runs TDLib in background, shows notifications via framebuffer

BASE_DIR="/mnt/mmc/MUOS/application/Telegram"
RUNTIME="/mnt/mmc/MUOS/application/CTupe"
export LD_LIBRARY_PATH="$RUNTIME/bin/libs.aarch64:$LD_LIBRARY_PATH"

# Check if already running
if pgrep -f "tg_background_service" | grep -v $$ > /dev/null 2>&1; then
    echo "Already running"
    exit 0
fi

# Start background LÖVE instance with notification-only mode
exec "$RUNTIME/bin/love" "$BASE_DIR" --background-notification 2>&1 &
