#!/bin/bash

# x-ui 安装脚本（修改版）
# 从用户仓库 whj2015/x-ui 安装，包含UI修改

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 配置 - 修改这里使用你的仓库
REPO_OWNER="whj2015"
REPO_NAME="x-ui"

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/os-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名:" config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码:" config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口:" config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        echo -e "${yellow}确认设定,设定中${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消,所有设置项均为默认设置,请及时修改${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    # 从用户仓库获取最新版本
    if [ $# == 0 ]; then
        echo -e "${green}从 ${REPO_OWNER}/${REPO_NAME} 获取最新版本...${plain}"
        last_version=$(curl -Ls "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测版本失败，尝试从源码编译...${plain}"
            install_from_source
            return
        fi
        echo -e "检测到版本：${last_version}"
        # 下载包含修改后的UI的预编译包
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载失败，尝试从源码编译...${plain}"
            install_from_source
            return
        fi
    else
        last_version=$1
        url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载失败，尝试从源码编译...${plain}"
            install_from_source
            return
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/x-ui.sh"
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} 安装完成，面板已启动，"
    echo -e ""
    echo -e "x-ui 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - 显示管理菜单 (功能更多)"
    echo -e "x-ui start        - 启动 x-ui 面板"
    echo -e "x-ui stop         - 停止 x-ui 面板"
    echo -e "x-ui restart      - 重启 x-ui 面板"
    echo -e "x-ui status       - 查看 x-ui 状态"
    echo -e "x-ui enable       - 设置 x-ui 开机自启"
    echo -e "x-ui disable      - 取消 x-ui 开机自启"
    echo -e "x-ui log          - 查看 x-ui 日志"
    echo -e "x-ui uninstall    - 卸载 x-ui 面板"
    echo -e "----------------------------------------------"
}

install_from_source() {
    echo -e "${green}从源码编译安装（包含UI修改）...${plain}"
    
    # 检查是否安装了源码
    if [ ! -d "/usr/local/src/x-ui" ]; then
        echo -e "${yellow}正在下载源码...${plain}"
        cd /usr/local/src
        git clone "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" x-ui
    else
        echo -e "${yellow}更新源码...${plain}"
        cd /usr/local/src/x-ui
        git pull
    fi
    
    cd /usr/local/src/x-ui
    
    # 构建
    echo -e "${green}编译中...${plain}"
    CGO_ENABLED=0 GOOS=linux GOARCH=${arch} go build -ldflags="-s -w" -o x-ui main.go
    
    # 安装
    systemctl stop x-ui 2>/dev/null || true
    rm -rf /usr/local/x-ui
    mkdir -p /usr/local/x-ui
    mkdir -p /usr/local/x-ui/bin
    
    cp -f x-ui /usr/local/x-ui/
    cp -f x-ui.sh /usr/local/x-ui/
    cp -f bin/* /usr/local/x-ui/bin/
    cp -f x-ui.service /etc/systemd/system/
    
    wget --no-check-certificate -O /usr/bin/x-ui "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/x-ui.sh"
    
    chmod +x /usr/local/x-ui/x-ui
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    chmod +x /usr/local/x-ui/bin/*
    
    # 恢复数据库（如果有）
    if [ -f "/etc/x-ui/x-ui.db" ]; then
        echo -e "${yellow}保留现有数据库${plain}"
    fi
    
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    echo -e "${green}✅ 从源码编译安装完成！${NC}"
    echo -e ""
    echo -e "访问地址: http://你的服务器IP:54321"
}

echo -e "${green}========================================${NC}"
echo -e "${green}  x-ui 安装脚本 (修改版)${NC}"
echo -e "${green}  仓库: ${REPO_OWNER}/${REPO_NAME}${NC}"
echo -e "${green}========================================${NC}"
echo ""
install_base
install_x-ui $1
