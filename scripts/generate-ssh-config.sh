#!/usr/bin/env bash
# generate-ssh-config.sh - 生成本地 SSH config
# 用法: ./generate-ssh-config.sh [--user <跳板机用户>] [--key <跳板机SSH密钥路径>]
set -euo pipefail
source "$(dirname "$0")/common.sh"

JUMPHOST_INFO="${OUTPUT_DIR}/jumphost-info.json"
SSH_CONFIG="${OUTPUT_DIR}/ssh-config"

[[ ! -f "$JUMPHOST_INFO" ]] && die "跳板机信息不存在，请先运行 deploy-jumphost.sh"

JUMPHOST_IP=$(grep -o '"jump_host_ip": *"[^"]*"' "$JUMPHOST_INFO" | cut -d'"' -f4)
JUMPHOST_USER="${1:-root}"
SSH_KEY="${2:-}"

cat > "$SSH_CONFIG" <<HEADER
# ============================================
# Jump Host SSH Config
# 跳板机: ${JUMPHOST_IP}
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
#
# 使用方法:
#   cp ${SSH_CONFIG} ~/.ssh/config  (追加到现有)
#   或
#   ssh -F ${SSH_CONFIG} <server_name>
# ============================================

Host jumphost
    HostName ${JUMPHOST_IP}
    User ${JUMPHOST_USER}
HEADER

if [[ -n "$SSH_KEY" ]]; then
    echo "    IdentityFile ${SSH_KEY}" >> "$SSH_CONFIG"
fi

echo "" >> "$SSH_CONFIG"

# 为每台服务器生成 SSH config
SERVER_COUNT=0
while IFS=',' read -r name ssh_port remote_port desc; do
    [[ -z "$name" ]] && continue
    SERVER_COUNT=$((SERVER_COUNT + 1))

    # 替换下划线为连字符作为 host alias
    HOST_ALIAS=$(echo "$name" | tr '_' '-')

    cat >> "$SSH_CONFIG" <<HOSTENTRY
Host ${HOST_ALIAS}
    HostName 127.0.0.1
    Port ${remote_port}
    ProxyJump jumphost

HOSTENTRY
done < <(read_servers)

info "已生成 SSH config: $SSH_CONFIG"
info "包含 ${SERVER_COUNT} 台服务器"

echo ""
echo "使用方式:"
echo "  # 连接到任意目标服务器"
echo "  ssh -F ${SSH_CONFIG} <server_host>"
echo ""
echo "  # 或者合并到 ~/.ssh/config"
echo "  cat ${SSH_CONFIG} >> ~/.ssh/config"
echo "  ssh <server_host>"
echo ""

if [[ $SERVER_COUNT -gt 0 ]]; then
    echo "可用服务器:"
    while IFS=',' read -r name ssh_port remote_port desc; do
        [[ -z "$name" ]] && continue
        HOST_ALIAS=$(echo "$name" | tr '_' '-')
        echo "  ${HOST_ALIAS}  ->  jumphost:${remote_port} -> ${name}:${ssh_port}"
    done < <(read_servers)
fi
