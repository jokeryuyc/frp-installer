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

# 修改配置
modify_config() {
    local mode=$(get_installed_mode)
    local config_file
    local temp_file
    
    if [ "$mode" == "frps" ]; then
        config_file="$INSTALL_DIR/frps.ini"
        if [ ! -f "$config_file" ]; then
            error "找不到配置文件: $config_file"
            return 1
        fi
        
        # 显示当前配置
        display_config
        
        # 获取新的配置值
        echo -e "\n${BLUE}${BOLD}修改服务端配置:${RESET} (直接按回车保留当前值)"
        
        local current_port=$(grep "^bind_port" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "服务端端口 [$current_port]: " new_port
        new_port=${new_port:-$current_port}
        
        local current_dashboard_port=$(grep "^dashboard_port" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "管理面板端口 [$current_dashboard_port]: " new_dashboard_port
        new_dashboard_port=${new_dashboard_port:-$current_dashboard_port}
        
        local current_dashboard_user=$(grep "^dashboard_user" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "管理面板用户名 [$current_dashboard_user]: " new_dashboard_user
        new_dashboard_user=${new_dashboard_user:-$current_dashboard_user}
        
        local current_dashboard_pwd=$(grep "^dashboard_pwd" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "管理面板密码 [$current_dashboard_pwd]: " new_dashboard_pwd
        new_dashboard_pwd=${new_dashboard_pwd:-$current_dashboard_pwd}
        
        local current_token=$(grep "^token" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "认证令牌 [$current_token]: " new_token
        new_token=${new_token:-$current_token}
        
        # 更新配置文件
        temp_file=$(mktemp)
        cat "$config_file" > "$temp_file"
        
        sed -i "s/^bind_port = .*/bind_port = $new_port/" "$temp_file"
        sed -i "s/^dashboard_port = .*/dashboard_port = $new_dashboard_port/" "$temp_file"
        sed -i "s/^dashboard_user = .*/dashboard_user = $new_dashboard_user/" "$temp_file"
        sed -i "s/^dashboard_pwd = .*/dashboard_pwd = $new_dashboard_pwd/" "$temp_file"
        
        # 检查token是否存在，不存在则添加
        if grep -q "^token = " "$temp_file"; then
            sed -i "s/^token = .*/token = $new_token/" "$temp_file"
        elif [ -n "$new_token" ]; then
            # 在[common]部分后添加token
            sed -i "/^\[common\]/a token = $new_token" "$temp_file"
        fi
        
        sudo cp "$temp_file" "$config_file"
        rm -f "$temp_file"
        
        # 重启服务
        sudo systemctl restart frps
        success "服务端配置已更新并重启服务!"
        
    elif [ "$mode" == "frpc" ]; then
        config_file="$INSTALL_DIR/frpc.ini"
        if [ ! -f "$config_file" ]; then
            error "找不到配置文件: $config_file"
            return 1
        fi
        
        # 显示当前配置
        display_config
        
        # 获取新的配置值
        echo -e "\n${BLUE}${BOLD}修改客户端配置:${RESET} (直接按回车保留当前值)"
        
        local current_server_addr=$(grep "^server_addr" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "服务器地址 [$current_server_addr]: " new_server_addr
        new_server_addr=${new_server_addr:-$current_server_addr}
        
        local current_server_port=$(grep "^server_port" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "服务器端口 [$current_server_port]: " new_server_port
        new_server_port=${new_server_port:-$current_server_port}
        
        local current_token=$(grep "^token" "$config_file" | cut -d '=' -f2 | tr -d ' ')
        read -p "认证令牌 [$current_token]: " new_token
        new_token=${new_token:-$current_token}
        
        # 更新[ssh]部分
        if grep -q "^\[ssh\]" "$config_file"; then
            local current_local_port=$(grep -A 3 "^\[ssh\]" "$config_file" | grep "^local_port" | cut -d '=' -f2 | tr -d ' ')
            read -p "本地SSH端口 [$current_local_port]: " new_local_port
            new_local_port=${new_local_port:-$current_local_port}
            
            local current_remote_port=$(grep -A 3 "^\[ssh\]" "$config_file" | grep "^remote_port" | cut -d '=' -f2 | tr -d ' ')
            read -p "远程映射端口 [$current_remote_port]: " new_remote_port
            new_remote_port=${new_remote_port:-$current_remote_port}
        fi
        
        # 是否添加新的转发规则
        echo -e "\n${BLUE}${BOLD}是否添加新的端口转发规则?${RESET}"
        read -p "添加新规则? [y/N]: " add_new_rule
        
        # 更新配置文件
        temp_file=$(mktemp)
        cat "$config_file" > "$temp_file"
        
        sed -i "s/^server_addr = .*/server_addr = $new_server_addr/" "$temp_file"
        sed -i "s/^server_port = .*/server_port = $new_server_port/" "$temp_file"
        
        # 检查token是否存在，不存在则添加
        if grep -q "^token = " "$temp_file"; then
            sed -i "s/^token = .*/token = $new_token/" "$temp_file"
        elif [ -n "$new_token" ]; then
            # 在[common]部分后添加token
            sed -i "/^\[common\]/a token = $new_token" "$temp_file"
        fi
        
        # 更新SSH部分
        if grep -q "^\[ssh\]" "$temp_file" && [ -n "$new_local_port" ] && [ -n "$new_remote_port" ]; then
            sed -i "/^\[ssh\]/,/remote_port/s/^local_port = .*/local_port = $new_local_port/" "$temp_file"
            sed -i "/^\[ssh\]/,/remote_port/s/^remote_port = .*/remote_port = $new_remote_port/" "$temp_file"
        fi
        
        # 添加新的转发规则
        if [[ "$add_new_rule" == [yY] ]]; then
            echo -e "\n${CYAN}添加新的转发规则:${RESET}"
            read -p "规则名称 (例如: web, rdp): " rule_name
            read -p "协议类型 [tcp/http/https/udp]: " rule_type
            read -p "本地IP [默认127.0.0.1]: " rule_local_ip
            rule_local_ip=${rule_local_ip:-127.0.0.1}
            read -p "本地端口: " rule_local_port
            read -p "远程端口 (仅tcp/udp需要): " rule_remote_port
            
            # 添加新规则到配置
            echo -e "\n[$rule_name]" >> "$temp_file"
            echo "type = $rule_type" >> "$temp_file"
            echo "local_ip = $rule_local_ip" >> "$temp_file"
            echo "local_port = $rule_local_port" >> "$temp_file"
            
            if [[ "$rule_type" == "tcp" || "$rule_type" == "udp" ]]; then
                echo "remote_port = $rule_remote_port" >> "$temp_file"
            elif [[ "$rule_type" == "http" || "$rule_type" == "https" ]]; then
                read -p "域名: " rule_domain
                echo "custom_domains = $rule_domain" >> "$temp_file"
            fi
        fi
        
        sudo cp "$temp_file" "$config_file"
        rm -f "$temp_file"
        
        # 重启服务
        sudo systemctl restart frpc
        success "客户端配置已更新并重启服务!"
        
    else
        error "未检测到已安装的FRP"
        return 1
    fi
    
    return 0
}