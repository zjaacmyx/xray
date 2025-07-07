#!/bin/bash
set -e

USERNAME="aac"
PASSWORD="Aa1234512345AC"

echo "🔧 安装 Dante (SOCKS5) 和 Squid (HTTP 代理)..."

apt update
apt install -y dante-server squid apache2-utils

# 创建系统用户用于 Dante 认证
echo "✅ 添加本地用户 $USERNAME..."
useradd -M -s /usr/sbin/nologin $USERNAME || true
echo "$USERNAME:$PASSWORD" | chpasswd

# ➤ 配置 Dante (SOCKS5) @6000
cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 6000
external: $(hostname -I | awk '{print $1}')
method: username

user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    method: username
    log: connect disconnect error
}
EOF

# ➤ 配置 Squid HTTP 代理 @7000
echo "✅ 配置 Squid HTTP 代理..."

# 创建密码文件（Basic Auth）
htpasswd -b -c /etc/squid/passwd $USERNAME $PASSWORD

# 备份旧配置
mv /etc/squid/squid.conf /etc/squid/squid.conf.bak

# 新配置
cat > /etc/squid/squid.conf <<EOF
http_port 7000
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm ProxyAuth
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
access_log /var/log/squid/access.log
cache deny all
EOF

# 重启服务
echo "✅ 启动并设置开机自启..."
systemctl restart danted
systemctl enable danted

systemctl restart squid
systemctl enable squid

# 防火墙配置
if command -v ufw >/dev/null && ufw status | grep -q active; then
    echo "✅ 开放防火墙端口 6000(SOCKS5) 和 7000(HTTP)..."
    ufw allow 6000/tcp
    ufw allow 7000/tcp
else
    echo "⚠️ 未检测到启用的 UFW 防火墙，请手动开放端口：6000 和 7000"
fi

# 完成提示
echo "🎉 代理部署完成！"
echo "SOCKS5 地址: <你的IP>:6000"
echo "HTTP 地址:  <你的IP>:7000"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
