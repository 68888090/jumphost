#!/usr/bin/env bash
# common.sh - 公共函数库
set -euo pipefail

FRP_VERSION="0.61.1"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${PROJECT_DIR}/config"
OUTPUT_DIR="${PROJECT_DIR}/output"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# 生成随机 token
gen_token() {
    openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p
}

# 读取 servers.csv，跳过注释和空行，返回有效行
read_servers() {
    grep -v '^#' "${CONFIG_DIR}/servers.csv" | grep -v '^$' || true
}
