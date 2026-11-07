#!/bin/bash
# =============================================================================
# monitor.sh — TGmuOS system & Telegram client monitor
#
# Крутой инструмент диагностики для Telegram клиента на Anbernic RG35XX SP.
# Показывает в реальном времени: процессы, память, CPU, состояние TDLib auth,
# последние логи, сетевое соединение и прокси.
#
# Запуск на устройстве:
#   ./tools/monitor.sh          # локально на muOS
#   ssh root@DEVICE "./tools/monitor.sh"   # удалённо по SSH
#
# Опции:
#   --once    один снимок состояния и выход
#   --interval N   обновление каждые N секунд (по умолчанию 2)
#   --follow    не очищать экран между кадрами (как tail -f)
# =============================================================================

set -u

DEVICE_IP="${DEVICE_IP:-192.168.0.151}"
APP_DIR="/mnt/mmc/MUOS/application/Telegram"
LOG_FILE="$APP_DIR/log.txt"
TDLIB_LOG="$APP_DIR/tdlib.log"
CONF_FILE="$APP_DIR/telegram.conf"
INTERVAL=2
ONCE=0
FOLLOW=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --once) ONCE=1; shift ;;
        --interval) INTERVAL="${2:-2}"; shift 2 ;;
        --follow) FOLLOW=1; shift ;;
        --ip) DEVICE_IP="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; shift ;;
    esac
done

if [[ $ONCE -eq 1 ]]; then
    FOLLOW=1
fi

# Remote exec helper — если ssh аргумент передан, выполняем на устройстве
REMOTE=""
if [[ -n "${SSH_TARGET:-}" ]]; then
    REMOTE="ssh $SSH_TARGET"
fi

run() {
    if [[ -n "$REMOTE" ]]; then
        $REMOTE "$1" 2>/dev/null
    else
        eval "$1" 2>/dev/null
    fi
}

header() {
    if [[ $FOLLOW -eq 0 ]]; then
        clear
    fi
    echo "================================================================================"
    echo "  TGmuOS MONITOR  —  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
}

section() {
    echo ""
    echo "--- $1 ---"
}

proc_info() {
    section "PROCESSES"
    run "ps aux | grep -E '[T]elegram|[l]ove|[s]ing-box|[t]dlib' | head -20"
    echo ""
    local tg_pid
    tg_pid=$(run "pgrep -f '[T]elegram' | head -1")
    if [[ -n "$tg_pid" ]]; then
        echo "Telegram PID: $tg_pid"
        run "cat /proc/$tg_pid/status 2>/dev/null | grep -E 'VmRSS|VmSize|Threads|State'"
    else
        echo "Telegram: НЕ ЗАПУЩЕН"
    fi
}

mem_info() {
    section "MEMORY"
    run "free -h 2>/dev/null || cat /proc/meminfo | head -10"
    echo ""
    run "df -h /mnt/mmc 2>/dev/null || df -h ."
}

auth_state() {
    section "TDLIB AUTH STATE"
    if [[ -f "$LOG_FILE" ]]; then
        run "tail -30 $LOG_FILE | grep -E 'authorizationState|WaitPhoneNumber|WaitCode|WaitOtherDevice|encryptionKey|phoneNumber|error' | tail -15"
    else
        echo "Лог не найден: $LOG_FILE"
    fi
}

network() {
    section "NETWORK & PROXY"
    run "ip addr show 2>/dev/null | grep -E 'inet ' | head -5"
    echo ""
    run "curl -s --connect-timeout 5 -o /dev/null -w 'Telegram API: %{http_code}\n' https://api.telegram.org 2>&1 || echo 'Telegram API: unreachable'"
    run "curl -x socks5h://127.0.0.1:10808 --connect-timeout 5 -o /dev/null -w 'Via Proxy: %{http_code}\n' https://api.telegram.org 2>&1 || echo 'Via Proxy: unreachable'"
}

recent_logs() {
    section "RECENT LOGS (последние 12 строк)"
    if [[ -f "$LOG_FILE" ]]; then
        run "tail -12 $LOG_FILE"
    else
        echo "Лог не найден: $LOG_FILE"
    fi
}

config() {
    section "CONFIG"
    if [[ -f "$CONF_FILE" ]]; then
        run "grep -v '^#' $CONF_FILE | grep -v '^$' | head -20"
    else
        echo "Конфиг не найден: $CONF_FILE"
    fi
}

render() {
    header
    proc_info
    mem_info
    auth_state
    network
    config
    recent_logs
    echo ""
    echo "Нажмите Ctrl+C для остановки | интервал: ${INTERVAL}s"
}

if [[ $ONCE -eq 1 ]]; then
    render
    exit 0
fi

while true; do
    render
    sleep "$INTERVAL"
done
