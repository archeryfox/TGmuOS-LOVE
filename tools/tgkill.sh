#!/bin/sh
# tgkill.sh - kill every Telegram client process on the device, including
# multiple Telegram instances, the legacy tgmuos binary and its sing-box.
set -u

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SELF=$$
PARENT=$PPID
LOG=/tmp/tgkill.log

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')" "$*" >>"$LOG" 2>/dev/null
}

: >"$LOG" 2>/dev/null || true
log "tgkill start: app=$APP_DIR self=$SELF"

is_app_path() {
    case "$1" in
        *Telegram*) return 0 ;;
    esac
    return 1
}

collect() {
    pid=$1
    [ "$pid" = "$SELF" ] && return
    [ "$pid" = "$PARENT" ] && return
    [ -r "/proc/$pid/cmdline" ] || return

    comm=$(cat "/proc/$pid/comm" 2>/dev/null || true)
    cmd=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)

    case "$comm" in
        love.aarch64|love)
            if is_app_path "$cwd" || is_app_path "$cmd"; then
                printf '%s\n' "$pid"
            fi
            ;;
        tgmuos|Telegram|tgmuos.bin)
            printf '%s\n' "$pid"
            ;;
        sing-box*)
            if is_app_path "$cmd" || is_app_path "$cwd"; then
                printf '%s\n' "$pid"
            fi
            ;;
    esac
}

stop_pids() {
    signal=$1
    shift
    [ -z "${*:-}" ] && return 0
    log "SIG$signal -> $*"
    for pid in "$@"; do
        kill -"$signal" "$pid" 2>/dev/null || true
    done
}

# Prevent muOS from relaunching the app while we clean up.
rm -f /tmp/app_go 2>/dev/null || true

PIDS=$(for entry in /proc/[0-9]*; do collect "${entry#/proc/}"; done | sort -n | uniq)
if [ -n "$PIDS" ]; then
    log "found: $(printf '%s ' $PIDS)"
    stop_pids TERM $PIDS
    i=0
    while [ "$i" -lt 25 ]; do
        alive=""
        for pid in $PIDS; do
            kill -0 "$pid" 2>/dev/null && alive="$alive $pid"
        done
        [ -z "$alive" ] && break
        sleep 0.2
        i=$((i + 1))
    done
    if [ -n "${alive:-}" ]; then
        stop_pids KILL $alive
    fi
else
    log "no Telegram processes found"
fi

sleep 1
printf 'launcher\n' >/tmp/act_go 2>/dev/null || true

LEFT=$(for entry in /proc/[0-9]*; do collect "${entry#/proc/}"; done | sort -n | uniq)
log "tgkill done; remaining: ${LEFT:-none}"
