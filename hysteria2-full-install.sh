#!/bin/bash

set -e

echo "开始安装 hysteria2..."

# 安装必要工具
apt update && apt install -y curl wget unzip openssl

# 固定版本号
VERSION="v2.6.2"

echo "下载 hysteria 版本 $VERSION"
wget -O hysteria.tar.gz "https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64.tar.gz"

# 解压
tar -xzvf hysteria.tar.gz

# 移动可执行文件到 /usr/local/bin 并赋予执行权限
mv hysteria /usr/local/bin/
chmod +x /usr/local/bin/hysteria

# 清理下载文件
rm hysteria.tar.gz

# 生成随机密码
PASS=$(openssl rand -hex 8)

# 生成自签 TLS 证书
mkdir -p /etc/hysteria
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -key /etc/hysteria/private.key -out /etc/hysteria/cert.pem -days 3650 -subj "/CN=bing.com"

# 生成配置文件
cat > /etc/hysteria/config.yaml <<EOF
listen: :5678
tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/private.key
auth:
  type: password
  password: $PASS
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF

# 创建 systemd 服务文件
cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria 2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd，启动并设置开机自启
systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria

# 获取公网 IP
IP=$(curl -s ipv4.ip.sb)

# 输出节点链接
echo
echo "✅ hysteria2 部署完成！"
echo "节点链接："
echo "hy2://$PASS@$IP:5678?insecure=1&sni=bing.com#Hysteria2-无域名节点"
echo
echo "如果你开启了防火墙，请记得放行 UDP 5678 端口："
echo "ufw allow 5678/udp"
