#!/usr/bin/env bash
# add-server.sh - 新增目标服务器
# 用法:
#   ./add-server.sh <server_name> [--port 22] [--remote 0]
#
# 选项:
#   --port   目标服务器本地 SSH 端口 (默认 22)
#   --remote 指定 frp 远程端口 (默认自动分配)
set -euo pipefail
source "$(dirname "$0")/common.sh"

# 解析参数
SERVER_NAME=""
LOCAL_SSH_PORT=22
REMOTE_PORT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) LOCAL_SSH_PORT="$2"; shift 2 ;;
        --remote) REMOTE_PORT="$2"; shift 2 ;;
        --help|-h)
            echo "用法: $0 <server_name> [--port 22] [--remote 22001]"
            exit 0
            ;;
        *) SERVER_NAME="$1"; shift ;;
    esac
done

[[ -z "$SERVER_NAME" ]] && die "请指定服务器名: $0 <server_name>"

# 读取跳板机信息
JUMPHOST_INFO="${OUTPUT_DIR}/jumphost-info.json"
[[ ! -f "$JUMPHOST_INFO" ]] && die "跳板机信息不存在，请先运行 deploy-jumphost.sh"

JUMPHOST_IP=$(grep -o '"jump_host_ip": *"[^"]*"' "$JUMPHOST_INFO" | cut -d'"' -f4)
TOKEN=$(grep -o '"token": *"[^"]*"' "$JUMPHOST_INFO" | cut -d'"' -f4)

# 自动分配远程端口
if [[ "$REMOTE_PORT" -eq 0 ]]; then
    # 从 servers.csv 找到最大端口号 + 1
    MAX_PORT=$(read_servers | cut -d',' -f3 | sort -n | tail -1)
    if [[ -z "$MAX_PORT" ]]; then
        REMOTE_PORT=22001
    else
        REMOTE_PORT=$((MAX_PORT + 1))
    fi
fi

[[ $REMOTE_PORT -gt 22050 ]] && die "端口超出范围 (最大 22050)，请手动指定"

# 检查端口冲突
if read_servers | cut -d',' -f3 | grep -q "^${REMOTE_PORT}$"; then
    die "端口 ${REMOTE_PORT} 已被占用"
fi

# 生成 frpc 配置
FRPC_DIR="${OUTPUT_DIR}/servers/${SERVER_NAME}"
mkdir -p "$FRPC_DIR"

sed \
    -e "s|{{JUMPHOST_IP}}|${JUMPHOST_IP}|g" \
    -e "s|{{TOKEN}}|${TOKEN}|g" \
    -e "s|{{SERVER_NAME}}|${SERVER_NAME}|g" \
    -e "s|{{SSH_PORT}}|${LOCAL_SSH_PORT}|g" \
    -e "s|{{REMOTE_PORT}}|${REMOTE_PORT}|g" \
    "${CONFIG_DIR}/frpc.toml" > "${FRPC_DIR}/frpc.toml"

# 记录到 servers.csv
echo "${SERVER_NAME},${LOCAL_SSH_PORT},${REMOTE_PORT},$(date +%F)" >> "${CONFIG_DIR}/servers.csv"

# 生成目标服务器部署脚本
cat > "${FRPC_DIR}/install-frpc.sh" <<'INSTALL_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
FRP_VERSION="0.61.1"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"

echo "=== 在目标服务器上安装 frpc ==="

if [[ ! -f /tmp/frp.tar.gz ]]; then
    curl -L --progress-bar -o /tmp/frp.tar.gz "$FRP_URL" || { echo "下载失败"; exit 1; }
fi

sudo mkdir -p /etc/frp
tar -xzf /tmp/frp.tar.gz -C /tmp/
sudo cp "/tmp/frp_${FRP_VERSION}_linux_amd64/frpc" /usr/local/bin/frpc
sudo chmod +x /usr/local/bin/frpc

# 复制配置 (scp 到目标服务器后运行此脚本)
sudo cp frpc.toml /etc/frp/frpc.toml

sudo tee /etc/systemd/system/frpc.service > /dev/null <<SYSTEMD
[Unit]
Description=frp Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD

sudo systemctl daemon-reload
sudo systemctl enable frpc
sudo systemctl restart frpc

echo "frpc 安装并启动完成"
echo "检查状态: sudo systemctl status frpc"
INSTALL_SCRIPT

chmod +x "${FRPC_DIR}/install-frpc.sh"

# 输出信息
info "=== 服务器 '${SERVER_NAME}' 配置已生成 ==="
echo ""
echo "服务器配置:"
echo "  名称:       ${SERVER_NAME}"
echo "  本地 SSH:   ${LOCAL_SSH_PORT}"
echo "  远程端口:   ${REMOTE_PORT}"
echo ""
echo "部署到目标服务器:"
echo "  1. scp ${FRPC_DIR}/frpc.toml ${FRPC_DIR}/install-frpc.sh user@${SERVER_NAME}:/tmp/"
echo "  2. ssh user@${SERVER_NAME} 'cd /tmp && sudo ./install-frpc.sh'"
echo ""
echo "连接方式:"
echo "  ssh -o ProxyJump=root@${JUMPHOST_IP} -p ${REMOTE_PORT} user@localhost"
echo ""
echo "下一步: 运行 ./generate-ssh-config.sh 更新本地 SSH config"
