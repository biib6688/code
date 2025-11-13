#!/bin/bash

sudo apt install squid -y
sudo apt-get install apache2-utils -y
sudo rm /etc/squid/squid.conf

# Tao tap tin cau hinh Squid moi
sudo bash -c 'cat << EOF > /etc/squid/squid.conf
# Cau hinh xac thuc co ban
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm proxy

# ACL cho xac thuc
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

# Cau hinh cong
http_port $PORTPROXY

# Cau hinh cache directory
cache_dir ufs /var/spool/squid 100 16 256

# Toi uu hoa cache
cache_mem 256 MB
maximum_object_size 4 MB
minimum_object_size 0 KB

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log /var/log/squid/store.log

# Tham so hieu suat khac
maximum_object_size_in_memory 8 MB
cache_swap_low 90
cache_swap_high 95

# Access Control Lists (ACLs) va quy tac truy cap
acl localnet src 192.168.0.0/16
acl localhost src 127.0.0.1/32

http_access allow localhost
http_access allow localnet
http_access deny all

EOF'

sudo sed -i "s/^http_port.*/http_port $PORTPROXY/" /etc/squid/squid.conf

# Tao mat khau
sudo htpasswd -b -c /etc/squid/passwords $USERPROXY $PASSPROXY

# Khoi dong lai squid
sudo systemctl restart squid.service

echo "Finish."
