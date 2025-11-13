#!/bin/bash

# Cài đặt Openbox và TightVNC server
sudo apt install openbox tightvncserver -y

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
/etc/X11/Xsession
xsetroot -cursor_name left_ptr &
openbox-session &
EOF

chmod +x ~/.vnc/xstartup

# Khởi động lại VNC server
vncserver :1100 -geometry 1100x710 -depth 24

# Cài đặt Google Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb -y
rm -rf google-chrome-stable_current_amd64.deb
