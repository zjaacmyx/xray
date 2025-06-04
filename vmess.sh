#!/bin/bash
set -e

UUID="1483c30c-ae2c-4130-f643-c6139d199c42"
PORT=21000
XRAY_DIR="/usr/local/share/xray"
CONFIG_FILE="/usr/local/etc/xray/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"

echo "📦 安装 Xray Core（VMess）..."

apt update
apt install -y curl unzip sudo

sudo mkdir -p "$XRAY_DIR"
sudo mkdir -p "$(dirname $CONFIG_FILE)"

curl -L -o /tmp/Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip
unzip -o /tmp/Xray-linux-64.zip -d /tmp/xray

sudo install -m 755 /tmp/xray/xray /usr/local/bin/xray
sudo install -m 644 /tmp/xray/geoip.dat "$XRAY_DIR/"
sudo install -m 644 /tmp/xray/geosite.dat "$XRAY_DIR/"

sudo tee $CONFIG_FILE > /dev/null <<EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [{"id": "$UUID", "alterId": 0}]
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

sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config $CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable xray
sudo systemctl restart xray

IP=$(curl -s ifconfig.me)
echo "✅ VMess 部署成功！"
echo "----------------------------------------"
echo "地址: $IP"
echo "端口: $PORT"
echo "UUID: $UUID"
echo "传输: ws"
echo "路径: /ray"
echo "加密: auto"
echo "alterId: 0"
echo "----------------------------------------"

# 输出 vmess 链接
json=$(cat <<JSON
{
  "v": "2",
  "ps": "vmess-node",
  "add": "$IP",
  "port": "$PORT",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "/ray",
  "tls": "none"
}
JSON
)

vmess_link="vmess://$(echo -n "$json" | base64 -w0)"
echo "📎 VMess 链接："
echo "$vmess_link"
