#!/bin/bash
set -e

# 基础信息
SS_PORT=22000
SS_PASSWORD="yiyann***999"
SS_METHOD="aes-256-gcm"

VLESS_UUID="1483c30c-ae2c-4130-f643-c6139d199c42"
VLESS_PORT=20000

VMESS_UUID="1483c30c-ae2c-4130-f643-c6139d199c42"
VMESS_PORT=21000

XRAY_DIR="/usr/local/share/xray"
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
SS_CONFIG="/etc/shadowsocks-libev/config.json"
XRAY_SERVICE="/etc/systemd/system/xray.service"

# 安装基础工具
echo "📦 安装依赖..."
apt update
apt install -y curl unzip socat sudo shadowsocks-libev

# 获取公网 IP
IP=$(curl -s ifconfig.me)

#######################
# 安装 Shadowsocks
#######################
echo ""
echo "🚀 安装 Shadowsocks-libev..."

mkdir -p /etc/shadowsocks-libev
cat > "$SS_CONFIG" <<EOF
{
  "server": "0.0.0.0",
  "server_port": $SS_PORT,
  "password": "$SS_PASSWORD",
  "timeout": 300,
  "method": "$SS_METHOD",
  "fast_open": false,
  "nameserver": "8.8.8.8",
  "mode": "tcp_and_udp"
}
EOF

systemctl restart shadowsocks-libev
systemctl enable shadowsocks-libev

SS_PLAIN="$SS_METHOD:$SS_PASSWORD@$IP:$SS_PORT"
SS_ENCODED=$(echo -n "$SS_PLAIN" | base64 | tr -d '\n')
SS_LINK="ss://$SS_ENCODED"

echo "✅ Shadowsocks 安装完成！"
echo "----------------------------------------"
echo "地址    : $IP"
echo "端口    : $SS_PORT"
echo "密码    : $SS_PASSWORD"
echo "加密方式: $SS_METHOD"
echo "📎 链接 : $SS_LINK"
echo "----------------------------------------"

#######################
# 安装 Xray Core
#######################
echo ""
echo "🚀 安装 Xray Core v1.8.4..."

mkdir -p "$XRAY_DIR" "$CONFIG_DIR"
curl -L -o /tmp/Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip
unzip -o /tmp/Xray-linux-64.zip -d /tmp/xray

install -m 755 /tmp/xray/xray "$XRAY_BIN"
install -m 644 /tmp/xray/geoip.dat "$XRAY_DIR/"
install -m 644 /tmp/xray/geosite.dat "$XRAY_DIR/"

#######################
# 写入 Xray 配置：VLESS + VMess 合并配置
#######################
cat > "$CONFIG_DIR/config.json" <<EOF
{
  "inbounds": [
    {
      "port": $VLESS_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$VLESS_UUID"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ray"
        }
      }
    },
    {
      "port": $VMESS_PORT,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$VMESS_UUID", "alterId": 0}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ray"
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

# 写入 systemd 服务
cat > "$XRAY_SERVICE" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$XRAY_BIN -config $CONFIG_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动 Xray 服务
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

#######################
# 打印 VLESS 信息
#######################
echo ""
echo "✅ Xray VLESS 配置完成！"
echo "----------------------------------------"
echo "地址   : $IP"
echo "端口   : $VLESS_PORT"
echo "UUID   : $VLESS_UUID"
echo "传输   : ws"
echo "路径   : /ray"
echo "协议   : vless"
echo "----------------------------------------"

#######################
# 打印 VMess 信息
#######################
echo ""
echo "✅ Xray VMess 配置完成！"
echo "----------------------------------------"
echo "地址    : $IP"
echo "端口    : $VMESS_PORT"
echo "UUID    : $VMESS_UUID"
echo "传输    : ws"
echo "路径    : /ray"
echo "加密    : auto"
echo "alterId : 0"
echo "----------------------------------------"

VMESS_JSON=$(cat <<JSON
{
  "v": "2",
  "ps": "vmess-node",
  "add": "$IP",
  "port": "$VMESS_PORT",
  "id": "$VMESS_UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "/ray",
  "tls": "none"
}
JSON
)

VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w0)"
echo "📎 VMess 链接："
echo "$VMESS_LINK"
echo "----------------------------------------"

echo "🎉 所有服务安装完毕！"

