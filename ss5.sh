#!/bin/bash
set -e

PORT=23000
USER="proxyuser"
PASS="proxypass"
CONF_DIR="/etc/opt/ss5"
CONF_PATH="$CONF_DIR/ss5.conf"
AUTH_PATH="$CONF_DIR/ss5.passwd"

echo "📦 安装编译依赖和工具..."
apt update
apt install -y gcc make libpam0g-dev libssl-dev iproute2 wget curl unzip sudo

echo "📦 下载并编译 ss5..."
mkdir -p /tmp/ss5-install
cd /tmp/ss5-install
wget -q https://github.com/MerlinKodo/ss5/archive/refs/heads/master.zip -O ss5.zip
unzip -q ss5.zip
cd ss5-master
./configure
make && make install

echo "📝 配置认证..."
mkdir -p "$CONF_DIR"
echo "auth 0.0.0.0/0 - u" > "$CONF_PATH"
echo "permit u $USER" >> "$CONF_PATH"
echo "$USER $PASS" > "$AUTH_PATH"
chmod 600 "$AUTH_PATH"

echo "🔧 设置 systemd 服务..."
cat >/etc/systemd/system/ss5.service <<EOF
[Unit]
Description=SS5 Socks Server
After=network.target

[Service]
ExecStart=/usr/local/sbin/ss5 -u root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 启动服务..."
systemctl daemon-reload
systemctl enable ss5
systemctl restart ss5

IP=$(curl -s ifconfig.me)

echo ""
echo "✅ 安装完成！"
echo "------------------------------------------------"
echo "地址: $IP"
echo "端口: $PORT"
echo "用户名: $USER"
echo "密码: $PASS"
echo "协议: socks5 / http"
echo "------------------------------------------------"
echo "V2Ray 可复制 SOCKS5 节点:"
echo "socks://$USER:$PASS@$IP:$PORT"
echo ""
echo "Clash HTTP 代理配置示例:"
echo "proxy:"
echo "  name: SS5-HTTP"
echo "  type: http"
echo "  server: $IP"
echo "  port: $PORT"
echo "  username: $USER"
echo "  password: $PASS"
echo "  tls: false"
echo "------------------------------------------------"
