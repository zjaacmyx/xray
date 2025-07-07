#!/bin/bash
set -e

USERNAME="aac"
PASSWORD="Aa1234512345AC"

echo "🔧 安装 Dante (SOCKS5) 和 Squid (HTTP 代理)..."

apt update
apt install -y dante-server squid apache2-utils

# 创建本地用户供 Dante 使用
echo "✅ 添加本地用户 $USERNAME..."
useradd -M -s /usr/sbin/nologin $USERNAME || true
echo "$USERNAME:$PASSWORD" | chpasswd

# 配置 Dante
echo "✅ 配置 Dante SOCKS5..."
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

# 配置 Squid HTTP 代理
echo "✅ 配置 Squid HTTP 代理..."

# 创建认证密码文件
htpasswd -b -c /etc/squid/passwd $USERNAME $PASSWORD

# 自动查找 basic_ncsa_auth 路径
BASIC_AUTH_BIN=$(find /usr -name basic_ncsa_auth | head -n1)

if [[ -z "$BASIC_AUTH_BIN" ]]; then
    echo "❌ 未找到 basic_ncsa_auth，Squid 安装不完整"
    exit 1
fi

echo "✅ 找到认证模块路径: $BASIC_AUTH_BIN"

# 备份原始配置
mv /etc/squid/squid.conf /etc/squid/squid.conf.bak || true

# 生成新配置
cat > /etc/squid/squid.conf <<EOF
http_port 7000
auth_param basic program $BASIC_AUTH_BIN /etc/squid/passwd
auth_param basic realm ProxyAuth
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
access_log /var/log/squid/access.log
cache deny all
EOF

# 启动服务
echo "✅ 启动服务并设置开机自启..."
systemctl restart danted
systemctl enable danted

systemctl restart squid || {
    echo "❌ Squid 启动失败，请查看日志："
    journalctl -xeu squid.service | tail -n 30
    exit 1
}
systemctl enable squid

# 防火墙配置
if command -v ufw >/dev/null && ufw status | grep -q active; then
    echo "✅ 开放防火墙端口 6000 和 7000..."
    ufw allow 6000/tcp
    ufw allow 7000/tcp
else
    echo "⚠️ 未检测到已启用的 UFW 防火墙，请手动放行端口 6000 和 7000"
fi

# 完成提示
echo "🎉 安装完成！"
echo "SOCKS5 地址: <你的IP>:6000"
echo "HTTP 地址:  <你的IP>:7000"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
