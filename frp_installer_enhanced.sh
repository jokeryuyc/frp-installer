#!/bin/bash

set -e

# 颜色输出
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# 全局变量
FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep tag_name | cut -d '"' -f 4)
ARCH="amd64"
INSTALL_DIR="/usr/local/frp"
SERVICE_NAME=""
BINARY_NAME=""
CONF_FILE=""
MODE=""

# 默认配置值（用户可以在安装过程中更改）
SERVER_PORT="6000"
DASHBOARD_PORT="6050"
DASHBOARD_USER="admin"
DASHBOARD_PWD="admin"
SERVER_ADDR=""
REMOTE_PORT="6022"
LOCAL_PORT="22"
TOKEN=""

# 日志函数
info() { echo -e "${GREEN}${BOLD}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET} $1"; }
error() { echo -e "${RED}${BOLD}[ERROR]${RESET} $1"; }
success() { echo -e "${CYAN}${BOLD}[SUCCESS]${RESET} $1"; }

# 显示横幅
show_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "┌───────────────────────────────────────┐"
    echo "│ ███████╗██████╗ ██████╗             │"
    echo "│ ██╔════╝██╔══██╗██╔══██╗            │"
    echo "│ █████╗  ██████╔╝██████╔╝            │"
    echo "│ ██╔══╝  ██╔══██╗██╔═══╝             │"
    echo "│ ██║     ██║  ██║██║                 │"
    echo "│ ╚═╝     ╚═╝  ╚═╝╚═╝                 │"
    echo "│ 增强版一键安装脚本 v1.0              │"
    echo "└───────────────────────────────────────┘${RESET}"
    echo -e "${MAGENTA}当前FRP最新版本: ${BOLD}$FRP_VERSION${RESET}\n"
}