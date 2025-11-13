#!/bin/bash

# Cài đặt XFCE và TightVNC server
wget https://mirror.cov.ukservers.com/ubuntu/pool/universe/a/autocutsel/autocutsel_0.10.0-1_amd64.deb
sudo dpkg -i autocutsel_0.10.0-1_amd64.deb
sudo apt install xfce4 xfce4-goodies tightvncserver -y

# Tạo thư mục và thiết lập mật khẩu VNC
mkdir -p ~/.vnc
echo "$PASSVNCSERVER" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Dừng VNC server nếu đang chạy
vncserver -kill :1

# Tạo file cấu hình xstartup
cat <<EOF > ~/.vnc/xstartup
#!/bin/sh

xrdb "$HOME/.Xresources"
xsetroot -solid "#ADD8E6"
export XKL_XMODMAP_DISABLE=1
autocutsel -fork
startxfce4 &
EOF

chmod +x ~/.vnc/xstartup
