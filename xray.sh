#!/bin/bash

set -e

# ====== 参数设置 ======
XRAY_VERSION="1.8.4"
PORT=80
UUID="1483c30c-ae2c-4130-f643-c6139d199c42"
WS_PATH="/ray"
XRAY_CONFIG_PATH="/usr/local/etc/xray"
XRAY_BINARY_PATH="/usr/local/bin/xray"
XRAY_SERVICE_PATH="/etc/systemd/system/xray.service"

echo "📦 安装 Xray Core v${XRAY_VERSION}..."

# ====== 下载并安装 Xray Core ======
mkdir -p /tmp/xray-install
cd /tmp/xray-install
wget -q https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip
unzip -o Xray-linux-64.zip -d xray
install -m 755 xray/xray ${XRAY_BINARY_PATH}
install -m 644 xray/geo* /usr/local/share/xray/
mkdir -p ${XRAY_CONFIG_PATH}

# ====== 写入配置文件 ======
cat > ${XRAY_CONFIG_PATH}/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0,
            "email": "vless@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${WS_PATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# ====== 创建 systemd 服务 ======
cat > ${XRAY_SERVICE_PATH} <<EOF
[Unit]
Description=Xray VLESS WS
After=network.target nss-lookup.target

[Service]
ExecStart=${XRAY_BINARY_PATH} -config ${XRAY_CONFIG_PATH}/config.json
Restart=on-failure
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# ====== 启动服务 ======
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ====== 放行端口（如有防火墙） ======
if command -v ufw >/dev/null; then
    ufw allow ${PORT}/tcp || true
fi

if command -v firewall-cmd >/dev/null; then
    firewall-cmd --add-port=${PORT}/tcp --permanent || true
    firewall-cmd --reload || true
fi

# ====== 输出配置信息 ======
echo "✅ Xray 安装完成，VLESS + WS 节点已启动！"
echo "-----------------------------------------"
echo "协议: VLESS"
echo "地址: $(curl -s ifconfig.me)"
echo "端口: ${PORT}"
echo "UUID : ${UUID}"
echo "加密: none"
echo "传输: ws"
echo "路径: ${WS_PATH}"
echo "-----------------------------------------"
