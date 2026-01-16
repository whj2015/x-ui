#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 开始部署 x-ui Docker 环境${NC}"
echo "=========================================="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装，请先安装Docker${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker已安装${NC}"

# 检查docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚠️ docker-compose未安装，将使用docker build + docker run${NC}"
    USE_COMPOSE=false
else
    echo -e "${GREEN}✅ docker-compose已安装${NC}"
    USE_COMPOSE=true
fi

# 检查bin目录
if [ ! -d "bin" ]; then
    echo -e "${YELLOW}⚠️ bin目录不存在，正在创建...${NC}"
    mkdir -p bin
fi

if [ ! -f "bin/xray-linux-amd64" ] && [ ! -f "bin/xray-linux-arm64" ]; then
    echo -e "${YELLOW}⚠️ xray二进制文件不存在${NC}"
    echo -e "${YELLOW}请从 https://github.com/XTLS/Xray-core/releases 下载并放到bin/目录${NC}"
    echo ""
    read -p "是否继续构建？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 创建数据目录
echo -e "${GREEN}📁 创建数据目录...${NC}"
mkdir -p data cert logs

# 构建镜像
echo -e "${GREEN}🔨 构建Docker镜像...${NC}"
if [ "$USE_COMPOSE" = true ]; then
    docker compose build --no-cache
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 镜像构建成功${NC}"
    else
        echo -e "${RED}❌ 镜像构建失败${NC}"
        exit 1
    fi

    # 停止旧容器
    echo -e "${YELLOW}🛑 停止旧容器...${NC}"
    docker compose down || true

    # 启动新容器
    echo -e "${GREEN}🚀 启动容器...${NC}"
    docker compose up -d

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 容器启动成功${NC}"
    else
        echo -e "${RED}❌ 容器启动失败${NC}"
        exit 1
    fi
else
    # 使用docker build
    docker build -t x-ui:latest --no-cache .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 镜像构建成功${NC}"
    else
        echo -e "${RED}❌ 镜像构建失败${NC}"
        exit 1
    fi

    # 停止旧容器
    echo -e "${YELLOW}🛑 停止旧容器...${NC}"
    docker stop x-ui 2>/dev/null || true
    docker rm x-ui 2>/dev/null || true

    # 启动新容器
    echo -e "${GREEN}🚀 启动容器...${NC}"
    docker run -d \
        --name x-ui \
        --restart unless-stopped \
        --network host \
        -v $PWD/data:/etc/x-ui/ \
        -v $PWD/cert:/root/cert/ \
        -v $PWD/logs:/var/log/x-ui/ \
        -e TZ=Asia/Shanghai \
        x-ui:latest

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 容器启动成功${NC}"
    else
        echo -e "${RED}❌ 容器启动失败${NC}"
        exit 1
    fi
fi

# 等待容器启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 5

# 检查容器状态
echo -e "${GREEN}📊 检查容器状态...${NC}"
if [ "$USE_COMPOSE" = true ]; then
    docker compose ps
else
    docker ps | grep x-ui
fi

# 检查健康状态
echo -e "${GREEN}🏥 检查服务健康状态...${NC}"
for i in {1..10}; do
    if curl -s http://localhost:54321/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 服务已就绪！${NC}"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${YELLOW}⚠️ 服务可能还未完全启动，请稍后检查${NC}"
    fi
    sleep 2
done

echo ""
echo "=========================================="
echo -e "${GREEN}🎉 部署完成！${NC}"
echo ""
echo "访问地址: http://localhost:54321"
echo "默认账号: admin"
echo "默认密码: admin"
echo ""
echo -e "${YELLOW}⚠️ 首次登录后请立即修改密码！${NC}"
echo ""
echo "常用命令:"
if [ "$USE_COMPOSE" = true ]; then
    echo "  查看日志: docker compose logs -f"
    echo "  重启服务: docker compose restart"
    echo "  停止服务: docker compose down"
else
    echo "  查看日志: docker logs -f x-ui"
    echo "  重启服务: docker restart x-ui"
    echo "  停止服务: docker stop x-ui && docker rm x-ui"
fi
echo ""
