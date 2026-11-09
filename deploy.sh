#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
. /etc/os-release
[[ $EUID == 0 && $VERSION_ID == 24.04 ]]
uuid=${1:?Indique UUID ext4}
[[ $uuid =~ ^[a-fA-F0-9-]{36}$ ]]
[[ $(blkid -t UUID="$uuid" -s TYPE -o value) == ext4 ]]
mkdir -p /srv/ia
if ! findmnt --fstab --mountpoint /srv/ia >/dev/null; then
    echo "UUID=$uuid /srv/ia ext4 defaults,nodev,nosuid 0 2" >> /etc/fstab
fi
mountpoint -q /srv/ia || mount /srv/ia
[[ $(findmnt -n -o UUID --mountpoint /srv/ia) == "$uuid" ]]
apt-get update
apt-get install -y nginx ufw fail2ban python3-systemd python3-flask python3-bcrypt gunicorn sqlite3 curl openssl zstd
if ! command -v ollama >/dev/null; then
    archive=$(mktemp /srv/ia/.ollama-XXXXXX.tar.zst)
    trap 'unlink "$archive"' EXIT
    curl -4 --fail --location --silent --show-error --retry 2 --connect-timeout 15 --max-time 1800 \
        https://github.com/ollama/ollama/releases/download/v0.40.15/ollama-linux-amd64.tar.zst -o "$archive"
    printf '%s  %s\n' 628c018404a4206493efd38e46251c154ede5141b8b8dc85c659b3b027c47379 "$archive" | sha256sum -c -
    tar --zstd -xf "$archive" -C /usr/local
    unlink "$archive"
    trap - EXIT
fi
id ollama >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/ollama --shell /usr/sbin/nologin ollama
id iachat >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin iachat
install -d -m 750 -o iachat -g iachat /srv/ia/db
install -d -m 750 -o ollama -g ollama /srv/ia/models
install -d -m 700 /srv/ia/backups /etc/iachat
install -d -m 750 -g iachat /opt/iachat
install -m 640 -g iachat app.py /opt/iachat/
install -D -m 644 ollama.conf /etc/systemd/system/ollama.service.d/local.conf
if ! systemctl cat ollama.service >/dev/null 2>&1; then
    install -m 644 ollama.service /etc/systemd/system/
fi
install -m 644 iachat.service /etc/systemd/system/
if [[ ! -f /etc/iachat/env ]]; then
    (umask 077; printf 'SESSION_KEY=%s\nCHAT_MODEL=llama3.2:1b\n' "$(openssl rand -hex 32)" > /etc/iachat/env)
fi
if [[ ! -f /etc/iachat/tls.key || ! -f /etc/iachat/tls.crt ]]; then
    (umask 077; openssl req -x509 -newkey rsa:3072 -nodes -days 365 -subj /CN=localhost -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' -keyout /etc/iachat/tls.key -out /etc/iachat/tls.crt)
fi
install -m 644 nginx.conf /etc/nginx/sites-available/iachat
ln -sfn /etc/nginx/sites-available/iachat /etc/nginx/sites-enabled/iachat
unlink /etc/nginx/sites-enabled/default || test ! -e /etc/nginx/sites-enabled/default
nginx -t
ufw default deny incoming
ufw default allow outgoing
for port in 22 80 443; do ufw allow "$port/tcp"; done
ufw --force enable
install -m 644 fail2ban.conf /etc/fail2ban/jail.d/iachat.local
install -D -m 644 journal.conf /etc/systemd/journald.conf.d/iachat.conf
systemctl daemon-reload
systemctl enable nginx ollama iachat fail2ban
systemctl restart systemd-journald nginx ollama iachat fail2ban
for attempt in {1..20}; do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null; then break; fi
    sleep 1
done
ollama pull "$(sed -n 's/^CHAT_MODEL=//p' /etc/iachat/env)"
