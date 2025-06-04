#!/bin/bash
set -e

PORT=12000
PASSWORD="aac3336362PP"
METHOD="aes-256-gcm"
CONFIG_PATH="/etc/shadowsocks-libev/config.json"

echo "📦 安装 Shadowsocks-libev..."

# 安装 Shadowsocks-libev
apt update
apt install -y shadowsocks-libev
apt install -y curl unzip socat
apt install -y sudo

# 写入配置文件
mkdir -p /etc/shadowsocks-libev
cat > $CONFIG_PATH <<EOF
{
  "server": "0.0.0.0",
  "server_port": $PORT,
  "password": "$PASSWORD",
  "timeout": 300,
  "method": "$METHOD",
  "fast_open": false,
  "nameserver": "8.8.8.8",
  "mode": "tcp_and_udp"
}
EOF

# 启动并设置开机启动
systemctl restart shadowsocks-libev
systemctl enable shadowsocks-libev

# 获取公网 IP
IP=\$(curl -s ifconfig.me)

echo "✅ Shadowsocks 安装成功！"
echo "----------------------------------------"
echo "地址: \$IP"
echo "端口: $PORT"
echo "密码: $PASSWORD"
echo "加密: $METHOD"
echo "----------------------------------------"
echo "连接 URI（Base64 编码）:"
echo -n "ss://\$(echo -n \"$METHOD:$PASSWORD@\$IP:$PORT\" | base64 -w0)"
echo
