#!/bin/bash
set -e

echo "🔧 安装 Dante SOCKS5 和 TinyProxy HTTP 代理..."

apt update
apt install -y dante-server tinyproxy

# 配置 Dante SOCKS5
cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 6000
external: $(ip route get 1 | awk '{print $5; exit}')
method: none

client pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: connect disconnect error
}

pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        protocol: tcp udp
        log: connect disconnect error
}
EOF

# 配置 TinyProxy HTTP
sed -i 's/^Port .*/Port 7000/' /etc/tinyproxy/tinyproxy.conf
sed -i 's/^Allow 127.0.0.1/#Allow 127.0.0.1/' /etc/tinyproxy/tinyproxy.conf
echo "Allow 0.0.0.0/0" >> /etc/tinyproxy/tinyproxy.conf

# 重启服务
echo "✅ 重启 Dante 和 TinyProxy..."
systemctl restart danted
systemctl enable danted

systemctl restart tinyproxy
systemctl enable tinyproxy

# 开放防火墙
echo "✅ 开放防火墙 6000(SOCKS5) 和 7000(HTTP)..."
ufw allow 6000/tcp || true
ufw allow 7000/tcp || true

echo "🎉 SOCKS5 端口:6000 和 HTTP 端口:7000 已全部安装完成，无需密码"
