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
    echo "┌──────────────────────────────────┐"
    echo "│ ████████╗██████╗ ██████╗             │"
    echo "│ ╚══██╔══╝██╔══██╗██╔══██╗            │"
    echo "│    ██║   ███████║██████╔╝            │"
    echo "│    ██║   ██╔══██║██╔═══╝             │"
    echo "│    ██║   ██║  ██║██║                 │"
    echo "│    ╚═╝   ╚═╝  ╚═╝╚═╝                 │"
    echo "│ 增强版一键安装脚本 v1.0              │"
    echo "└──────────────────────────────────┘${RESET}"
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

# 显示状态
show_status() {
    local mode=$(get_installed_mode)
    
    if [ "$mode" == "frps" ]; then
        echo -e "\n${CYAN}${BOLD}FRP服务端状态:${RESET}"
        systemctl status frps
        echo -e "\n${YELLOW}服务端管理面板:${RESET} http://$(curl -s ifconfig.me || hostname -I | awk '{print $1}'):$(grep dashboard_port $INSTALL_DIR/frps.ini | cut -d '=' -f2 | tr -d ' ')"
        echo -e "${YELLOW}用户名:${RESET} $(grep dashboard_user $INSTALL_DIR/frps.ini | cut -d '=' -f2 | tr -d ' ')"
        echo -e "${YELLOW}密码:${RESET} $(grep dashboard_pwd $INSTALL_DIR/frps.ini | cut -d '=' -f2 | tr -d ' ')"
    elif [ "$mode" == "frpc" ]; then
        echo -e "\n${CYAN}${BOLD}FRP客户端状态:${RESET}"
        systemctl status frpc
        echo -e "\n${YELLOW}连接到服务器:${RESET} $(grep server_addr $INSTALL_DIR/frpc.ini | cut -d '=' -f2 | tr -d ' '):$(grep server_port $INSTALL_DIR/frpc.ini | cut -d '=' -f2 | tr -d ' ')"
        echo -e "${YELLOW}当前活跃隧道:${RESET}"
        grep -E "^\[.*\]" $INSTALL_DIR/frpc.ini | grep -v "\[common\]" | tr -d '[]' | while read tunnel; do
            echo -e "  - $tunnel"
        done
    else
        error "未检测到已安装的FRP"
        return 1
    fi
    
    return 0
}

# 安装FRP服务端
install_frps() {
    MODE="frps"
    SERVICE_NAME="frps"
    BINARY_NAME="frps"
    CONF_FILE="frps.ini"

    info "✨ 开始安装FRP服务端..."
    
    # 获取用户配置
    echo -e "\n${BLUE}${BOLD}配置FRP服务端参数:${RESET} (直接按回车使用默认值)"
    read -p "服务端端口 [默认: $SERVER_PORT]: " input_server_port
    SERVER_PORT=${input_server_port:-$SERVER_PORT}
    
    read -p "管理面板端口 [默认: $DASHBOARD_PORT]: " input_dashboard_port
    DASHBOARD_PORT=${input_dashboard_port:-$DASHBOARD_PORT}
    
    read -p "管理面板用户名 [默认: $DASHBOARD_USER]: " input_dashboard_user
    DASHBOARD_USER=${input_dashboard_user:-$DASHBOARD_USER}
    
    read -p "管理面板密码 [默认: $DASHBOARD_PWD]: " input_dashboard_pwd
    DASHBOARD_PWD=${input_dashboard_pwd:-$DASHBOARD_PWD}
    
    read -p "认证令牌 (留空则不设置): " TOKEN
    
    # 下载和安装FRP
    install_frp
    
    # 创建配置文件
    sudo tee $INSTALL_DIR/frps.ini > /dev/null <<EOF
[common]
bind_port = $SERVER_PORT
dashboard_port = $DASHBOARD_PORT
dashboard_user = $DASHBOARD_USER
dashboard_pwd = $DASHBOARD_PWD
EOF

    # 如果提供了TOKEN，则添加到配置中
    if [ -n "$TOKEN" ]; then
        echo "token = $TOKEN" >> $INSTALL_DIR/frps.ini
    fi
    
    # 设置服务并启动
    setup_service
    
    # 显示完成信息
    local PUBLIC_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    success "🎉 FRP服务端安装完成！"
    echo -e "\n${CYAN}${BOLD}服务端信息:${RESET}"
    echo -e "${YELLOW}--------------------------------------${RESET}"
    echo -e "${YELLOW}服务端地址:${RESET} $PUBLIC_IP"
    echo -e "${YELLOW}服务端端口:${RESET} $SERVER_PORT"
    echo -e "${YELLOW}管理面板:${RESET} http://$PUBLIC_IP:$DASHBOARD_PORT"
    echo -e "${YELLOW}管理面板用户名:${RESET} $DASHBOARD_USER"
    echo -e "${YELLOW}管理面板密码:${RESET} $DASHBOARD_PWD"
    if [ -n "$TOKEN" ]; then
        echo -e "${YELLOW}认证令牌:${RESET} $TOKEN"
    fi
    echo -e "${YELLOW}--------------------------------------${RESET}"
    echo -e "${GREEN}配置文件位置:${RESET} $INSTALL_DIR/frps.ini"
    echo -e "${GREEN}重启服务命令:${RESET} sudo systemctl restart frps"
    echo -e "${GREEN}查看状态命令:${RESET} sudo systemctl status frps"
}

