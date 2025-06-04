#!/bin/bash
set -e

PORT=23000
USER="proxyuser"
PASS="proxypass"
CONF_PATH="/etc/opt/ss5/ss5.conf"
AUTH_PATH="/etc/opt/ss5/ss5.passwd"

echo "📦 安装 SS5（Socks5 + HTTP）..."
apt update
apt install -y gcc make libpam0g-dev libssl-dev iproute2 wget curl unzip sudo

# 下载并编译 SS5
cd /tmp
wget -q https://github.com/MerlinKodo/ss5/archive/refs/heads/master.zip -O ss5.zip
unzip -q ss5.zip
cd ss5-master
./configure
make && make install

# 配置认证
echo "auth 0.0.0.0/0 - u" >> $CONF_PATH
echo "permit u $USER" >> $CONF_PATH
echo "$USER $PASS" > $AUTH_PATH
chmod 600 $AUTH_PATH

# 启用认证配置
sed -i 's/^auth.*$/auth    0.0.0.0\/0    -    u/' $CONF_PATH
sed -i 's/^permit.*$/permit u    '"$USER"'/' $CONF_PATH

# 创建 systemd 服务
cat > /etc/systemd/system/ss5.service <<EOF
[Unit]
Description=SS5 Socks Server
After=network.target

[Service]
ExecStart=/usr/local/sbin/ss5 -u root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable ss5
systemctl restart ss5

# 获取公网 IP
IP=$(curl -s ifconfig.me)

# 输出 V2Ray 可识别格式
echo ""
echo "✅ SS5 安装成功"
echo "------------------------------------------------"
echo "🌐 外网地址: $IP"
echo "📌 端口:      $PORT"
echo "👤 用户名:    $USER"
echo "🔒 密码:      $PASS"
echo "📡 协议:      socks5 / http"
echo "------------------------------------------------"
echo "✅ V2Ray (SOCKS5) 节点格式（可复制）:"
echo "socks://$USER:$PASS@$IP:$PORT"
echo "✅ Clash (HTTP) 节点格式:"
echo "proxy:"
echo "  name: SS5-HTTP"
echo "  type: http"
echo "  server: $IP"
echo "  port: $PORT"
echo "  username: $USER"
echo "  password: $PASS"
echo "  tls: false"
echo "------------------------------------------------"
