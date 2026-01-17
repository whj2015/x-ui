#!/bin/bash

# x-ui 本地安装脚本
# 使用当前目录的源代码编译并安装

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 开始本地安装 x-ui（使用修改后的源代码）${NC}"
echo "=========================================="

# 检查系统
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：必须使用root用户运行！${NC}"
    exit 1
fi

# 获取架构
arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    echo -e "${YELLOW}未知架构: ${arch}，使用 amd64${NC}"
    arch="amd64"
fi

echo -e "${GREEN}架构: ${arch}${NC}"

# 检查Go
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}正在安装 Go...${NC}"
    if command -v apt &> /dev/null; then
        apt update && apt install -y golang-go
    elif command -v yum &> /dev/null; then
        yum install -y golang
    fi
fi

# 检查源码目录
cur_dir=$(pwd)
if [ ! -f "main.go" ]; then
    echo -e "${RED}错误：未找到 main.go，请确保在正确的目录下运行${NC}"
    exit 1
fi

echo -e "${GREEN}源码目录: ${cur_dir}${NC}"

# 安装依赖
echo -e "${GREEN}📦 安装 Go 依赖...${NC}"
go mod download

# 构建
echo -e "${GREEN}🔨 编译 x-ui...${NC}"
if [ "$arch" == "amd64" ]; then
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o x-ui main.go
else
    CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o x-ui main.go
fi

# 检查xray文件
echo -e "${GREEN}📋 检查 xray 文件...${NC}"
if [ ! -f "bin/xray-linux-${arch}" ]; then
    echo -e "${YELLOW}⚠️ xray 文件不存在，正在下载...${NC}"
    mkdir -p bin
    wget -O bin/xray-linux-${arch} \
        "https://github.com/XTLS/Xray-core/releases/download/v1.4.2/Xray-linux-${arch}.zip" 2>/dev/null || \
    wget -O bin/xray-linux-${arch} \
        "https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-${arch}.zip"
    
    if [ -f "bin/xray-linux-${arch}.zip" ]; then
        unzip -o bin/xray-linux-${arch}.zip -d bin/
        rm -f bin/xray-linux-${arch}.zip
    fi
fi

if [ -f "bin/xray-linux-${arch}" ]; then
    chmod +x bin/xray-linux-${arch}
    echo -e "${GREEN}✅ xray 文件准备完成${NC}"
else
    echo -e "${YELLOW}⚠️ xray 文件未能自动下载，请手动下载到 bin/xray-linux-${arch}${NC}"
fi

# 停止旧服务
echo -e "${GREEN}🛑 停止旧服务...${NC}"
systemctl stop x-ui 2>/dev/null || true
systemctl disable x-ui 2>/dev/null || true

# 创建安装目录
echo -e "${GREEN}📁 创建安装目录...${NC}"
rm -rf /usr/local/x-ui
mkdir -p /usr/local/x-ui
mkdir -p /usr/local/x-ui/bin
mkdir -p /etc/x-ui

# 复制文件
echo -e "${GREEN}📦 复制文件...${NC}"
cp -f x-ui /usr/local/x-ui/
cp -f x-ui.sh /usr/local/x-ui/
cp -f bin/* /usr/local/x-ui/bin/
cp -f x-ui.service /etc/systemd/system/

# 复制数据库（如果存在）
if [ -f "/etc/x-ui/x-ui.db" ]; then
    echo -e "${YELLOW}保留现有数据库${NC}"
fi

# 设置权限
chmod +x /usr/local/x-ui/x-ui
chmod +x /usr/local/x-ui/x-ui.sh
chmod +x /usr/local/x-ui/bin/*

# 下载x-ui命令
echo -e "${GREEN}📥 下载 x-ui 管理命令...${NC}"
wget --no-check-certificate -O /usr/bin/x-ui \
    "https://raw.githubusercontent.com/whj2015/x-ui/main/x-ui.sh" 2>/dev/null || \
wget --no-check-certificate -O /usr/bin/x-ui \
    "https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh"
chmod +x /usr/bin/x-ui

# 重载 systemd
echo -e "${GREEN}🔄 重载 systemd...${NC}"
systemctl daemon-reload

# 设置开机自启
echo -e "${GREEN}⚡ 设置开机自启...${NC}"
systemctl enable x-ui

# 启动服务
echo -e "${GREEN}🚀 启动服务...${NC}"
systemctl start x-ui

# 等待服务启动
sleep 3

# 检查状态
echo ""
echo "=========================================="
if systemctl is-active --quiet x-ui; then
    echo -e "${GREEN}✅ x-ui 安装成功！${NC}"
else
    echo -e "${YELLOW}⚠️ 服务可能未完全启动，请检查日志: systemctl status x-ui${NC}"
fi

echo ""
echo -e "${GREEN}🎉 安装完成！${NC}"
echo ""
echo "访问地址: http://你的服务器IP:54321"
echo "管理命令: x-ui"
echo ""
echo "常用命令:"
echo "  x-ui              - 管理菜单"
echo "  x-ui status       - 查看状态"
echo "  x-ui restart      - 重启服务"
echo "  x-ui log          - 查看日志"
echo "  x-ui stop         - 停止服务"
echo ""