# 安装FRP客户端
install_frpc() {
    MODE="frpc"
    SERVICE_NAME="frpc"
    BINARY_NAME="frpc"
    CONF_FILE="frpc.ini"

    info "✨ 开始安装FRP客户端..."
    
    # 获取用户配置
    echo -e "\n${BLUE}${BOLD}配置FRP客户端参数:${RESET} (直接按回车使用默认值)"
    read -p "服务端地址: " SERVER_ADDR
    while [ -z "$SERVER_ADDR" ]; do
        error "服务端地址不能为空"
        read -p "服务端地址: " SERVER_ADDR
    done
    
    read -p "服务端端口 [默认: $SERVER_PORT]: " input_server_port
    SERVER_PORT=${input_server_port:-$SERVER_PORT}
    
    read -p "认证令牌 (如果服务端设置了token): " TOKEN
    
    read -p "本地SSH端口 [默认: $LOCAL_PORT]: " input_local_port
    LOCAL_PORT=${input_local_port:-$LOCAL_PORT}
    
    read -p "远程映射端口 [默认: $REMOTE_PORT]: " input_remote_port
    REMOTE_PORT=${input_remote_port:-$REMOTE_PORT}
    
    # 下载和安装FRP
    install_frp
    
    # 创建基本配置文件
    sudo tee $INSTALL_DIR/frpc.ini > /dev/null <<EOF
[common]
server_addr = $SERVER_ADDR
server_port = $SERVER_PORT
EOF

    # 如果提供了TOKEN，则添加到配置中
    if [ -n "$TOKEN" ]; then
        echo "token = $TOKEN" >> $INSTALL_DIR/frpc.ini
    fi
    
    # 添加SSH配置
    sudo tee -a $INSTALL_DIR/frpc.ini > /dev/null <<EOF

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = $LOCAL_PORT
remote_port = $REMOTE_PORT
EOF

    # 询问是否需要添加更多转发规则
    echo -e "\n${BLUE}${BOLD}是否添加更多转发规则?${RESET} (例如Web, RDP等)"
    read -p "添加更多规则? [y/N]: " add_more_rules
    
    if [[ "$add_more_rules" == [yY] ]]; then
        while true; do
            echo -e "\n${CYAN}添加新的转发规则:${RESET} (输入q退出)"
            read -p "规则名称 (例如: web, rdp) 或q退出: " rule_name
            
            if [[ "$rule_name" == "q" ]]; then
                break
            fi
            
            read -p "协议类型 [tcp/http/https/udp]: " rule_type
            read -p "本地IP [默认127.0.0.1]: " rule_local_ip
            rule_local_ip=${rule_local_ip:-127.0.0.1}
            read -p "本地端口: " rule_local_port
            
            # 添加新规则到配置
            sudo tee -a $INSTALL_DIR/frpc.ini > /dev/null <<EOF

[$rule_name]
type = $rule_type
local_ip = $rule_local_ip
local_port = $rule_local_port
EOF

            if [[ "$rule_type" == "tcp" || "$rule_type" == "udp" ]]; then
                read -p "远程端口: " rule_remote_port
                echo "remote_port = $rule_remote_port" | sudo tee -a $INSTALL_DIR/frpc.ini > /dev/null
            elif [[ "$rule_type" == "http" || "$rule_type" == "https" ]]; then
                read -p "域名: " rule_domain
                echo "custom_domains = $rule_domain" | sudo tee -a $INSTALL_DIR/frpc.ini > /dev/null
            fi
        done
    fi
    
    # 设置服务并启动
    setup_service
    
    # 显示完成信息
    success "🎉 FRP客户端安装完成！"
    echo -e "\n${CYAN}${BOLD}客户端信息:${RESET}"
    echo -e "${YELLOW}--------------------------------------${RESET}"
    echo -e "${YELLOW}连接到服务器:${RESET} $SERVER_ADDR:$SERVER_PORT"
    echo -e "${YELLOW}SSH映射:${RESET} $SERVER_ADDR:$REMOTE_PORT -> 本地${LOCAL_PORT}端口"
    if [ -n "$TOKEN" ]; then
        echo -e "${YELLOW}认证令牌:${RESET} $TOKEN"
    fi
    echo -e "${YELLOW}--------------------------------------${RESET}"
    echo -e "${GREEN}配置文件位置:${RESET} $INSTALL_DIR/frpc.ini"
    echo -e "${GREEN}重启服务命令:${RESET} sudo systemctl restart frpc"
    echo -e "${GREEN}查看状态命令:${RESET} sudo systemctl status frpc"
}

