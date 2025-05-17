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

# 检查是否已安装
check_installed() {
    if [ -d "$INSTALL_DIR" ] || systemctl is-active --quiet frps 2>/dev/null || systemctl is-active --quiet frpc 2>/dev/null; then
        return 0 # 已安装
    else
        return 1 # 未安装
    fi
}

# 获取当前安装的模式
get_installed_mode() {
    if systemctl is-active --quiet frps 2>/dev/null; then
        echo "frps"
    elif systemctl is-active --quiet frpc 2>/dev/null; then
        echo "frpc"
    else
        echo "unknown"
    fi
}

# 卸载FRP
uninstall_frp() {
    local mode=$(get_installed_mode)
    
    echo -e "\n${YELLOW}${BOLD}⚠️  您正在卸载FRP...${RESET}"
    read -p "确定要卸载FRP吗? [y/N]: " confirm
    if [[ "$confirm" != [yY] ]]; then
        info "已取消卸载"
        return
    fi
    
    if [ "$mode" == "frps" ]; then
        sudo systemctl stop frps 2>/dev/null || true
        sudo systemctl disable frps 2>/dev/null || true
        sudo rm -f /etc/systemd/system/frps.service
    elif [ "$mode" == "frpc" ]; then
        sudo systemctl stop frpc 2>/dev/null || true
        sudo systemctl disable frpc 2>/dev/null || true
        sudo rm -f /etc/systemd/system/frpc.service
    else
        warn "未检测到正在运行的FRP服务"
    fi
    
    sudo rm -rf "$INSTALL_DIR"
    sudo systemctl daemon-reload
    
    success "FRP已成功卸载!"
    exit 0
}

# 显示当前配置
display_config() {
    local mode=$(get_installed_mode)
    local config_file
    
    if [ "$mode" == "frps" ]; then
        config_file="$INSTALL_DIR/frps.ini"
        if [ -f "$config_file" ]; then
            echo -e "\n${CYAN}${BOLD}当前服务端(frps)配置:${RESET}"
            echo -e "${YELLOW}------------------------------${RESET}"
            cat "$config_file"
            echo -e "${YELLOW}------------------------------${RESET}"
        else
            error "找不到配置文件: $config_file"
        fi
    elif [ "$mode" == "frpc" ]; then
        config_file="$INSTALL_DIR/frpc.ini"
        if [ -f "$config_file" ]; then
            echo -e "\n${CYAN}${BOLD}当前客户端(frpc)配置:${RESET}"
            echo -e "${YELLOW}------------------------------${RESET}"
            cat "$config_file"
            echo -e "${YELLOW}------------------------------${RESET}"
        else
            error "找不到配置文件: $config_file"
        fi
    else
        error "未检测到已安装的FRP"
        return 1
    fi
    
    return 0
}