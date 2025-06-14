#!/bin/bash
set -e

echo "🔧 安装 Dante SOCKS5 服务器..."
apt update
apt install -y dante-server

cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 6666
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

echo "✅ 配置完成，重启 Dante..."
systemctl restart danted
systemctl enable danted

echo "✅ 开放防火墙 6666 端口..."
ufw allow 6666/tcp || true

echo "🎉 SOCKS5 服务器安装完成，端口: 6666，无需用户名密码"
