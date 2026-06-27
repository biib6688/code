#!/bin/bash
set -e

WORKDIR="/root/tun2socks"
mkdir -p "$WORKDIR"

#echo "111.11.11.111:1111:abcd:abcd" > "$WORKDIR/ip.conf"
apt-get update -y
apt-get install -y unzip wget dnsutils iproute2

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  T2S_ARCH=amd64 ;;
    aarch64) T2S_ARCH=arm64 ;;
    armv7l)  T2S_ARCH=armv7 ;;
    *) echo "Kien truc $ARCH chua duoc ho tro tu dong. Vui long kiem tra release phu hop tai:
https://github.com/xjasonlyu/tun2socks/releases"; exit 1 ;;
esac

cd "$WORKDIR"
wget -O tun2socks.zip "https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-${T2S_ARCH}.zip"
unzip -o tun2socks.zip
mv -f tun2socks-linux-${T2S_ARCH} /usr/local/bin/tun2socks
chmod +x /usr/local/bin/tun2socks
rm -f tun2socks.zip

cat << 'EOF' > "$WORKDIR/tun2socks.sh"
#!/bin/bash
CONF_FILE="/root/tun2socks/ip.conf"
TUN_DEV="tun1"
TUN_IP="10.0.5.1/24"
TUN_GW="${TUN_IP%/*}"
GW_FILE="/tmp/tun2socks_gw"
IFACE_FILE="/tmp/tun2socks_iface"
RESOLV_BACKUP="/etc/resolv.conf.tun2socks.bak"

load_conf() {
    [ -f "$CONF_FILE" ] || { echo "Khong tim thay $CONF_FILE"; exit 1; }
    IFS=':' read -r PROXY_HOST PROXY_PORT PROXY_USER PROXY_PASS < <(head -n1 "$CONF_FILE")
    if [ -z "$PROXY_HOST" ] || [ -z "$PROXY_PORT" ] || [ -z "$PROXY_USER" ] || [ -z "$PROXY_PASS" ]; then
        echo "File ip.conf sai dinh dang. Can dung: HOST:PORT:USER:PASS"
        exit 1
    fi
}

has_resolved() { systemctl list-unit-files 2>/dev/null | grep -q systemd-resolved; }

up() {
    load_conf
    echo "Proxy: ${PROXY_HOST}:${PROXY_PORT} (User: ${PROXY_USER})"

    ip tuntap add mode tun dev "$TUN_DEV" 2>/dev/null || true
    ip addr add "$TUN_IP" dev "$TUN_DEV" 2>/dev/null || true
    ip link set dev "$TUN_DEV" up

    GW=$(ip route show default | grep -vE 'tun|docker|br-' | awk '{print $3; exit}')
    IFACE=$(ip route show default | grep -vE 'tun|docker|br-' | awk '{print $5; exit}')
    echo "$GW" > "$GW_FILE"
    echo "$IFACE" > "$IFACE_FILE"
    echo "Gateway goc: $GW qua $IFACE"

    if [ -n "$GW" ] && [ -n "$IFACE" ]; then
        ip route add "$PROXY_HOST" via "$GW" dev "$IFACE" 2>/dev/null || true
    fi
    sleep 1

    ip route del default 2>/dev/null || true
    ip route add default via "$TUN_GW" dev "$TUN_DEV" metric 1

    # Backup DNS goc (chi backup lan dau)
    if [ ! -f "$RESOLV_BACKUP" ] && [ -e /etc/resolv.conf ]; then
        cp -L /etc/resolv.conf "$RESOLV_BACKUP" 2>/dev/null || true
    fi

    if has_resolved; then
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
    fi
    rm -f /etc/resolv.conf
    cat << DNS > /etc/resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
options use-vc
DNS

    echo "Da thiet lap route + DNS qua tun2socks."
}

run() {
    load_conf
    exec /usr/local/bin/tun2socks \
        -device "$TUN_DEV" \
        -proxy "socks5://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}" \
        -loglevel info
}

down() {
    load_conf

    while ip route del default via "$TUN_GW" dev "$TUN_DEV" 2>/dev/null; do
        echo "Da xoa default route qua $TUN_DEV"
    done

    if [ -f "$GW_FILE" ] && [ -f "$IFACE_FILE" ]; then
        GW=$(cat "$GW_FILE"); IFACE=$(cat "$IFACE_FILE")
    else
        GW=$(ip route show | grep -vE 'tun|docker|br-' | awk '/default/{print $3; exit}')
        IFACE=$(ip route show | grep -vE 'tun|docker|br-' | awk '/default/{print $5; exit}')
    fi
    if [ -n "$GW" ] && [ -n "$IFACE" ]; then
        ip route add default via "$GW" dev "$IFACE" 2>/dev/null || true
    fi
    ip route del "$PROXY_HOST" 2>/dev/null || true

    ip link set dev "$TUN_DEV" down 2>/dev/null || true
    ip tuntap del mode tun dev "$TUN_DEV" 2>/dev/null || true

    if [ -f "$RESOLV_BACKUP" ]; then
        cp -L "$RESOLV_BACKUP" /etc/resolv.conf
    fi
    if has_resolved; then
        systemctl enable systemd-resolved 2>/dev/null || true
        systemctl start systemd-resolved 2>/dev/null || true
    fi

    echo "Da khoi phuc network goc."
}

case "$1" in
    up)   up ;;
    run)  run ;;
    down) down ;;
    *) echo "Dung: $0 {up|run|down}"; exit 1 ;;
esac
EOF
chmod +x "$WORKDIR/tun2socks.sh"

# ----------------------------------------------------------------
# 5. Systemd service
# ----------------------------------------------------------------
cat << 'EOF' > /etc/systemd/system/tun2socks.service
[Unit]
Description=tun2socks SOCKS5 Proxy Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStartPre=/root/tun2socks/tun2socks.sh up
ExecStart=/root/tun2socks/tun2socks.sh run
ExecStop=/root/tun2socks/tun2socks.sh down
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tun2socks
systemctl start tun2socks
