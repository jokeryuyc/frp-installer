# FRP 一键安装脚本

这是一个用于快速安装和配置 FRP (Fast Reverse Proxy) 的脚本，支持服务端(frps)和客户端(frpc)模式。

## 功能特点

- 自动获取最新版本的 FRP
- 交互式安装选择服务端或客户端模式
- 自动创建基本配置文件
- 设置系统服务并自动启动
- 彩色输出优化使用体验

## 使用方法

### 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jokeryuyc/frp-installer/main/frp_install.sh)
```

### 手动安装

1. 下载脚本

```bash
wget https://raw.githubusercontent.com/jokeryuyc/frp-installer/main/frp_install.sh
```

2. 赋予执行权限

```bash
chmod +x frp_install.sh
```

3. 运行脚本

```bash
./frp_install.sh
```

## 配置文件

### 服务端(frps)默认配置

配置文件位置: `/usr/local/frp/frps.ini`

```ini
[common]
bind_port = 6000
dashboard_port = 6050
dashboard_user = admin
dashboard_pwd = admin
```

### 客户端(frpc)默认配置

配置文件位置: `/usr/local/frp/frpc.ini`

```ini
[common]
server_addr = xxx.xxx.xxx  # 需要修改为您的服务器IP地址
server_port = 6000

[ssh]
type = tcp
local_port = 22
remote_port = 6022
```

## 服务管理

启动服务:
```bash
sudo systemctl start frps  # 或 frpc
```

停止服务:
```bash
sudo systemctl stop frps  # 或 frpc
```

重启服务:
```bash
sudo systemctl restart frps  # 或 frpc
```

查看服务状态:
```bash
sudo systemctl status frps  # 或 frpc
```

## 注意事项

- 安装后请务必修改默认配置以增强安全性，特别是服务端的dashboard密码。
- 客户端配置中需要填写正确的服务器地址。
- 本脚本默认安装到 `/usr/local/frp` 目录下。

## 许可

MIT