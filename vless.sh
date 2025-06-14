#!/bin/bash
set -e

UUID="1483c30c-ae2c-4130-f643-c6139d199c42"
PORT=20000
XRAY_DIR="/usr/local/share/xray"
CONFIG_FILE="/usr/local/etc/xray/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"

echo "📦 安装 Xray Core v1.8.4..."

apt update
apt install -y curl unzip socat
apt install -y sudo

# 创建目录
sudo mkdir -p "$XRAY_DIR"
sudo mkdir -p "$(dirname $CONFIG_FILE)"

# 下载并解压 Xray
curl -L -o /tmp/Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip
unzip -o /tmp/Xray-linux-64.zip -d /tmp/xray

sudo install -m 755 /tmp/xray/xray /usr/local/bin/xray
sudo install -m 644 /tmp/xray/geoip.dat "$XRAY_DIR/"
sudo install -m 644 /tmp/xray/geosite.dat "$XRAY_DIR/"

# 写配置文件
sudo tee $CONFIG_FILE > /dev/null <<EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$UUID"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/ray"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# 写 systemd 服务文件
sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray -config $CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd，启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable xray
sudo systemctl restart xray

echo "✅ Xray 安装完成，VLESS+WS 节点已启动！"
echo "-----------------------------------------"
echo "地址: $(curl -s ifconfig.me)"
echo "端口: $PORT"
echo "UUID : $UUID"
echo "传输: ws"
echo "路径: /ray"
echo "-----------------------------------------"
