#!/bin/bash

# Kiểm tra biến môi trường
if [[ -z "$PORTPROXY" || -z "$USERPROXY" || -z "$PASSPROXY" ]]; then
  echo "❌ Thiếu biến môi trường. Vui lòng export các biến sau:"
  echo "   PORTPROXY, USERPROXY, PASSPROXY"
  exit 1
fi

SOCKSPORT=$((PORTPROXY + 1))

# Cài Squid (HTTP proxy)
sudo apt update
sudo apt install squid apache2-utils -y
sudo rm -f /etc/squid/squid.conf

# Cấu hình Squid
sudo bash -c "cat << EOF > /etc/squid/squid.conf
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

http_port $PORTPROXY

cache_dir ufs /var/spool/squid 100 16 256
cache_mem 256 MB
maximum_object_size 4 MB
minimum_object_size 0 KB

access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log /var/log/squid/store.log

maximum_object_size_in_memory 8 MB
cache_swap_low 90
cache_swap_high 95

acl localnet src 192.168.0.0/16
acl localhost src 127.0.0.1/32
http_access allow localhost
http_access allow localnet
http_access deny all
EOF"

# Tạo tài khoản cho Squid (HTTP proxy)
sudo htpasswd -b -c /etc/squid/passwords "$USERPROXY" "$PASSPROXY"
sudo systemctl restart squid.service

# Cài Dante (SOCKS5 proxy)
sudo apt install dante-server -y

# Tạo user hệ thống (nếu chưa tồn tại)
if ! id "$USERPROXY" &>/dev/null; then
  sudo useradd -M -s /usr/sbin/nologin "$USERPROXY"
fi
echo "$USERPROXY:$PASSPROXY" | sudo chpasswd

# Lấy interface mạng
INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

# Cấu hình Dante
sudo bash -c "cat << EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $SOCKSPORT
external: $INTERFACE

method: username
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    method: username
    log: connect disconnect error
}
EOF"

sudo systemctl restart danted

# Hoàn tất
echo "✅ Hoàn tất cấu hình proxy:"
echo "🔌 HTTP Proxy  : http://<IP>:$PORTPROXY (user: $USERPROXY)"
echo "🧦 SOCKS5 Proxy: socks5://<IP>:$SOCKSPORT (user: $USERPROXY)"
