#!/bin/sh
# ssh_tgkill.sh - kill Telegram on device via SSH
HOST=${1:-192.168.43.182}
USER=${2:-root}
PASS=${3:-root}
export DISPLAY=:0
export SSH_ASKPASS=/tmp/kilo/askpass.sh
printf '#!/bin/sh\necho %s\n' "$PASS" > /tmp/kilo/askpass.sh
chmod +x /tmp/kilo/askpass.sh
setsid ssh -o StrictHostKeyChecking=no "$USER@$HOST" "sh /mnt/mmc/MUOS/application/Telegram/tools/tgkill.sh" >/tmp/tgkill_remote.log 2>&1
echo "done"