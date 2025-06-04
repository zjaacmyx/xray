#!/bin/bash
set -e

PORT=12000
USERNAME="user1"
PASSWORD="pass123456"

echo "📦 安装依赖..."
apt update
apt install -y gcc make libpam0g-dev libssl-dev iproute2 wget curl unzip sudo

echo "📦 下载并安装 ss5..."
cd /tmp
wget -q https://github.com/zhaojh329/ss5/releases/download/3.9.2/ss5-3.9.2.tar.gz
tar zxvf ss5-3.9.2.tar.gz
cd ss5-3.9.2
make && make install

echo "📦 配置 ss5..."

cat > /etc/ss5.conf <<EOF
auth 0
permit -s 0.0.0.0/0 -i 0.0.0.0/0 -u $USERNAME
EOF

echo "$USERNAME $PASSWORD" >> /etc/opt/ss5.passwd

# 启动 ss5
ss5 -u $USERNAME -p $PASSWORD -b 0.0.0.0 -l $PORT &

IP=$(curl -s ifconfig.me)

echo "✅ SS5 安装完成"
echo "地址: $IP"
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo ""
echo "V2Ray 代理格式（socks5）:"
echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"
echo ""
echo "V2Ray 代理格式（http）:"
echo "http://$USERNAME:$PASSWORD@$IP:$PORT"
