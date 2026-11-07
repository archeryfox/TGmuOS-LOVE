#!/bin/sh
# tgclose.sh - stop TGMUOS (LOVE) on muOS from any SSH session.
# Usage:
#   tgclose.sh        stop the Telegram app (love.aarch64)
#   tgclose.sh -a     also stop sing-box
#   tgclose.sh -h     show help
set -u

also_proxy=0
case "${1:-}" in
    -a|--all) also_proxy=1 ;;
    -h|--help)
        echo "Usage: tgclose.sh [-a]"
        echo "  (no args)  stop love.aarch64 (TGMUOS)"
        echo "  -a         also stop sing-box"
        exit 0
        ;;
esac

stop_pids() {
    label="$1"
    shift
    [ -z "${*:-}" ] && { echo "$label: not running"; return; }
    echo "$label: stopping $*"
    kill -TERM $* 2>/dev/null
    i=0
    while [ "$i" -lt 10 ]; do
        alive=""
        for pid in $*; do
            kill -0 "$pid" 2>/dev/null && alive="$alive $pid"
        done
        [ -z "$alive" ] && break
        sleep 0.3
        i=$((i + 1))
    done
    if [ -n "$alive" ]; then
        echo "$label: force killing$alive"
        for pid in $alive; do kill -9 "$pid" 2>/dev/null; done
    fi
}

love_pids=$(ps -eo pid,comm | awk '$2 == "love.aarch64" {print $1}')
stop_pids "love.aarch64" $love_pids

if [ "$also_proxy" = 1 ]; then
    proxy_pids=$(ps -eo pid,comm | awk '$2 ~ /^sing-box/ {print $1}')
    stop_pids "sing-box" $proxy_pids
fi

# Tell the muOS frontend to go back to the launcher instead of relaunching.
if [ -e /tmp/act_go ]; then
    printf 'launcher\n' > /tmp/act_go 2>/dev/null
fi

sleep 0.5
left=$(ps -eo comm | awk '$1 == "love.aarch64"' | wc -l)
echo "remaining love.aarch64: $left"
