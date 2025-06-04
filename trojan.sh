#!/bin/bash
set -e

# 你的 UUID 和端口
UUID="1483c30c-ae2c-4130-f643-c6139d199c42"
PORT=30000
DOMAIN="yourdomain.com"
XRAY_DIR="/usr/local/share/xray"
CONFIG_FILE="/usr/local/etc/xray/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"

echo "📦 安装依赖和 Xray Core v1.8.4..."

# 安装依赖
apt update
apt install -y curl unzip socat

# 安装 acme.sh
curl https://get.acme.sh | sh
export PATH="$HOME/.acme.sh:$PATH"

# 申请证书
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --force

# 安装证书到指定位置
CERT_DIR="/etc/xray/cert"
mkdir -p $CERT_DIR
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
  --key-file $CERT_DIR/private.key \
  --fullchain-file $CERT_DIR/fullchain.pem \
  --reloadcmd "systemctl restart xray"

# 下载并安装 Xray
mkdir -p "$XRAY_DIR"
curl -L -o /tmp/Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip
unzip -o /tmp/Xray-linux-64.zip -d /tmp/xray

install -m 755 /tmp/xray/xray /usr/local/bin/xray
install -m 644 /tmp/xray/geoip.dat "$XRAY_DIR/"
install -m 644 /tmp/xray/geosite.dat "$XRAY_DIR/"

# 写配置文件
mkdir -p "$(dirname $CONFIG_FILE)"
cat > $CONFIG_FILE <<EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "trojan",
    "settings": {
      "clients": [
        {
          "password": "$UUID"
        }
      ],
      "fallbacks": []
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "$CERT_DIR/fullchain.pem",
            "keyFile": "$CERT_DIR/private.key"
          }
        ]
      },
      "wsSettings": {
        "path": "/ray"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

# 写 systemd 服务文件
cat > $SERVICE_FILE <<EOF
[Unit]
Description=Xray Trojan Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray -config $CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd，启用并启动 Xray
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo "✅ Xray Trojan 节点安装完成！"
echo "节点信息："
echo "UUID (密码): $UUID"
echo "端口: $PORT"
echo "域名: $DOMAIN"
echo "传输协议: ws"
echo "路径: /ray"
echo ""
echo "Trojan URI:"
echo "trojan://$UUID@$DOMAIN:$PORT?security=tls&type=ws&path=%2Fray#trojan-node"
