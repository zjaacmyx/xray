#!/bin/bash

# SS5 安装 + 配置脚本（匿名、端口6666）

set -e

echo "🔧 安装依赖..."
if [ -f /etc/debian_version ]; then
    apt update
    apt install -y gcc make libpam0g-dev
elif [ -f /etc/redhat-release ]; then
    yum install -y gcc make pam-devel
else
    echo "❌ 不支持的系统"
    exit 1
fi

echo "📦 下载并编译 SS5..."
wget https://github.com/seriyps/mtproxy/releases/download/v1.1.1/ss5-3.8.9-8.tar.gz -O ss5.tar.gz
tar -xzf ss5.tar.gz
cd ss5-3.8.9-8
./configure
make
make install

echo "📝 配置 SS5（匿名，无需认证，监听 6666）..."
SS5_CONF="/etc/opt/ss5/ss5.conf"

cat > $SS5_CONF <<EOF
auth    0.0.0.0/0   -   -
permit  -   0.0.0.0/0   -   -   -   -   -   -
EOF

SS5_CONFIG="/etc/opt/ss5/ss5.conf"
SS5_OPTIONS="/etc/opt/ss5/ss5.conf"

# 设置端口6666
SS5_PORT_CONF="/etc/opt/ss5/ss5.conf"

# 修改启动参数
SS5_START="/etc/sysconfig/ss5"
if [ ! -f "$SS5_START" ]; then
    mkdir -p /etc/sysconfig/
    echo "OPTIONS=\"-u root -b 0.0.0.0 -s 6666\"" > $SS5_START
else
    sed -i 's/OPTIONS=.*/OPTIONS="-u root -b 0.0.0.0 -s 6666"/' $SS5_START
fi

echo "✅ SS5 配置完成，启用匿名，监听端口：6666"

# 开放防火墙
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=6666/tcp
    firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1; then
    ufw allow 6666/tcp
else
    echo "⚠️ 未检测到防火墙管理工具，手动确认端口是否放行"
fi

echo "🚀 启动 SS5..."
/etc/init.d/ss5 start

echo "🎉 SS5 SOCKS5 服务器已启动，端口6666，无需认证"
