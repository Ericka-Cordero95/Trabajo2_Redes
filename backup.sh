#!/bin/bash
set -euo pipefail
[[ $EUID == 0 ]]
mountpoint -q /srv/ia
umask 077
temp=$(mktemp /srv/ia/backups/.sqlite.XXXXXX)
trap 'unlink "$temp"' EXIT
db=/srv/ia/db/chat.sqlite
if [[ ${1:-} == restore ]]; then
    tar -xOzf "${2:?Indique un respaldo propio}" chat.sqlite > "$temp"
    [[ $(sqlite3 "$temp" 'PRAGMA integrity_check') == ok ]]
    systemctl stop iachat
    trap 'systemctl start iachat; test ! -e "$temp" || unlink "$temp"' EXIT
    chown iachat:iachat "$temp"
    mv -f "$temp" "$db"
else
    sqlite3 "$db" ".backup '$temp'"
    [[ $(sqlite3 "$temp" 'PRAGMA integrity_check') == ok ]]
    file=$(mktemp /srv/ia/backups/chat-XXXXXX.tar.gz)
    name=$(basename "$temp")
    tar -czf "$file" --transform="s|^$name$|chat.sqlite|" -C /srv/ia/backups "$name" -C / etc/fstab etc/nginx/sites-available/iachat etc/systemd/system/iachat.service etc/systemd/system/ollama.service.d/local.conf etc/fail2ban/jail.d/iachat.local
    echo "$file"
fi
