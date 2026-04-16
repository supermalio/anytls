#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

V2BX_BIN="/usr/local/V2bX/V2bX"
V2BX_CONFIG="/etc/V2bX/config.json"
SERVICE_FILE="/etc/systemd/system/V2bX.service"

# 获取最新版本号
get_latest_version() {
    local version
    version=$(curl -sL https://github.com/wyx2685/V2bX/releases | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | head -1)
    if [ -z "$version" ]; then
        echo "v0.4.0"
    else
        echo "$version"
    fi
}

# 检测架构
get_arch() {
    arch=$(uname -m)
    case $arch in
        x86_64) echo "64" ;;
        aarch64) echo "arm64-v8a" ;;
        armv7l) echo "arm32-v7a" ;;
        *) echo "64" ;;
    esac
}

# 安装 V2bX
install_v2bx() {
    echo -e "${GREEN}开始安装 V2bX...${PLAIN}"

    local version
    version=$(get_latest_version)
    echo -e "${YELLOW}检测到最新版本: ${version}${PLAIN}"

    local arch
    arch=$(get_arch)
    local url="https://github.com/wyx2685/V2bX/releases/download/${version}/V2bX-linux-${arch}.zip"

    echo -e "${GREEN}下载 V2bX ${version}...${PLAIN}"
    wget -O /tmp/V2bX.zip "$url"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络或版本号${PLAIN}"
        return 1
    fi

    mkdir -p /usr/local/V2bX /etc/V2bX
    unzip -o /tmp/V2bX.zip -d /tmp/V2bX_extract
    cp /tmp/V2bX_extract/V2bX /usr/local/V2bX/V2bX
    chmod +x /usr/local/V2bX/V2bX
    rm -rf /tmp/V2bX.zip /tmp/V2bX_extract

    # 创建系统服务
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=V2bX Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/V2bX/V2bX server --config /etc/V2bX/config.json
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable V2bX

    echo -e "${GREEN}V2bX 安装完成！${PLAIN}"
}

# 写入配置文件
write_config() {
    local api_host=$1
    local api_key=$2
    local node_id=$3
    local node_type=$4
    local cert_domain=$5

    cat > "$V2BX_CONFIG" << EOF
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": [
        {
            "Type": "sing",
            "Log": {
                "Level": "error",
                "Timestamp": true
            }
        }
    ],
    "Nodes": [
        {
            "Core": "sing",
            "ApiHost": "${api_host}",
            "ApiKey": "${api_key}",
            "NodeID": ${node_id},
            "NodeType": "${node_type}",
            "Timeout": 30,
            "ListenIP": "::",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "MinReportTraffic": 0,
            "TCPFastOpen": false,
            "SniffEnabled": true,
            "CertConfig": {
                "CertMode": "self",
                "RejectUnknownSni": false,
                "CertDomain": "${cert_domain}",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        }
    ]
}
EOF
    echo -e "${GREEN}配置文件已写入${PLAIN}"
}

# 交互式配置
setup_config() {
    echo ""
    echo -e "${YELLOW}===== 配置 V2bX =====${PLAIN}"
    echo ""

    read -p "请输入面板域名 (例如 https://xxx.com): " api_host
    read -p "请输入 API 密钥 (muKey): " api_key
    read -p "请输入节点 ID: " node_id

    echo ""
    echo "请选择节点协议:"
    echo "  1. anytls"
    echo "  2. vless"
    echo "  3. trojan"
    echo "  4. shadowsocks"
    read -p "请输入序号 [1-4]: " node_type_choice
    case $node_type_choice in
        1) node_type="anytls" ;;
        2) node_type="vless" ;;
        3) node_type="trojan" ;;
        4) node_type="shadowsocks" ;;
        *) node_type="anytls" ;;
    esac

    read -p "请输入伪装域名 (默认 ithome.com): " cert_domain
    cert_domain=${cert_domain:-ithome.com}

    write_config "$api_host" "$api_key" "$node_id" "$node_type" "$cert_domain"
}

# 启动/停止/重启/状态
start_v2bx()   { systemctl start V2bX   && echo -e "${GREEN}V2bX 已启动${PLAIN}"; }
stop_v2bx()    { systemctl stop V2bX    && echo -e "${YELLOW}V2bX 已停止${PLAIN}"; }
restart_v2bx() { systemctl restart V2bX && echo -e "${GREEN}V2bX 已重启${PLAIN}"; }
status_v2bx()  { systemctl status V2bX; }

# 卸载
uninstall_v2bx() {
    read -p "确认卸载 V2bX？(y/n): " confirm
    if [ "$confirm" = "y" ]; then
        systemctl stop V2bX
        systemctl disable V2bX
        rm -f "$SERVICE_FILE"
        rm -rf /usr/local/V2bX
        rm -rf /etc/V2bX
        systemctl daemon-reload
        echo -e "${GREEN}V2bX 已卸载${PLAIN}"
    fi
}

# 查看日志
show_log() {
    journalctl -u V2bX -n 50 --no-pager
}

# 主菜单
show_menu() {
    echo ""
    echo -e "${GREEN}===== V2bX 管理脚本 =====${PLAIN}"
    echo "  1. 安装 V2bX"
    echo "  2. 修改配置"
    echo "  3. 启动"
    echo "  4. 停止"
    echo "  5. 重启"
    echo "  6. 查看状态"
    echo "  7. 查看日志"
    echo "  8. 卸载"
    echo "  0. 退出"
    echo ""
    read -p "请输入选项: " choice

    case $choice in
        1)
            install_v2bx
            if [ $? -eq 0 ]; then
                setup_config
                start_v2bx
                status_v2bx
            fi
            ;;
        2)
            setup_config
            restart_v2bx
            ;;
        3) start_v2bx ;;
        4) stop_v2bx ;;
        5) restart_v2bx ;;
        6) status_v2bx ;;
        7) show_log ;;
        8) uninstall_v2bx ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${PLAIN}" ;;
    esac

    show_menu
}

# 入口
show_menu
