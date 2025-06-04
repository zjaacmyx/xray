#!/bin/bash
set -e

PORT=22000
PASSWORD="yiyann***999"
METHOD="aes-256-gcm"
CONFIG_PATH="/etc/shadowsocks-libev/config.json"

echo "📦 正在安装 Shadowsocks-libev..."

# 安装依赖
apt update
apt install -y shadowsocks-libev curl sudo

# 写入配置文件
mkdir -p /etc/shadowsocks-libev
cat > "$CONFIG_PATH" <<EOF
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
IP=$(curl -s ifconfig.me)

# 构造 ss:// 链接（Base64 编码）
PLAIN="$METHOD:$PASSWORD@$IP:$PORT"
ENCODED=$(echo -n "$PLAIN" | base64 -w 0)
LINK="ss://$ENCODED"

# 打印结果
echo ""
echo "✅ Shadowsocks 安装完成！已启动"
echo "----------------------------------------"
echo "地址    : $IP"
echo "端口    : $PORT"
echo "密码    : $PASSWORD"
echo "加密方式: $METHOD"
echo "----------------------------------------"
echo "📎 可用于 V2RayN、Shadowrocket 等客户端的链接："
echo "$LINK"
echo "----------------------------------------"