# 公共安装函数
install_frp() {
    # 下载FRP
    cd /tmp
    FRP_FILE="frp_${FRP_VERSION#v}_linux_${ARCH}.tar.gz"
    info "正在下载FRP $FRP_VERSION..."
    wget -q --show-progress https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/${FRP_FILE}
    tar -xzf $FRP_FILE
    cd frp_${FRP_VERSION#v}_linux_${ARCH}

    # 安装目录
    sudo mkdir -p $INSTALL_DIR
    sudo chmod +x ${BINARY_NAME}
    sudo cp ${BINARY_NAME} $INSTALL_DIR
    rm -f ${BINARY_NAME}
}

# 配置系统服务
setup_service() {
    # 设置systemd服务
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=FRP ${MODE^^} Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${BINARY_NAME} -c ${INSTALL_DIR}/${CONF_FILE}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}
    sudo systemctl restart ${SERVICE_NAME}

    # 验证服务状态
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        info "✅ 服务已成功启动"
    else
        error "❌ 服务启动失败，请检查配置和日志"
        sudo journalctl -u ${SERVICE_NAME} --no-pager -n 20
        exit 1
    fi
}

# 主函数
main() {
    # 显示横幅
    show_banner
    
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &> /dev/null; then
            error "此脚本需要以root权限运行，请使用sudo或以root用户身份运行"
            exit 1
        fi
    fi
    
    # 检查是否已安装
    if check_installed; then
        echo -e "\n${BLUE}${BOLD}检测到已安装FRP，请选择操作:${RESET}"
        echo "1) 显示当前状态"
        echo "2) 修改配置"
        echo "3) 卸载FRP"
        echo "4) 重新安装"
        read -p "请输入选项 [1-4]: " choice
        
        case "$choice" in
            1)
                show_status
                ;;
            2)
                modify_config
                ;;
            3)
                uninstall_frp
                ;;
            4)
                uninstall_frp
                # 继续安装流程
                ;;
            *)
                error "无效选项"
                exit 1
                ;;
        esac
    fi
    
    # 如果未安装或选择重新安装
    if ! check_installed; then
        echo -e "\n${BLUE}${BOLD}请选择要安装的FRP模式:${RESET}"
        echo "1) frps (服务端 - 运行在公网服务器)"
        echo "2) frpc (客户端 - 运行在内网机器)"
        read -p "请输入选项 [1/2]: " mode_choice
        
        case "$mode_choice" in
            1)
                install_frps
                ;;
            2)
                install_frpc
                ;;
            *)
                error "无效选项！退出"
                exit 1
                ;;
        esac
    fi
}

# 执行主函数
main "$@"