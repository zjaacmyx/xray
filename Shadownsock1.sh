#!/bin/bash
set -e

PORT=22001
PASSWORD="yiyann***999"
METHOD="aes-256-gcm"
CONFIG_PATH="/etc/shadowsocks-libev/config.json"
GOST_URL="https://github.com/ginuerzh/gost/releases/download/v2.12.0/gost_2.12.0_linux_amd64.tar.gz"
LOCAL_DOH_DNS="127.0.0.1:5353"
REMOTE_DOH="https://dns0.eu/dns-query"

echo "📦 安装 Shadowsocks-libev 和 gost..."

# 安装必要组件
apt update
apt install -y shadowsocks-libev curl unzip socat sudo wget screen tar

# 下载并解压 gost（仅第一次）
if [ ! -f /usr/local/bin/gost ]; then
  cd /tmp
  wget -qO- "$GOST_URL" | tar -zxv
  chmod +x gost
  mv gost /usr/local/bin/gost
fi

# 启动 gost 本地 DoH DNS 转换服务（UDP → DoH）
echo "🚀 启动本地 DNS 转换（dns0.eu）..."
screen -dmS gost_dns0eu gost -L=udp://127.0.0.1:5353 -F=dns+$REMOTE_DOH

# 写入 Shadowsocks 配置
echo "📝 写入 Shadowsocks 配置..."
mkdir -p /etc/shadowsocks-libev
cat > "$CONFIG_PATH" <<EOF
{
  "server": "0.0.0.0",
  "server_port": $PORT,
  "password": "$PASSWORD",
  "timeout": 300,
  "method": "$METHOD",
  "fast_open": false,
  "nameserver": "$LOCAL_DOH_DNS",
  "mode": "tcp_and_udp"
}
EOF

# 启动并设置开机启动
echo "🔧 启动 Shadowsocks-libev..."
systemctl restart shadowsocks-libev
systemctl enable shadowsocks-libev

# 获取公网 IP
IP=$(curl -s ifconfig.me)

# 构造 ss:// 链接
PLAIN="$METHOD:$PASSWORD@$IP:$PORT"
ENCODED=$(echo -n "$PLAIN" | base64 | tr -d '\n')
LINK="ss://$ENCODED"

# 输出信息
echo ""
echo "✅ Shadowsocks 安装完成！"
echo "----------------------------------------"
echo "地址    : $IP"
echo "端口    : $PORT"
echo "密码    : $PASSWORD"
echo "加密方式: $METHOD"
echo "DNS     : $REMOTE_DOH → $LOCAL_DOH_DNS"
echo "----------------------------------------"
echo "📎 客户端链接："
echo "$LINK"
echo "----------------------------------------"
