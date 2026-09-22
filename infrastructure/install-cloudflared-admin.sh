#!/bin/bash
# Install a remotely managed Cloudflare Tunnel without exposing its token in
# argv, the environment, shell history, or the systemd unit.
set -euo pipefail

readonly TOKEN_FILE=/etc/cloudflared/tunnel-token

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi
if [ ! -s "$TOKEN_FILE" ]; then
    echo "missing $TOKEN_FILE; create it mode 0600 before running this installer" >&2
    exit 2
fi

export DEBIAN_FRONTEND=noninteractive
install -d -o root -g root -m 0755 /usr/share/keyrings
key_tmp=$(mktemp /tmp/cloudflare-main.gpg.XXXXXX)
trap 'rm -f "$key_tmp"' EXIT
curl -fsSL --proto '=https' --tlsv1.2 https://pkg.cloudflare.com/cloudflare-main.gpg -o "$key_tmp"
gpg --show-keys "$key_tmp" >/dev/null
install -o root -g root -m 0644 "$key_tmp" /usr/share/keyrings/cloudflare-main.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list
apt-get update
apt-get install -y --no-install-recommends cloudflared

# --token-file requires cloudflared 2025.4.0 or later.
version=$(cloudflared --version | sed -nE 's/.*version ([0-9]+)\.([0-9]+)\.([0-9]+).*/\1 \2 \3/p')
read -r year month patch <<<"$version"
if [ -z "${year:-}" ] || [ "$year" -lt 2025 ] || { [ "$year" -eq 2025 ] && [ "$month" -lt 4 ]; }; then
    echo "cloudflared 2025.4.0 or later is required; found: $(cloudflared --version)" >&2
    exit 1
fi

id cloudflared >/dev/null 2>&1 || useradd --system --home-dir /var/lib/cloudflared --create-home --shell /usr/sbin/nologin cloudflared
chown root:cloudflared "$TOKEN_FILE"
chmod 0640 "$TOKEN_FILE"

cat > /etc/systemd/system/cloudflared.service <<'EOF'
[Unit]
Description=Cloudflare Tunnel for Parallel Works administration
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=cloudflared
Group=cloudflared
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --metrics 127.0.0.1:2000 run --token-file /etc/cloudflared/tunnel-token
Restart=on-failure
RestartSec=5s
TimeoutStartSec=60
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cloudflared.service
for attempt in $(seq 1 15); do
    systemctl is-active --quiet cloudflared.service && curl -fsS http://127.0.0.1:2000/ready >/dev/null && break
    sleep 2
done
systemctl is-active --quiet cloudflared.service
curl -fsS http://127.0.0.1:2000/ready
ss -ltn | grep -qE '127\.0\.0\.1:(3000|3001|2000)'
echo "Cloudflare Tunnel is connected; complete hostname and Access policy checks from an unauthenticated browser."
