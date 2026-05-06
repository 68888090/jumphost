#!/usr/bin/env bash
# deploy-jumphost.sh - 在跳板机上部署 frps 服务
# 用法: 在跳板机上执行此脚本
#   ./deploy-jumphost.sh [--ip <跳板机公网IP>]
set -euo pipefail
source "$(dirname "$0")/common.sh"

JUMPHOST_IP="${1:-}"

if [[ -z "$JUMPHOST_IP" ]]; then
    JUMPHOST_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || true)
    if [[ -z "$JUMPHOST_IP" ]]; then
        die "无法获取公网 IP，请手动指定: $0 <跳板机公网IP>"
    fi
    info "自动检测到公网 IP: $JUMPHOST_IP"
fi

TOKEN=$(gen_token)
DASHBOARD_PASS=$(openssl rand -hex 8 2>/dev/null || head -c 8 /dev/urandom | xxd -p)

info "=== 部署 frps 到跳板机 ($JUMPHOST_IP) ==="

# 1. 下载 frp
if [[ ! -f /tmp/frp.tar.gz ]]; then
    info "下载 frp v${FRP_VERSION}..."
    curl -L --progress-bar -o /tmp/frp.tar.gz "$FRP_URL" || die "下载失败"
fi

# 2. 解压 & 安装
info "安装 frps..."
sudo mkdir -p /etc/frp
tar -xzf /tmp/frp.tar.gz -C /tmp/
sudo cp "/tmp/frp_${FRP_VERSION}_linux_amd64/frps" /usr/local/bin/frps
sudo chmod +x /usr/local/bin/frps

# 3. 生成配置
info "生成 frps 配置..."
sudo tee /etc/frp/frps.toml > /dev/null <<FRPSCONF
bindPort = 7000
auth.token = "${TOKEN}"

allowPorts = [
  { start = 22001, end = 22050 }
]

webServer.addr = "127.0.0.1"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "${DASHBOARD_PASS}"
FRPSCONF

# 4. 创建 systemd 服务
info "创建 systemd 服务..."
sudo tee /etc/systemd/system/frps.service > /dev/null <<SYSTEMD
[Unit]
Description=frp Server (Jump Host)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD

sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl restart frps

# 5. 保存配置到本地 output 目录
mkdir -p "$OUTPUT_DIR"
cat > "${OUTPUT_DIR}/jumphost-info.json" <<EOF
{
  "jump_host_ip": "${JUMPHOST_IP}",
  "token": "${TOKEN}",
  "dashboard_user": "admin",
  "dashboard_password": "${DASHBOARD_PASS}",
  "bind_port": 7000,
  "dashboard_port": 7500,
  "remote_port_range": "22001-22050"
}
EOF

info "=== 部署完成 ==="
echo ""
echo "跳板机信息已保存到: ${OUTPUT_DIR}/jumphost-info.json"
echo ""
echo "关键信息:"
echo "  公网 IP:    ${JUMPHOST_IP}"
echo "  frps 端口:  7000"
echo "  Token:      ${TOKEN}"
echo "  Dashboard:  http://${JUMPHOST_IP}:7500 (仅本机)"
echo ""
echo "下一步: 在新设备上运行 ./add-server.sh <服务器名> <SSH端口>"
